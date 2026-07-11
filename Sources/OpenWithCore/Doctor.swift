import Foundation

/// One finding from `openwith doctor`.
public struct Diagnostic: Sendable, Equatable, Codable {
  public enum Severity: String, Sendable, Codable, Comparable {
    case ok
    case warning
    case error

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
      let order: [Severity] = [.ok, .warning, .error]
      return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
  }

  public var severity: Severity
  public var message: String

  public init(_ severity: Severity, _ message: String) {
    self.severity = severity
    self.message = message
  }
}

extension Engine {
  /// Sanity-checks a config: unresolved apps, unknown types, duplicate or
  /// conflicting entries, role misuse on URL schemes.
  public func doctorConfig(_ config: Config) -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []
    var byKey: [String: (index: Int, bundleID: String)] = [:]

    for (index, association) in config.associations.enumerated() {
      let label = "entry #\(index + 1) (\(association.target))"

      // App resolvable?
      if provider.app(forBundleID: association.app.bundleID) == nil {
        if let path = association.app.path, let byPath = provider.app(atPath: path) {
          diagnostics.append(
            Diagnostic(
              .warning,
              "\(label): bundle id '\(association.app.bundleID)' is not installed; app_path resolves to '\(byPath.bundleID)' and will be used"
            ))
        } else if let name = association.app.name, let byName = provider.app(named: name) {
          diagnostics.append(
            Diagnostic(
              .warning,
              "\(label): bundle id '\(association.app.bundleID)' is not installed; app_name resolves to '\(byName.bundleID)' and will be used"
            ))
        } else {
          diagnostics.append(
            Diagnostic(
              .error, "\(label): app '\(association.app.bundleID)' is not installed"))
        }
      }

      // Target resolvable / sane?
      switch association.target {
      case .uti(let uti):
        if !provider.isDeclared(contentType: uti) {
          diagnostics.append(
            Diagnostic(.warning, "\(label): UTI '\(uti)' is not declared on this system"))
        }
      case .ext(let ext):
        if let uti = provider.contentType(forExtension: ext) {
          if uti.hasPrefix("dyn.") {
            diagnostics.append(
              Diagnostic(
                .warning,
                "\(label): extension '\(ext)' has no declared type; a dynamic UTI (\(uti)) will be used"
              ))
          }
        } else {
          diagnostics.append(
            Diagnostic(.error, "\(label): extension '\(ext)' cannot be resolved to a type"))
        }
      case .urlScheme(let scheme):
        if association.role != .all {
          diagnostics.append(
            Diagnostic(
              .error,
              "\(label): URL schemes have no roles; 'role = \"\(association.role.rawValue)\"' is invalid for url:\(scheme)"
            ))
        }
      case .file(let path):
        diagnostics.append(
          Diagnostic(.error, "\(label): file paths (\(path)) cannot appear in a config"))
      }

      // Duplicates and conflicts.
      if let resolved = try? resolve(association.target) {
        let key = "\(resolved.value)|\(association.role.rawValue)"
        if let previous = byKey[key] {
          if previous.bundleID == association.app.bundleID {
            diagnostics.append(
              Diagnostic(
                .warning, "\(label): duplicate of entry #\(previous.index + 1) (same app)"))
          } else {
            diagnostics.append(
              Diagnostic(
                .error,
                "\(label): conflicts with entry #\(previous.index + 1) — both set \(association.target) [\(association.role.rawValue)] but to different apps ('\(previous.bundleID)' vs '\(association.app.bundleID)'); the last one wins"
              ))
          }
        } else {
          byKey[key] = (index, association.app.bundleID)
        }
      }
    }

    if diagnostics.isEmpty {
      diagnostics.append(
        Diagnostic(.ok, "config is sane: \(config.associations.count) association(s), no findings"))
    }
    return diagnostics
  }

  /// Basic environment checks used by a bare `openwith doctor`.
  public func doctorEnvironment() -> [Diagnostic] {
    var diagnostics: [Diagnostic] = []

    if let app = provider.defaultApp(forContentType: "public.plain-text", role: .all) {
      diagnostics.append(
        Diagnostic(
          .ok, "LaunchServices answers: public.plain-text opens with \(app.name) (\(app.bundleID))")
      )
    } else {
      diagnostics.append(
        Diagnostic(.warning, "LaunchServices returned no default app for public.plain-text"))
    }

    if let app = provider.defaultApp(forScheme: "http") {
      diagnostics.append(Diagnostic(.ok, "default browser: \(app.name) (\(app.bundleID))"))
    } else {
      diagnostics.append(Diagnostic(.warning, "no default handler for the http scheme"))
    }

    let unresolvable = Curated.targets.filter { (try? resolve($0.target)) == nil }
    if unresolvable.isEmpty {
      diagnostics.append(
        Diagnostic(.ok, "all \(Curated.targets.count) curated targets resolve to a type or scheme"))
    } else {
      diagnostics.append(
        Diagnostic(
          .warning,
          "curated targets that do not resolve: \(unresolvable.map { $0.target.description }.joined(separator: ", "))"
        ))
    }

    return diagnostics
  }
}
