import ArgumentParser
import Foundation
import OpenWithCore

struct DoctorCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "doctor",
    abstract: "Sanity-check the environment, or validate a config file.",
    discussion: """
      Without an argument, runs basic environment checks. With a config file,
      validates it: unresolved bundle ids, missing apps, unknown types,
      duplicate or conflicting entries, and role misuse on URL schemes.
      """
  )

  @Argument(help: "Optional config file (TOML) to validate.")
  var file: String?

  @Flag(help: "Machine-readable output (pinned shape).")
  var json = false

  func run() throws {
    let engine = Engine.live()
    let diagnostics: [Diagnostic]
    if let file {
      let data = try readFile(file)
      let config = try NativeConfig.decode(toml: String(decoding: data, as: UTF8.self))
      diagnostics = engine.doctorConfig(config)
    } else {
      diagnostics = engine.doctorEnvironment()
    }

    if json {
      print(try JSONOutput.encode(JSONOutput.DoctorJSON(diagnostics: diagnostics)))
    } else {
      for diagnostic in diagnostics {
        let mark: String
        switch diagnostic.severity {
        case .ok: mark = "✓"
        case .warning: mark = "⚠"
        case .error: mark = "✗"
        }
        print("\(mark) \(diagnostic.message)")
      }
    }

    if diagnostics.contains(where: { $0.severity == .error }) {
      throw ExitCode(1)
    }
  }
}
