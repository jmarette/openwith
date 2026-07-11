import ArgumentParser
import Foundation
import OpenWithCore

struct SetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set",
    abstract: "Set the default app for a target.",
    discussion: """
      macOS will ask you to confirm the change with a dialog. openwith reads
      the state back afterwards and exits non-zero if the change was not
      recorded (dialog declined or dismissed).
      """
  )

  @Argument(help: "md | ext:md | uti:public.html | url:mailto | /path/to/file")
  var target: String

  @Argument(help: "Bundle id (canonical), app name, or path to a .app bundle.")
  var app: String

  @Option(help: "Role to set: viewer, editor or all (URL schemes: all only).")
  var role: Role = .all

  func run() async throws {
    let engine = Engine.live()
    let parsed = try Target.parse(target)

    switch try await engine.setDefault(appReference: app, for: parsed, role: role) {
    case .alreadySet(let app):
      print("already set: \(target) → \(formatApp(app))")
    case .applied(let app):
      print("applied: \(target) → \(formatApp(app))")
    case .notConfirmed(let desired, let actual):
      let now = actual.map { "the default is still \(formatApp($0))" } ?? "no default is recorded"
      note(
        "not confirmed: macOS did not record \(target) → \(desired.bundleID) (the confirmation dialog was declined or dismissed); \(now)"
      )
      throw ExitCode(1)
    }
  }
}
