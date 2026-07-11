import Foundation

/// The pinned `--json` output shapes of the CLI's read commands.
///
/// These are a machine API: field names and structure are covered by tests
/// (`JSONShapeTests`) and must only change with a `schemaVersion` bump.
public enum JSONOutput {
  public static let schemaVersion = 1

  public struct TargetJSON: Codable, Equatable, Sendable {
    /// "uti" | "extension" | "scheme" | "file"
    public var kind: String
    /// The target exactly as the user typed it.
    public var input: String
    /// The UTI or URL scheme LaunchServices keys on.
    public var resolved: String

    public init(kind: String, input: String, resolved: String) {
      self.kind = kind
      self.input = input
      self.resolved = resolved
    }

    public init(input: String, target: Target, resolved: ResolvedTarget) {
      self.init(kind: target.kind, input: input, resolved: resolved.value)
    }
  }

  public struct GetJSON: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var target: TargetJSON
    public var role: String
    public var app: AppInfo?

    public init(target: TargetJSON, role: Role, app: AppInfo?) {
      self.schemaVersion = JSONOutput.schemaVersion
      self.target = target
      self.role = role.rawValue
      self.app = app
    }
  }

  public struct ListJSON: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var target: TargetJSON
    public var role: String
    public var apps: [AppInfo]

    public init(target: TargetJSON, role: Role, apps: [AppInfo]) {
      self.schemaVersion = JSONOutput.schemaVersion
      self.target = target
      self.role = role.rawValue
      self.apps = apps
    }
  }

  public struct DoctorJSON: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var diagnostics: [Diagnostic]

    public init(diagnostics: [Diagnostic]) {
      self.schemaVersion = JSONOutput.schemaVersion
      self.diagnostics = diagnostics
    }
  }

  /// Deterministic encoding (sorted keys, no escaped slashes) so the shapes
  /// can be pinned byte-for-byte in tests.
  public static func encode(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
  }
}
