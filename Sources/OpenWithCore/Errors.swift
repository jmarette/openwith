import Foundation

public enum OpenWithError: Error, Equatable {
  case invalidTarget(String, hint: String)
  case fileNotFound(String)
  case fileTypeUnknown(String)
  case unknownExtension(String)
  case appNotFound(String)
  case roleNotSupportedForSchemes(scheme: String, role: Role)
  case unsupportedSchema(Int)
  case invalidConfig(String)
  case setFailed(target: String, reason: String)
  case guiNotInstalled
}

extension OpenWithError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidTarget(let input, let hint):
      return "invalid target '\(input)': \(hint)"
    case .fileNotFound(let path):
      return "file not found: \(path)"
    case .fileTypeUnknown(let path):
      return "could not determine the content type of \(path)"
    case .unknownExtension(let ext):
      return "could not resolve extension '\(ext)' to a content type"
    case .appNotFound(let ref):
      return
        "no installed application matches '\(ref)' (tried bundle id, app name and path)"
    case .roleNotSupportedForSchemes(let scheme, let role):
      return
        "URL schemes have no viewer/editor roles: use --role all for url:\(scheme) (got '\(role.rawValue)')"
    case .unsupportedSchema(let schema):
      return
        "config schema \(schema) is newer than the supported schema \(Config.currentSchema); upgrade openwith"
    case .invalidConfig(let message):
      return "invalid config: \(message)"
    case .setFailed(let target, let reason):
      return "failed to set default for \(target): \(reason)"
    case .guiNotInstalled:
      return
        "OpenWith.app is not installed; get it with: brew install --cask jmarette/tap/openwith-app"
    }
  }
}
