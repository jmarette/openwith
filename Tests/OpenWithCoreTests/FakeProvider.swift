import Foundation
import Synchronization

@testable import OpenWithCore

/// In-memory LaunchServices stand-in. Tests must never touch the machine's
/// real defaults, so the whole database is injectable state.
final class FakeProvider: LaunchServicesProviding, Sendable {
  struct State: Sendable {
    var apps: [AppInfo] = []
    /// "uti|role" → bundle id
    var typeDefaults: [String: String] = [:]
    var schemeDefaults: [String: String] = [:]
    var typeHandlers: [String: [String]] = [:]
    var schemeHandlers: [String: [String]] = [:]
    var extensionMap: [String: String] = [:]
    var fileTypes: [String: String] = [:]
    var declared: Set<String> = []
    var descriptions: [String: String] = [:]
    /// Simulates the user declining the macOS confirmation dialog: the write
    /// call "succeeds" but nothing changes.
    var declineWrites = false
    var writeLog: [String] = []
  }

  let state: Mutex<State>

  init(_ configure: (inout State) -> Void = { _ in }) {
    var initial = State()
    configure(&initial)
    state = Mutex(initial)
  }

  var writeLog: [String] { state.withLock { $0.writeLog } }

  // MARK: Reads

  func defaultApp(forContentType uti: String, role: Role) -> AppInfo? {
    state.withLock { current in
      guard let bundleID = current.typeDefaults["\(uti)|\(role.rawValue)"] else { return nil }
      return current.apps.first { $0.bundleID == bundleID }
    }
  }

  func defaultApp(forScheme scheme: String) -> AppInfo? {
    state.withLock { current in
      guard let bundleID = current.schemeDefaults[scheme] else { return nil }
      return current.apps.first { $0.bundleID == bundleID }
    }
  }

  func handlers(forContentType uti: String, role: Role) -> [AppInfo] {
    state.withLock { current in
      (current.typeHandlers[uti] ?? []).compactMap { id in
        current.apps.first { $0.bundleID == id }
      }
    }
  }

  func handlers(forScheme scheme: String) -> [AppInfo] {
    state.withLock { current in
      (current.schemeHandlers[scheme] ?? []).compactMap { id in
        current.apps.first { $0.bundleID == id }
      }
    }
  }

  // MARK: Writes

  func setDefault(bundleID: String, forContentType uti: String, role: Role) async throws {
    state.withLock { current in
      current.writeLog.append("type:\(uti)|\(role.rawValue)=\(bundleID)")
      guard !current.declineWrites else { return }
      current.typeDefaults["\(uti)|\(role.rawValue)"] = bundleID
      if role == .all {
        current.typeDefaults["\(uti)|viewer"] = bundleID
        current.typeDefaults["\(uti)|editor"] = bundleID
      }
    }
  }

  func setDefault(bundleID: String, forScheme scheme: String) async throws {
    state.withLock { current in
      current.writeLog.append("scheme:\(scheme)=\(bundleID)")
      guard !current.declineWrites else { return }
      current.schemeDefaults[scheme] = bundleID
    }
  }

  // MARK: Application resolution

  func app(forBundleID bundleID: String) -> AppInfo? {
    state.withLock { current in current.apps.first { $0.bundleID == bundleID } }
  }

  func app(atPath path: String) -> AppInfo? {
    state.withLock { current in current.apps.first { $0.path == path } }
  }

  func app(named name: String) -> AppInfo? {
    state.withLock { current in
      current.apps.first { $0.name.lowercased() == name.lowercased() }
    }
  }

  // MARK: Content-type resolution

  func contentType(forExtension ext: String) -> String? {
    state.withLock { $0.extensionMap[ext] }
  }

  func contentType(forFileAt path: String) -> String? {
    state.withLock { $0.fileTypes[path] }
  }

  func localizedDescription(forContentType uti: String) -> String? {
    state.withLock { $0.descriptions[uti] }
  }

  func isDeclared(contentType uti: String) -> Bool {
    state.withLock { $0.declared.contains(uti) }
  }
}

// MARK: Shared fixtures

extension AppInfo {
  static let vscode = AppInfo(
    bundleID: "com.microsoft.VSCode",
    name: "Visual Studio Code",
    path: "/Applications/Visual Studio Code.app")
  static let safari = AppInfo(
    bundleID: "com.apple.Safari",
    name: "Safari",
    path: "/Applications/Safari.app")
  static let firefox = AppInfo(
    bundleID: "org.mozilla.firefox",
    name: "Firefox",
    path: "/Applications/Firefox.app")
  static let outlook = AppInfo(
    bundleID: "com.microsoft.Outlook",
    name: "Microsoft Outlook",
    path: "/Applications/Microsoft Outlook.app")
}

extension FakeProvider {
  /// A little machine: VS Code + Safari + Firefox + Outlook, markdown and
  /// html types, http/mailto schemes.
  static func standard(_ extra: @Sendable (inout State) -> Void = { _ in }) -> FakeProvider {
    FakeProvider { state in
      state.apps = [.vscode, .safari, .firefox, .outlook]
      state.extensionMap = [
        "md": "net.daringfireball.markdown",
        "html": "public.html",
        "txt": "public.plain-text",
      ]
      state.declared = ["net.daringfireball.markdown", "public.html", "public.plain-text"]
      state.typeDefaults = [
        "public.html|all": "com.apple.Safari",
        "public.html|viewer": "com.apple.Safari",
        "public.html|editor": "com.apple.Safari",
      ]
      state.typeHandlers = [
        "public.html": ["com.apple.Safari", "org.mozilla.firefox", "com.microsoft.VSCode"],
        "net.daringfireball.markdown": ["com.microsoft.VSCode"],
      ]
      state.schemeDefaults = ["http": "com.apple.Safari"]
      state.schemeHandlers = ["http": ["com.apple.Safari", "org.mozilla.firefox"]]
      state.descriptions = ["public.html": "HTML document"]
      extra(&state)
    }
  }
}
