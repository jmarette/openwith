import Foundation

/// Import (and lossily export) utiluti's formats, for migration.
///
/// utiluti stores flat `key → bundle id` plists — one file for types (keys
/// are UTIs or `extension:ext`) and a separate one for URL schemes — plus
/// `.mobileconfig` profiles with payload types
/// `com.scriptingosx.utiluti.type` / `com.scriptingosx.utiluti.url`.
///
/// The format has no role concept, so imported entries default to
/// `role = all`, and exporting to it drops roles (documented as lossy).
public enum Utiluti {
  /// How to interpret the keys of a flat utiluti plist.
  public enum Kind: String, Sendable {
    case type
    case url
    case auto
  }

  // MARK: Import

  public static func importConfig(data: Data, kind: Kind = .auto) throws -> Config {
    let plist: Any
    do {
      plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    } catch {
      throw OpenWithError.invalidConfig("not a property list: \(error.localizedDescription)")
    }
    guard let dict = plist as? [String: Any] else {
      throw OpenWithError.invalidConfig("expected a dictionary at the top level")
    }
    if dict["PayloadContent"] != nil {
      return try importMobileconfig(dict)
    }
    guard let mapping = dict as? [String: String] else {
      throw OpenWithError.invalidConfig(
        "expected a flat <key>UTI-or-extension-or-scheme</key><string>bundle id</string> dictionary"
      )
    }
    return Config(associations: associations(from: mapping, kind: kind))
  }

  private static func importMobileconfig(_ dict: [String: Any]) throws -> Config {
    guard let payloads = dict["PayloadContent"] as? [[String: Any]] else {
      throw OpenWithError.invalidConfig("PayloadContent is not an array of payloads")
    }
    var result: [Association] = []
    for payload in payloads {
      let kind: Kind
      switch payload["PayloadType"] as? String {
      case "com.scriptingosx.utiluti.type": kind = .type
      case "com.scriptingosx.utiluti.url": kind = .url
      default: continue
      }
      // The mapping entries are the payload's string values that are not
      // reserved profile keys.
      var mapping: [String: String] = [:]
      for (key, value) in payload {
        guard !key.hasPrefix("Payload"), let bundleID = value as? String else { continue }
        mapping[key] = bundleID
      }
      result.append(contentsOf: associations(from: mapping, kind: kind))
    }
    guard !result.isEmpty else {
      throw OpenWithError.invalidConfig(
        "no com.scriptingosx.utiluti.type/.url payloads found in the profile")
    }
    return Config(associations: result)
  }

  private static func associations(from mapping: [String: String], kind: Kind) -> [Association] {
    // Sort for deterministic output across runs.
    mapping.sorted(by: { $0.key < $1.key }).map { key, bundleID in
      let target: Target
      if let ext = stripExtensionPrefix(key) {
        target = .ext(ext.lowercased())
      } else {
        switch kind {
        case .type: target = .uti(key)
        case .url: target = .urlScheme(key.lowercased())
        case .auto: target = key.contains(".") ? .uti(key) : .urlScheme(key.lowercased())
        }
      }
      return Association(target: target, app: AppRef(bundleID: bundleID), role: .all)
    }
  }

  private static func stripExtensionPrefix(_ key: String) -> String? {
    guard key.hasPrefix("extension:") else { return nil }
    return String(key.dropFirst("extension:".count))
  }

  // MARK: Export (lossy)

  /// The `key → bundle id` mapping of a utiluti *type* plist. Roles are
  /// dropped; role-specific entries collapse onto the same key.
  public static func typeMapping(_ config: Config) -> [String: String] {
    var mapping: [String: String] = [:]
    for association in config.associations {
      switch association.target {
      case .uti(let uti): mapping[uti] = association.app.bundleID
      case .ext(let ext): mapping["extension:\(ext)"] = association.app.bundleID
      case .urlScheme, .file: continue
      }
    }
    return mapping
  }

  /// The `scheme → bundle id` mapping of a utiluti *url* plist.
  public static func urlMapping(_ config: Config) -> [String: String] {
    var mapping: [String: String] = [:]
    for association in config.associations {
      if case .urlScheme(let scheme) = association.target {
        mapping[scheme] = association.app.bundleID
      }
    }
    return mapping
  }

  public static func exportTypePlist(_ config: Config) throws -> Data {
    try plistData(typeMapping(config))
  }

  public static func exportURLPlist(_ config: Config) throws -> Data {
    try plistData(urlMapping(config))
  }

  private static func plistData(_ mapping: [String: String]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: mapping, format: .xml, options: 0)
  }
}
