import Testing

@testable import OpenWithCore

@Suite("Target parsing")
struct TargetParsingTests {
  private func parse(_ input: String, fileExists: Bool = false) throws -> Target {
    try Target.parse(input, fileExists: { _ in fileExists })
  }

  @Test func bareExtension() throws {
    #expect(try parse("md") == .ext("md"))
    #expect(try parse("MD") == .ext("md"))
  }

  @Test func explicitExtension() throws {
    #expect(try parse("ext:md") == .ext("md"))
    #expect(try parse("ext:.md") == .ext("md"))
    #expect(try parse("extension:Md") == .ext("md"))
  }

  @Test func explicitUTI() throws {
    #expect(try parse("uti:public.html") == .uti("public.html"))
  }

  @Test func bareTokenWithDotIsUTI() throws {
    #expect(try parse("public.html") == .uti("public.html"))
    // Documented quirk: multi-part extensions need the ext: prefix.
    #expect(try parse("tar.gz") == .uti("tar.gz"))
    #expect(try parse("ext:tar.gz") == .ext("tar.gz"))
  }

  @Test func schemes() throws {
    #expect(try parse("url:mailto") == .urlScheme("mailto"))
    #expect(try parse("scheme:MailTo") == .urlScheme("mailto"))
    #expect(try parse("mailto:") == .urlScheme("mailto"))
    #expect(try parse("url:mailto:") == .urlScheme("mailto"))
  }

  @Test func filePaths() throws {
    #expect(try parse("/tmp/notes.md") == .file("/tmp/notes.md"))
    #expect(try parse("./notes.md") == .file("./notes.md"))
    #expect(try parse("../notes.md") == .file("../notes.md"))
    #expect(try parse("~/notes.md") == .file("~/notes.md"))
  }

  @Test func existingRelativeFileWinsOverUTI() throws {
    #expect(try parse("notes.md", fileExists: true) == .file("notes.md"))
    #expect(try parse("notes.md", fileExists: false) == .uti("notes.md"))
  }

  @Test func emptyTargetThrows() {
    #expect(throws: OpenWithError.invalidTarget("", hint: "empty target")) {
      try Target.parse("", fileExists: { _ in false })
    }
  }
}
