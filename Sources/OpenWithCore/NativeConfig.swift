import Foundation
import TOMLKit

/// The native openwith config format: one TOML document unifying content
/// types, extensions and URL schemes, with roles and a schema version.
///
/// ```toml
/// schema = 1
///
/// [[type]]
/// uti  = "public.plain-text"
/// app  = "com.microsoft.VSCode"
/// role = "editor"                 # viewer | editor | all (default: all)
///
/// [[type]]
/// extension = "md"
/// app       = "com.microsoft.VSCode"
///
/// [[url]]
/// scheme = "mailto"
/// app    = "com.microsoft.Outlook"
/// ```
public enum NativeConfig {
  public static func decode(toml: String) throws -> Config {
    let file: ConfigFile
    do {
      file = try TOMLDecoder().decode(ConfigFile.self, from: toml)
    } catch {
      throw OpenWithError.invalidConfig(String(describing: error))
    }
    guard file.schema <= Config.currentSchema else {
      throw OpenWithError.unsupportedSchema(file.schema)
    }

    var associations: [Association] = []
    for (index, entry) in (file.type ?? []).enumerated() {
      let target: Target
      switch (entry.uti, entry.extension) {
      case (let uti?, nil):
        target = .uti(uti)
      case (nil, let ext?):
        target = .ext(ext.lowercased())
      case (nil, nil):
        throw OpenWithError.invalidConfig("[[type]] entry #\(index + 1) needs 'uti' or 'extension'")
      case (.some, .some):
        throw OpenWithError.invalidConfig(
          "[[type]] entry #\(index + 1) has both 'uti' and 'extension'; pick one")
      }
      associations.append(
        Association(
          target: target,
          app: AppRef(bundleID: entry.app, path: entry.appPath, name: entry.appName),
          role: entry.role ?? .all))
    }
    for entry in file.url ?? [] {
      associations.append(
        Association(
          target: .urlScheme(entry.scheme.lowercased()),
          app: AppRef(bundleID: entry.app, path: entry.appPath, name: entry.appName),
          role: .all))
    }
    return Config(schema: file.schema, associations: associations)
  }

  public static func encode(_ config: Config) throws -> String {
    var types: [TypeEntry] = []
    var urls: [URLEntry] = []
    for association in config.associations {
      switch association.target {
      case .uti(let uti):
        types.append(entry(uti: uti, association: association))
      case .ext(let ext):
        types.append(entry(ext: ext, association: association))
      case .urlScheme(let scheme):
        urls.append(
          URLEntry(
            scheme: scheme, app: association.app.bundleID,
            appPath: association.app.path, appName: association.app.name))
      case .file(let path):
        throw OpenWithError.invalidConfig(
          "cannot store a file path (\(path)) in a config; use its extension or UTI")
      }
    }
    let file = ConfigFile(
      schema: config.schema, type: types.isEmpty ? nil : types, url: urls.isEmpty ? nil : urls)
    let body = try TOMLEncoder().encode(file)
    return "# openwith config — https://github.com/jmarette/openwith\n\n" + body
  }

  private static func entry(uti: String? = nil, ext: String? = nil, association: Association)
    -> TypeEntry
  {
    TypeEntry(
      uti: uti,
      extension: ext,
      app: association.app.bundleID,
      appPath: association.app.path,
      appName: association.app.name,
      role: association.role == .all ? nil : association.role)
  }

  // MARK: File shape

  struct ConfigFile: Codable {
    var schema: Int
    var type: [TypeEntry]?
    var url: [URLEntry]?
  }

  struct TypeEntry: Codable {
    var uti: String?
    var `extension`: String?
    var app: String
    var appPath: String?
    var appName: String?
    var role: Role?

    enum CodingKeys: String, CodingKey {
      case uti
      case `extension`
      case app
      case appPath = "app_path"
      case appName = "app_name"
      case role
    }
  }

  struct URLEntry: Codable {
    var scheme: String
    var app: String
    var appPath: String?
    var appName: String?

    enum CodingKeys: String, CodingKey {
      case scheme
      case app
      case appPath = "app_path"
      case appName = "app_name"
    }
  }
}
