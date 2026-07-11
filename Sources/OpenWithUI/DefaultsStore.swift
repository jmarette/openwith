import Foundation
import Observation
import OpenWithCore

/// The GUI's view model: one row per known target, loaded from the curated
/// list plus discovery, with the live default and candidate handlers.
@MainActor
@Observable
public final class DefaultsStore {
  public struct Row: Identifiable, Sendable {
    public var id: String { target.description }
    public var target: Target
    public var label: String
    public var category: CuratedTarget.Category
    public var resolved: ResolvedTarget
    public var current: AppInfo?
    public var handlers: [AppInfo]
    /// The role the next change (and the displayed default) applies to.
    public var role: Role = .all
    /// Set when the user changed this row in this session.
    public var changed = false
    /// Human-readable outcome of the last change attempt on this row.
    public var lastOutcome: String?

    public var isScheme: Bool {
      if case .scheme = resolved { return true }
      return false
    }
  }

  public enum Filter: String, CaseIterable, Sendable {
    case all = "All"
    case types = "Types"
    case extensions = "Extensions"
    case schemes = "URL schemes"
    case changed = "Changed by me"
  }

  public private(set) var rows: [Row] = []
  public var searchText = ""
  public var filter: Filter = .all
  public private(set) var isLoading = false
  public var statusMessage: String?

  private let engine: Engine

  public init(engine: Engine = .live()) {
    self.engine = engine
  }

  public var visibleRows: [Row] {
    rows.filter { row in
      switch filter {
      case .all: break
      case .types:
        guard case .uti = row.target else { return false }
      case .extensions:
        guard case .ext = row.target else { return false }
      case .schemes:
        guard row.isScheme else { return false }
      case .changed:
        guard row.changed else { return false }
      }
      guard !searchText.isEmpty else { return true }
      return row.label.localizedCaseInsensitiveContains(searchText)
        || row.resolved.value.localizedCaseInsensitiveContains(searchText)
        || row.target.value.localizedCaseInsensitiveContains(searchText)
        || (row.current?.name.localizedCaseInsensitiveContains(searchText) ?? false)
    }
  }

  /// Builds the table from the curated list plus discovered targets. Reads
  /// only — never writes to LaunchServices.
  public func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    let engine = self.engine
    let loaded: [Row] = await Task.detached(priority: .userInitiated) {
      let all = Curated.targets + Discovery.discoverTargets()
      var rows: [Row] = []
      var seen = Set<String>()
      for curated in all {
        guard let resolved = try? engine.resolve(curated.target) else { continue }
        guard seen.insert(resolved.value + "|" + curated.target.kind).inserted else { continue }
        rows.append(
          Row(
            target: curated.target,
            label: curated.label,
            category: curated.category,
            resolved: resolved,
            current: engine.currentDefault(for: resolved, role: .all),
            handlers: Self.handlers(engine: engine, resolved: resolved)))
      }
      return rows
    }.value

    rows = loaded
    statusMessage = "\(loaded.count) targets"
  }

  private nonisolated static func handlers(engine: Engine, resolved: ResolvedTarget) -> [AppInfo] {
    switch resolved {
    case .contentType(let uti):
      return engine.provider.handlers(forContentType: uti, role: .all)
    case .scheme(let scheme):
      return engine.provider.handlers(forScheme: scheme)
    }
  }

  /// Changes the role a row displays and writes with, re-reading the current
  /// default for that role (viewer/editor defaults can differ from "all").
  public func setRole(_ role: Role, forRowID rowID: String) {
    guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
    rows[index].role = role
    rows[index].current = engine.currentDefault(for: rows[index].resolved, role: role)
  }

  /// Sets the default for a row and refreshes it from the read-back state:
  /// the row shows what macOS actually recorded, not what we asked for.
  public func setDefault(rowID: String, to app: AppInfo, role: Role = .all) async {
    guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
    let row = rows[index]
    let engine = self.engine

    let outcome: Result<SetOutcome, any Error> = await Task.detached {
      do {
        return .success(try await engine.setDefault(app: app, for: row.resolved, role: role))
      } catch {
        return .failure(error)
      }
    }.value

    // Re-read reality regardless of the outcome.
    rows[index].current = engine.currentDefault(for: row.resolved, role: role)

    switch outcome {
    case .success(.alreadySet):
      rows[index].lastOutcome = nil
      statusMessage = "\(row.label): already \(app.name)"
    case .success(.applied):
      rows[index].changed = true
      rows[index].lastOutcome = nil
      statusMessage = "\(row.label) → \(app.name)"
    case .success(.notConfirmed):
      rows[index].lastOutcome = "macOS did not record the change (dialog declined?)"
      statusMessage = "\(row.label): change not confirmed"
    case .failure(let error):
      let message = (error as? OpenWithError)?.errorDescription ?? error.localizedDescription
      rows[index].lastOutcome = message
      statusMessage = "\(row.label): \(message)"
    }
  }

  // MARK: Config file operations

  public func exportConfig() throws -> String {
    try NativeConfig.encode(engine.exportCurrentDefaults())
  }

  /// Applies a config file (native TOML or utiluti plist/mobileconfig) and
  /// returns a human summary. Sequential: one OS dialog per actual change.
  public func applyConfigFile(at url: URL) async -> String {
    let engine = self.engine
    let summary: String = await Task.detached {
      guard let data = FileManager.default.contents(atPath: url.path) else {
        return "cannot read \(url.lastPathComponent)"
      }
      let config: Config
      do {
        if let imported = try? Utiluti.importConfig(data: data) {
          config = imported
        } else {
          config = try NativeConfig.decode(toml: String(decoding: data, as: UTF8.self))
        }
      } catch {
        let message = (error as? OpenWithError)?.errorDescription ?? error.localizedDescription
        return "cannot parse \(url.lastPathComponent): \(message)"
      }

      let results = await engine.apply(config)
      let applied = results.filter { $0.status == .applied }.count
      let already = results.filter { $0.status == .alreadySet }.count
      let failures = results.filter(\.isFailure).count
      var parts = ["\(applied) applied", "\(already) already set"]
      if failures > 0 { parts.append("\(failures) not applied") }
      return parts.joined(separator: ", ")
    }.value

    await load()
    statusMessage = summary
    return summary
  }
}
