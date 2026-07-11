import ArgumentParser
import Foundation
import OpenWithCore

struct ApplyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "apply",
    abstract: "Apply a native openwith config (TOML).",
    discussion: """
      Applies each association in the file, in order, skipping the ones that
      already hold. macOS asks you to confirm each actual change — silent
      bulk-apply is not possible on current macOS; expect one dialog per
      change.
      """
  )

  @Argument(help: "Path to an openwith TOML config.")
  var file: String

  @Flag(name: .customLong("dry-run"), help: "Show what would change without writing.")
  var dryRun = false

  func run() async throws {
    let data = try readFile(file)
    let config = try NativeConfig.decode(toml: String(decoding: data, as: UTF8.self))
    let code = await runApply(config: config, dryRun: dryRun)
    if code != 0 { throw ExitCode(code) }
  }
}
