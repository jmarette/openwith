import Foundation
import UniformTypeIdentifiers

/// Augments the curated target list by scanning installed applications.
///
/// macOS has no API that enumerates "every" file type, so the GUI surfaces
/// the types users actually have handlers for: each app's declared
/// `CFBundleDocumentTypes` (content types and extensions) and
/// `CFBundleURLTypes` (URL schemes). Known limitation: types no installed
/// app declares will not appear; the CLI accepts them regardless.
public enum Discovery {
  public static let defaultDirectories: [String] = [
    "/Applications",
    "/Applications/Utilities",
    "/System/Applications",
    "/System/Applications/Utilities",
    (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
  ]

  /// Scans app bundles and returns targets not already covered by `existing`
  /// (compared on their raw value), labeled and categorised as `.discovered`.
  public static func discoverTargets(
    directories: [String] = defaultDirectories,
    existing: [CuratedTarget] = Curated.targets
  ) -> [CuratedTarget] {
    var seenTypes = Set<String>()
    var seenSchemes = Set<String>()
    for curated in existing {
      switch curated.target {
      case .uti(let uti): seenTypes.insert(uti)
      case .ext(let ext): seenTypes.insert(ext)
      case .urlScheme(let scheme): seenSchemes.insert(scheme)
      case .file: continue
      }
    }

    var discovered: [CuratedTarget] = []
    let fileManager = FileManager.default
    for directory in directories {
      guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
      for entry in entries where entry.hasSuffix(".app") {
        let url = URL(fileURLWithPath: directory).appendingPathComponent(entry)
        guard let info = Bundle(url: url)?.infoDictionary else { continue }

        for documentType in info["CFBundleDocumentTypes"] as? [[String: Any]] ?? [] {
          for uti in documentType["LSItemContentTypes"] as? [String] ?? [] {
            guard !uti.hasPrefix("dyn."), seenTypes.insert(uti).inserted else { continue }
            discovered.append(CuratedTarget(.uti(uti), label(forUTI: uti), .discovered))
          }
          for ext in documentType["CFBundleTypeExtensions"] as? [String] ?? [] {
            let normalized = ext.lowercased()
            guard normalized != "*", seenTypes.insert(normalized).inserted else { continue }
            discovered.append(
              CuratedTarget(.ext(normalized), "\(normalized) file (.\(normalized))", .discovered))
          }
        }
        for urlType in info["CFBundleURLTypes"] as? [[String: Any]] ?? [] {
          for scheme in urlType["CFBundleURLSchemes"] as? [String] ?? [] {
            let normalized = scheme.lowercased()
            guard seenSchemes.insert(normalized).inserted else { continue }
            discovered.append(
              CuratedTarget(.urlScheme(normalized), "\(normalized) links", .discovered))
          }
        }
      }
    }

    return discovered.sorted {
      $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
    }
  }

  private static func label(forUTI uti: String) -> String {
    if let type = UTType(uti), let description = type.localizedDescription, !description.isEmpty {
      return description
    }
    return uti
  }
}
