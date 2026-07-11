import Foundation

/// The result of applying one association from a config.
public struct ApplyResult: Sendable, Equatable {
  public enum Status: Sendable, Equatable {
    /// Dry run: a real apply would change the default (from `current`).
    case wouldSet(current: AppInfo?)
    case alreadySet
    case applied
    /// The write went through but the read-back does not show the desired
    /// app — the user declined (or ignored) the OS confirmation dialog.
    case notConfirmed(actual: String?)
    case failed(message: String)
  }

  public var association: Association
  public var status: Status

  public init(association: Association, status: Status) {
    self.association = association
    self.status = status
  }

  public var isFailure: Bool {
    switch status {
    case .wouldSet, .alreadySet, .applied: return false
    case .notConfirmed, .failed: return true
    }
  }
}

extension Engine {
  /// Applies a config, one association at a time (sequential on purpose:
  /// each change can raise its own OS confirmation dialog). Idempotent —
  /// associations that already hold are skipped without writing.
  public func apply(_ config: Config, dryRun: Bool = false) async -> [ApplyResult] {
    var results: [ApplyResult] = []
    for association in config.associations {
      results.append(await applyOne(association, dryRun: dryRun))
    }
    return results
  }

  private func applyOne(_ association: Association, dryRun: Bool) async -> ApplyResult {
    let resolved: ResolvedTarget
    let app: AppInfo
    do {
      resolved = try resolve(association.target)
      app = try resolveApp(association.app)
    } catch {
      return ApplyResult(association: association, status: .failed(message: errorMessage(error)))
    }

    if case .scheme(let scheme) = resolved, association.role != .all {
      let error = OpenWithError.roleNotSupportedForSchemes(scheme: scheme, role: association.role)
      return ApplyResult(association: association, status: .failed(message: errorMessage(error)))
    }

    let current = currentDefault(for: resolved, role: association.role)
    if current?.bundleID == app.bundleID {
      return ApplyResult(association: association, status: .alreadySet)
    }
    if dryRun {
      return ApplyResult(association: association, status: .wouldSet(current: current))
    }

    do {
      switch try await setDefault(app: app, for: resolved, role: association.role) {
      case .alreadySet:
        return ApplyResult(association: association, status: .alreadySet)
      case .applied:
        return ApplyResult(association: association, status: .applied)
      case .notConfirmed(_, let actual):
        return ApplyResult(
          association: association, status: .notConfirmed(actual: actual?.bundleID))
      }
    } catch {
      return ApplyResult(association: association, status: .failed(message: errorMessage(error)))
    }
  }

  private func errorMessage(_ error: any Error) -> String {
    (error as? OpenWithError)?.errorDescription ?? (error as NSError).localizedDescription
  }
}

extension Engine {
  /// Snapshots the current defaults for the given targets (the curated list
  /// by default) into a config suitable for `openwith export`.
  public func exportCurrentDefaults(targets: [CuratedTarget] = Curated.targets) -> Config {
    var associations: [Association] = []
    var seen: Set<ResolvedTarget> = []
    for curated in targets {
      guard let resolved = try? resolve(curated.target) else { continue }
      guard seen.insert(resolved).inserted else { continue }
      guard let app = currentDefault(for: resolved, role: .all) else { continue }
      associations.append(
        Association(
          target: curated.target,
          app: AppRef(bundleID: app.bundleID, path: app.path, name: app.name),
          role: .all))
    }
    return Config(associations: associations)
  }
}
