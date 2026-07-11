import Foundation
import Testing

@testable import OpenWithCore

@Suite("utiluti interoperability")
struct UtilutiTests {
  private func plist(_ mapping: [String: String]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: mapping, format: .xml, options: 0)
  }

  @Test func importsFlatTypePlist() throws {
    let data = try plist([
      "public.html": "org.mozilla.firefox",
      "extension:md": "com.microsoft.VSCode",
    ])
    let config = try Utiluti.importConfig(data: data, kind: .auto)

    // Deterministic order: sorted by key.
    #expect(config.associations.count == 2)
    #expect(
      config.associations[0]
        == Association(
          target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"), role: .all))
    #expect(
      config.associations[1]
        == Association(
          target: .uti("public.html"), app: AppRef(bundleID: "org.mozilla.firefox"), role: .all))
  }

  @Test func importsFlatURLPlist() throws {
    let data = try plist(["mailto": "com.microsoft.Outlook"])
    let config = try Utiluti.importConfig(data: data, kind: .auto)
    #expect(
      config.associations
        == [
          Association(
            target: .urlScheme("mailto"), app: AppRef(bundleID: "com.microsoft.Outlook"),
            role: .all)
        ])
  }

  @Test func dottedSchemeNeedsExplicitURLKind() throws {
    // Heuristic limitation: dotted keys read as UTIs under .auto.
    let data = try plist(["com.example.scheme": "com.example.app"])
    let auto = try Utiluti.importConfig(data: data, kind: .auto)
    #expect(auto.associations[0].target == .uti("com.example.scheme"))

    let url = try Utiluti.importConfig(data: data, kind: .url)
    #expect(url.associations[0].target == .urlScheme("com.example.scheme"))
  }

  @Test func importsMobileconfig() throws {
    let profile: [String: Any] = [
      "PayloadType": "Configuration",
      "PayloadVersion": 1,
      "PayloadIdentifier": "com.example.defaults",
      "PayloadContent": [
        [
          "PayloadType": "com.scriptingosx.utiluti.type",
          "PayloadVersion": 1,
          "PayloadIdentifier": "com.example.defaults.types",
          "PayloadUUID": "00000000-0000-0000-0000-000000000001",
          "public.html": "org.mozilla.firefox",
          "extension:md": "com.microsoft.VSCode",
        ] as [String: Any],
        [
          "PayloadType": "com.scriptingosx.utiluti.url",
          "PayloadVersion": 1,
          "PayloadIdentifier": "com.example.defaults.urls",
          "PayloadUUID": "00000000-0000-0000-0000-000000000002",
          "mailto": "com.microsoft.Outlook",
        ] as [String: Any],
      ],
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: profile, format: .xml, options: 0)
    let config = try Utiluti.importConfig(data: data)

    #expect(config.associations.count == 3)
    #expect(
      config.associations.contains(
        Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"), role: .all)))
    #expect(
      config.associations.contains(
        Association(
          target: .uti("public.html"), app: AppRef(bundleID: "org.mozilla.firefox"), role: .all)))
    #expect(
      config.associations.contains(
        Association(
          target: .urlScheme("mailto"), app: AppRef(bundleID: "com.microsoft.Outlook"), role: .all))
    )
  }

  @Test func rejectsProfilesWithoutUtilutiPayloads() throws {
    let profile: [String: Any] = [
      "PayloadType": "Configuration",
      "PayloadContent": [["PayloadType": "com.example.other"] as [String: Any]],
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: profile, format: .xml, options: 0)
    #expect(throws: OpenWithError.self) { try Utiluti.importConfig(data: data) }
  }

  @Test func rejectsGarbage() {
    #expect(throws: OpenWithError.self) {
      try Utiluti.importConfig(data: Data("schema = 1".utf8))
    }
  }

  @Test func exportIsLossyButRoundTrippable() throws {
    let config = Config(associations: [
      Association(target: .uti("public.html"), app: AppRef(bundleID: "org.mozilla.firefox")),
      Association(
        target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"), role: .editor),
      Association(target: .urlScheme("mailto"), app: AppRef(bundleID: "com.microsoft.Outlook")),
    ])

    #expect(
      Utiluti.typeMapping(config)
        == [
          "public.html": "org.mozilla.firefox",
          "extension:md": "com.microsoft.VSCode",  // role dropped: lossy
        ])
    #expect(Utiluti.urlMapping(config) == ["mailto": "com.microsoft.Outlook"])

    // Round-trip through the plist bytes.
    let reimported = try Utiluti.importConfig(
      data: try Utiluti.exportTypePlist(config), kind: .type)
    #expect(reimported.associations.count == 2)
    #expect(reimported.associations.allSatisfy { $0.role == .all })
  }
}
