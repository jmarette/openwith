import Foundation

/// The LaunchServices role an association applies to.
///
/// URL schemes only support `.all`; viewer/editor distinctions exist for
/// content types only.
public enum Role: String, Sendable, Codable, Hashable, CaseIterable {
  case viewer
  case editor
  case all
}

/// What an association points at, as expressed by the user.
///
/// Extensions and file paths are resolved to a UTI at apply time; see
/// `Engine.resolve(_:)`.
public enum Target: Sendable, Hashable {
  case uti(String)
  case ext(String)
  case urlScheme(String)
  case file(String)

  /// Stable machine-readable kind, used in `--json` output.
  public var kind: String {
    switch self {
    case .uti: return "uti"
    case .ext: return "extension"
    case .urlScheme: return "scheme"
    case .file: return "file"
    }
  }

  /// The raw value carried by the case.
  public var value: String {
    switch self {
    case .uti(let v), .ext(let v), .urlScheme(let v), .file(let v):
      return v
    }
  }
}

extension Target: CustomStringConvertible {
  public var description: String { "\(kind):\(value)" }
}

/// A target resolved to what LaunchServices actually keys on.
public enum ResolvedTarget: Sendable, Hashable {
  case contentType(String)
  case scheme(String)

  public var value: String {
    switch self {
    case .contentType(let v), .scheme(let v):
      return v
    }
  }
}

/// A reference to an application as stored in a config file.
///
/// The bundle identifier is the canonical LaunchServices key; `path` and
/// `name` are fallbacks used when the bundle id is not installed.
public struct AppRef: Sendable, Hashable, Codable {
  public var bundleID: String
  public var path: String?
  public var name: String?

  public init(bundleID: String, path: String? = nil, name: String? = nil) {
    self.bundleID = bundleID
    self.path = path
    self.name = name
  }
}

/// An application installed on this machine, fully resolved.
public struct AppInfo: Sendable, Hashable, Codable {
  public var bundleID: String
  public var name: String
  public var path: String

  public init(bundleID: String, name: String, path: String) {
    self.bundleID = bundleID
    self.name = name
    self.path = path
  }
}

/// One desired default-app assignment.
public struct Association: Sendable, Hashable {
  public var target: Target
  public var app: AppRef
  public var role: Role

  public init(target: Target, app: AppRef, role: Role = .all) {
    self.target = target
    self.app = app
    self.role = role
  }
}

/// A full openwith configuration: a schema version plus the associations.
public struct Config: Sendable, Hashable {
  public static let currentSchema = 1

  public var schema: Int
  public var associations: [Association]

  public init(schema: Int = Config.currentSchema, associations: [Association] = []) {
    self.schema = schema
    self.associations = associations
  }
}

/// The version of the openwith tools. Must match `version` in `dist.toml`.
public enum OpenWithVersion {
  public static let string = "0.1.0"
}

/// Shared identifiers for the GUI app and the PrefPane.
public enum Branding {
  public static let guiBundleID = "com.jmarette.openwith"
  public static let paneBundleID = "com.jmarette.openwith.pane"
}
