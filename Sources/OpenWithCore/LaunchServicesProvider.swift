import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

/// The real LaunchServices-backed provider.
///
/// Uses the modern `NSWorkspace` APIs wherever they can express the
/// operation, and drops to the LaunchServices C API for role-specific
/// (viewer/editor) reads and writes, which `NSWorkspace` cannot express.
public struct LaunchServicesProvider: LaunchServicesProviding {
  public init() {}

  private var workspace: NSWorkspace { NSWorkspace.shared }

  // MARK: Reads

  public func defaultApp(forContentType uti: String, role: Role) -> AppInfo? {
    if role == .all, let type = UTType(uti) {
      guard let url = workspace.urlForApplication(toOpen: type) else { return nil }
      return appInfo(at: url)
    }
    guard
      let bundleID = LSCopyDefaultRoleHandlerForContentType(uti as CFString, role.lsRolesMask)?
        .takeRetainedValue() as String?
    else { return nil }
    return app(forBundleID: bundleID)
  }

  public func defaultApp(forScheme scheme: String) -> AppInfo? {
    guard let url = URL(string: "\(scheme):"),
      let appURL = workspace.urlForApplication(toOpen: url)
    else { return nil }
    return appInfo(at: appURL)
  }

  public func handlers(forContentType uti: String, role: Role) -> [AppInfo] {
    if role == .all, let type = UTType(uti) {
      return workspace.urlsForApplications(toOpen: type).compactMap(appInfo(at:))
    }
    guard
      let ids = LSCopyAllRoleHandlersForContentType(uti as CFString, role.lsRolesMask)?
        .takeRetainedValue() as? [String]
    else { return [] }
    return ids.compactMap(app(forBundleID:))
  }

  public func handlers(forScheme scheme: String) -> [AppInfo] {
    guard let url = URL(string: "\(scheme):") else { return [] }
    return workspace.urlsForApplications(toOpen: url).compactMap(appInfo(at:))
  }

  // MARK: Writes

  public func setDefault(bundleID: String, forContentType uti: String, role: Role) async throws {
    guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
      throw OpenWithError.appNotFound(bundleID)
    }
    if role == .all, let type = UTType(uti) {
      try await workspace.setDefaultApplication(at: appURL, toOpen: type)
      return
    }
    // Role-specific writes (and undeclared UTIs) go through LaunchServices.
    let status = LSSetDefaultRoleHandlerForContentType(
      uti as CFString, role.lsRolesMask, bundleID as CFString)
    guard status == noErr else {
      throw OpenWithError.setFailed(target: "uti:\(uti)", reason: "LaunchServices error \(status)")
    }
  }

  public func setDefault(bundleID: String, forScheme scheme: String) async throws {
    guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
      throw OpenWithError.appNotFound(bundleID)
    }
    try await workspace.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme)
  }

  // MARK: Application resolution

  public func app(forBundleID bundleID: String) -> AppInfo? {
    guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
    return appInfo(at: url)
  }

  public func app(atPath path: String) -> AppInfo? {
    let expanded = (path as NSString).expandingTildeInPath
    guard FileManager.default.fileExists(atPath: expanded) else { return nil }
    return appInfo(at: URL(fileURLWithPath: expanded))
  }

  public func app(named name: String) -> AppInfo? {
    let fileManager = FileManager.default
    let wanted = name.lowercased()
    let candidates = [wanted, wanted.hasSuffix(".app") ? wanted : wanted + ".app"]
    for directory in Self.applicationDirectories {
      guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
      for entry in entries where candidates.contains(entry.lowercased()) {
        if let info = app(atPath: (directory as NSString).appendingPathComponent(entry)) {
          return info
        }
      }
    }
    return nil
  }

  private static let applicationDirectories: [String] = [
    "/Applications",
    "/Applications/Utilities",
    "/System/Applications",
    "/System/Applications/Utilities",
    (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
  ]

  private func appInfo(at url: URL) -> AppInfo? {
    guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
    let info = bundle.infoDictionary ?? [:]
    let name =
      (info["CFBundleDisplayName"] as? String)
      ?? (info["CFBundleName"] as? String)
      ?? url.deletingPathExtension().lastPathComponent
    return AppInfo(bundleID: bundleID, name: name, path: url.path)
  }

  // MARK: Content-type resolution

  public func contentType(forExtension ext: String) -> String? {
    UTType(filenameExtension: ext)?.identifier
  }

  public func contentType(forFileAt path: String) -> String? {
    let expanded = (path as NSString).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded)
    if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
      return type.identifier
    }
    let ext = url.pathExtension
    guard !ext.isEmpty else { return nil }
    return contentType(forExtension: ext)
  }

  public func localizedDescription(forContentType uti: String) -> String? {
    UTType(uti)?.localizedDescription
  }

  public func isDeclared(contentType uti: String) -> Bool {
    UTType(uti)?.isDeclared ?? false
  }
}

extension Role {
  var lsRolesMask: LSRolesMask {
    switch self {
    case .viewer: return .viewer
    case .editor: return .editor
    case .all: return .all
    }
  }
}
