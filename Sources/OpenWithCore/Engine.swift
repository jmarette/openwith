import Foundation

/// The outcome of a single set-default operation.
///
/// `notConfirmed` means the write went through the API but the read-back did
/// not show the desired app — on current macOS that almost always means the
/// user declined (or has not yet answered) the OS confirmation dialog.
public enum SetOutcome: Sendable, Equatable {
  case alreadySet(AppInfo)
  case applied(AppInfo)
  case notConfirmed(desired: AppInfo, actual: AppInfo?)
}

/// High-level default-apps operations, generic over a LaunchServices provider.
public struct Engine: Sendable {
  public var provider: any LaunchServicesProviding

  public init(provider: any LaunchServicesProviding) {
    self.provider = provider
  }

  /// The engine backed by the machine's real LaunchServices database.
  public static func live() -> Engine {
    Engine(provider: LaunchServicesProvider())
  }

  // MARK: Resolution

  /// Resolves a parsed target to the UTI or scheme LaunchServices keys on.
  public func resolve(_ target: Target) throws -> ResolvedTarget {
    switch target {
    case .uti(let uti):
      return .contentType(uti)
    case .ext(let ext):
      guard let uti = provider.contentType(forExtension: ext) else {
        throw OpenWithError.unknownExtension(ext)
      }
      return .contentType(uti)
    case .urlScheme(let scheme):
      return .scheme(scheme)
    case .file(let path):
      let expanded = (path as NSString).expandingTildeInPath
      guard FileManager.default.fileExists(atPath: expanded) else {
        throw OpenWithError.fileNotFound(path)
      }
      guard let uti = provider.contentType(forFileAt: path) else {
        throw OpenWithError.fileTypeUnknown(path)
      }
      return .contentType(uti)
    }
  }

  /// Resolves an app reference (bundle id, app name, or .app path) to an
  /// installed application. The bundle id is the canonical key and is tried
  /// first for non-path references.
  public func resolveApp(_ reference: String) throws -> AppInfo {
    if reference.contains("/") || reference.lowercased().hasSuffix(".app")
      || reference.hasPrefix("~")
    {
      if let info = provider.app(atPath: reference) { return info }
    }
    if let info = provider.app(forBundleID: reference) { return info }
    if let info = provider.app(named: reference) { return info }
    throw OpenWithError.appNotFound(reference)
  }

  /// Resolves a config `AppRef`, falling back from bundle id to path to name.
  public func resolveApp(_ ref: AppRef) throws -> AppInfo {
    if let info = provider.app(forBundleID: ref.bundleID) { return info }
    if let path = ref.path, let info = provider.app(atPath: path) { return info }
    if let name = ref.name, let info = provider.app(named: name) { return info }
    throw OpenWithError.appNotFound(ref.bundleID)
  }

  // MARK: Reads

  public func currentDefault(for target: Target, role: Role = .all) throws -> AppInfo? {
    try currentDefault(for: resolve(target), role: role)
  }

  public func currentDefault(for resolved: ResolvedTarget, role: Role = .all) -> AppInfo? {
    switch resolved {
    case .contentType(let uti):
      return provider.defaultApp(forContentType: uti, role: role)
    case .scheme(let scheme):
      return provider.defaultApp(forScheme: scheme)
    }
  }

  public func handlers(for target: Target, role: Role = .all) throws -> [AppInfo] {
    switch try resolve(target) {
    case .contentType(let uti):
      return provider.handlers(forContentType: uti, role: role)
    case .scheme(let scheme):
      return provider.handlers(forScheme: scheme)
    }
  }

  // MARK: Writes

  /// Sets the default app for a target and verifies the change by reading it
  /// back. Idempotent: returns `.alreadySet` without writing when the target
  /// already points at the desired app.
  public func setDefault(
    appReference: String, for target: Target, role: Role = .all
  ) async throws -> SetOutcome {
    let app = try resolveApp(appReference)
    return try await setDefault(
      app: app, for: try resolve(target), role: roleValidated(role, target: target))
  }

  /// The primitive shared by `setDefault(appReference:...)` and `apply(_:)`.
  public func setDefault(
    app: AppInfo, for resolved: ResolvedTarget, role: Role = .all
  ) async throws -> SetOutcome {
    if case .scheme(let scheme) = resolved, role != .all {
      throw OpenWithError.roleNotSupportedForSchemes(scheme: scheme, role: role)
    }
    if let current = currentDefault(for: resolved, role: role), current.bundleID == app.bundleID {
      return .alreadySet(current)
    }

    var writeError: (any Error)?
    do {
      switch resolved {
      case .contentType(let uti):
        try await provider.setDefault(bundleID: app.bundleID, forContentType: uti, role: role)
      case .scheme(let scheme):
        try await provider.setDefault(bundleID: app.bundleID, forScheme: scheme)
      }
    } catch {
      writeError = error
    }

    // Trust the read-back, not the API result: the OS confirmation dialog
    // means a "successful" call may still have changed nothing.
    let actual = currentDefault(for: resolved, role: role)
    if actual?.bundleID == app.bundleID {
      return .applied(app)
    }
    if let error = writeError, !isUserDeclined(error) {
      throw OpenWithError.setFailed(
        target: resolved.value, reason: (error as NSError).localizedDescription)
    }
    return .notConfirmed(desired: app, actual: actual)
  }

  private func roleValidated(_ role: Role, target: Target) throws -> Role {
    if case .urlScheme(let scheme) = target, role != .all {
      throw OpenWithError.roleNotSupportedForSchemes(scheme: scheme, role: role)
    }
    return role
  }

  private func isUserDeclined(_ error: any Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
  }
}
