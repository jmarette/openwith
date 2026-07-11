import Foundation

extension Target {
  /// Parses a user-supplied target string.
  ///
  /// Accepted forms:
  /// - `uti:public.html` — an explicit UTI
  /// - `ext:md` / `extension:md` — an explicit file extension
  /// - `url:mailto` / `scheme:mailto` / `mailto:` — a URL scheme
  /// - `/path/to/file`, `./file`, `~/file`, or any existing path — a file
  ///   whose content type is inferred at resolve time
  /// - `md` — a bare token: treated as a UTI when it contains a dot,
  ///   otherwise as a file extension. Use `ext:`/`uti:` to disambiguate.
  ///
  /// `fileExists` is injectable so parsing stays deterministic in tests.
  public static func parse(
    _ input: String,
    fileExists: (String) -> Bool = { path in
      FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
    }
  ) throws -> Target {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      throw OpenWithError.invalidTarget(input, hint: "empty target")
    }

    if let rest = strippingPrefix("uti:", from: trimmed) {
      return .uti(rest)
    }
    if let rest = strippingPrefix("ext:", from: trimmed)
      ?? strippingPrefix("extension:", from: trimmed)
    {
      return .ext(normalizedExtension(rest))
    }
    if let rest = strippingPrefix("url:", from: trimmed)
      ?? strippingPrefix("scheme:", from: trimmed)
    {
      return .urlScheme(normalizedScheme(rest))
    }

    // "mailto:" — a scheme written with its trailing colon.
    if trimmed.hasSuffix(":"), !trimmed.dropLast().contains(where: { $0 == ":" || $0 == "/" }) {
      return .urlScheme(normalizedScheme(String(trimmed.dropLast())))
    }

    if trimmed.hasPrefix("/") || trimmed.hasPrefix("./") || trimmed.hasPrefix("../")
      || trimmed.hasPrefix("~")
    {
      return .file(trimmed)
    }
    if fileExists(trimmed) {
      return .file(trimmed)
    }

    if trimmed.contains(".") {
      return .uti(trimmed)
    }
    return .ext(normalizedExtension(trimmed))
  }

  private static func strippingPrefix(_ prefix: String, from value: String) -> String? {
    guard value.lowercased().hasPrefix(prefix) else { return nil }
    let rest = String(value.dropFirst(prefix.count))
    guard !rest.isEmpty else { return nil }
    return rest
  }

  private static func normalizedExtension(_ ext: String) -> String {
    var value = ext.lowercased()
    while value.hasPrefix(".") { value.removeFirst() }
    return value
  }

  private static func normalizedScheme(_ scheme: String) -> String {
    var value = scheme.lowercased()
    if let colon = value.firstIndex(of: ":") { value = String(value[..<colon]) }
    return value
  }
}
