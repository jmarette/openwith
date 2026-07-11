import Foundation

/// The low-level operations `Engine` needs from LaunchServices.
///
/// The real implementation is `LaunchServicesProvider`; tests inject a fake
/// so the suite never mutates the machine's actual defaults.
public protocol LaunchServicesProviding: Sendable {
  // MARK: Reads

  func defaultApp(forContentType uti: String, role: Role) -> AppInfo?
  func defaultApp(forScheme scheme: String) -> AppInfo?
  func handlers(forContentType uti: String, role: Role) -> [AppInfo]
  func handlers(forScheme scheme: String) -> [AppInfo]

  // MARK: Writes

  /// Sets the default handler. On current macOS the OS asks the user to
  /// confirm; callers must read the state back instead of assuming success.
  func setDefault(bundleID: String, forContentType uti: String, role: Role) async throws
  func setDefault(bundleID: String, forScheme scheme: String) async throws

  // MARK: Application resolution

  func app(forBundleID bundleID: String) -> AppInfo?
  func app(atPath path: String) -> AppInfo?
  func app(named name: String) -> AppInfo?

  // MARK: Content-type resolution

  func contentType(forExtension ext: String) -> String?
  func contentType(forFileAt path: String) -> String?
  func localizedDescription(forContentType uti: String) -> String?
  func isDeclared(contentType uti: String) -> Bool
}
