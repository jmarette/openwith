import Testing

@testable import OpenWithCore

@Suite("Native TOML config")
struct NativeConfigTests {
  @Test func decodesTheDocumentedExample() throws {
    let toml = """
      # openwith.toml
      schema = 1

      [[type]]
      uti  = "public.plain-text"
      app  = "com.microsoft.VSCode"   # bundle id (canonical)
      role = "editor"                 # viewer | editor | all  (default: all)

      [[type]]
      extension = "md"
      app       = "com.microsoft.VSCode"

      [[type]]
      uti      = "public.html"
      app      = "org.mozilla.firefox"
      app_path = "/Applications/Firefox.app"

      [[url]]
      scheme = "mailto"
      app    = "com.microsoft.Outlook"
      """
    let config = try NativeConfig.decode(toml: toml)

    #expect(config.schema == 1)
    #expect(config.associations.count == 4)
    #expect(
      config.associations[0]
        == Association(
          target: .uti("public.plain-text"),
          app: AppRef(bundleID: "com.microsoft.VSCode"),
          role: .editor))
    #expect(
      config.associations[1]
        == Association(
          target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"), role: .all))
    #expect(
      config.associations[2]
        == Association(
          target: .uti("public.html"),
          app: AppRef(bundleID: "org.mozilla.firefox", path: "/Applications/Firefox.app"),
          role: .all))
    #expect(
      config.associations[3]
        == Association(
          target: .urlScheme("mailto"),
          app: AppRef(bundleID: "com.microsoft.Outlook"),
          role: .all))
  }

  @Test func roundTrips() throws {
    let original = Config(associations: [
      Association(target: .uti("public.plain-text"), app: AppRef(bundleID: "a.b.c"), role: .editor),
      Association(target: .ext("md"), app: AppRef(bundleID: "a.b.c")),
      Association(
        target: .uti("public.html"),
        app: AppRef(bundleID: "d.e.f", path: "/Applications/F.app", name: "F")),
      Association(target: .urlScheme("mailto"), app: AppRef(bundleID: "g.h.i")),
    ])
    let toml = try NativeConfig.encode(original)
    let decoded = try NativeConfig.decode(toml: toml)
    #expect(decoded == original)
  }

  @Test func rejectsEntryWithBothUTIAndExtension() {
    let toml = """
      schema = 1
      [[type]]
      uti = "public.html"
      extension = "html"
      app = "a.b.c"
      """
    #expect(throws: OpenWithError.self) { try NativeConfig.decode(toml: toml) }
  }

  @Test func rejectsEntryWithNeitherUTINorExtension() {
    let toml = """
      schema = 1
      [[type]]
      app = "a.b.c"
      """
    #expect(throws: OpenWithError.self) { try NativeConfig.decode(toml: toml) }
  }

  @Test func rejectsNewerSchema() {
    let toml = "schema = 99"
    #expect(throws: OpenWithError.unsupportedSchema(99)) { try NativeConfig.decode(toml: toml) }
  }

  @Test func rejectsFilePathTargetsOnEncode() {
    let config = Config(associations: [
      Association(target: .file("/tmp/x.md"), app: AppRef(bundleID: "a.b.c"))
    ])
    #expect(throws: OpenWithError.self) { _ = try NativeConfig.encode(config) }
  }

  @Test func extensionsAreLowercasedOnDecode() throws {
    let toml = """
      schema = 1
      [[type]]
      extension = "MD"
      app = "a.b.c"
      """
    let config = try NativeConfig.decode(toml: toml)
    #expect(config.associations[0].target == .ext("md"))
  }
}
