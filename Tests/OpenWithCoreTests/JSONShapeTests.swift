import Testing

@testable import OpenWithCore

/// Pins the exact `--json` output bytes. These shapes are a machine API:
/// if one of these tests fails, either revert the change or bump
/// `JSONOutput.schemaVersion` and document the migration.
@Suite("Pinned JSON shapes")
struct JSONShapeTests {
  @Test func getShape() throws {
    let payload = JSONOutput.GetJSON(
      target: JSONOutput.TargetJSON(
        kind: "extension", input: "md", resolved: "net.daringfireball.markdown"),
      role: .all,
      app: .vscode)
    let expected = """
      {
        "app" : {
          "bundleID" : "com.microsoft.VSCode",
          "name" : "Visual Studio Code",
          "path" : "/Applications/Visual Studio Code.app"
        },
        "role" : "all",
        "schemaVersion" : 1,
        "target" : {
          "input" : "md",
          "kind" : "extension",
          "resolved" : "net.daringfireball.markdown"
        }
      }
      """
    #expect(try JSONOutput.encode(payload) == expected)
  }

  @Test func getShapeWithNoDefaultOmitsApp() throws {
    let payload = JSONOutput.GetJSON(
      target: JSONOutput.TargetJSON(kind: "scheme", input: "url:mailto", resolved: "mailto"),
      role: .all,
      app: nil)
    let expected = """
      {
        "role" : "all",
        "schemaVersion" : 1,
        "target" : {
          "input" : "url:mailto",
          "kind" : "scheme",
          "resolved" : "mailto"
        }
      }
      """
    #expect(try JSONOutput.encode(payload) == expected)
  }

  @Test func listShape() throws {
    let payload = JSONOutput.ListJSON(
      target: JSONOutput.TargetJSON(kind: "uti", input: "uti:public.html", resolved: "public.html"),
      role: .viewer,
      apps: [.safari, .firefox])
    let expected = """
      {
        "apps" : [
          {
            "bundleID" : "com.apple.Safari",
            "name" : "Safari",
            "path" : "/Applications/Safari.app"
          },
          {
            "bundleID" : "org.mozilla.firefox",
            "name" : "Firefox",
            "path" : "/Applications/Firefox.app"
          }
        ],
        "role" : "viewer",
        "schemaVersion" : 1,
        "target" : {
          "input" : "uti:public.html",
          "kind" : "uti",
          "resolved" : "public.html"
        }
      }
      """
    #expect(try JSONOutput.encode(payload) == expected)
  }

  @Test func doctorShape() throws {
    let payload = JSONOutput.DoctorJSON(diagnostics: [
      Diagnostic(.ok, "all good"),
      Diagnostic(.error, "entry #2: app 'x.y.z' is not installed"),
    ])
    let expected = """
      {
        "diagnostics" : [
          {
            "message" : "all good",
            "severity" : "ok"
          },
          {
            "message" : "entry #2: app 'x.y.z' is not installed",
            "severity" : "error"
          }
        ],
        "schemaVersion" : 1
      }
      """
    #expect(try JSONOutput.encode(payload) == expected)
  }
}
