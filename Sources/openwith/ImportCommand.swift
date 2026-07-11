import ArgumentParser
import Foundation
import OpenWithCore

enum ImportSource: String, ExpressibleByArgument {
  case auto
  case utilutiPlist = "utiluti-plist"
  case mobileconfig
  case native
}

struct ImportCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "import",
    abstract: "Import a utiluti (or native) config: apply it, or convert it to TOML.",
    discussion: """
      Reads utiluti's flat type/URL plists and .mobileconfig profiles, or a
      native openwith TOML file. By default the associations are applied
      directly (macOS confirms each change); with --convert-only the file is
      converted to the native TOML format instead of being applied.

      utiluti has no role concept, so imported entries get role = all.
      """
  )

  @Argument(help: "Path to the file to import.")
  var file: String

  @Option(name: .customLong("from"), help: "auto | utiluti-plist | mobileconfig | native")
  var from: ImportSource = .auto

  @Option(
    name: .customLong("kind"),
    help: "For flat utiluti plists: interpret keys as 'type' or 'url' ('auto' guesses).")
  var kind: Utiluti.Kind = .auto

  @Flag(name: .customLong("convert-only"), help: "Convert to native TOML instead of applying.")
  var convertOnly = false

  @Option(name: .shortAndLong, help: "Output file for --convert-only (stdout if omitted).")
  var output: String?

  @Flag(name: .customLong("dry-run"), help: "Show what applying would change, without writing.")
  var dryRun = false

  func validate() throws {
    if output != nil && !convertOnly {
      throw ValidationError("-o/--output only makes sense with --convert-only.")
    }
    if convertOnly && dryRun {
      throw ValidationError("--convert-only and --dry-run are mutually exclusive.")
    }
  }

  func run() async throws {
    let data = try readFile(file)
    let config = try parse(data)

    if convertOnly {
      try writeOutput(try NativeConfig.encode(config), to: output)
      if let output {
        note("converted \(config.associations.count) association(s) to \(output)")
      }
      return
    }

    let code = await runApply(config: config, dryRun: dryRun)
    if code != 0 { throw ExitCode(code) }
  }

  private func parse(_ data: Data) throws -> Config {
    switch from {
    case .native:
      return try NativeConfig.decode(toml: String(decoding: data, as: UTF8.self))
    case .utilutiPlist, .mobileconfig:
      return try Utiluti.importConfig(data: data, kind: kind)
    case .auto:
      // Property lists fail fast on TOML text (and vice versa), so probing
      // is unambiguous: try utiluti first, then native.
      if let config = try? Utiluti.importConfig(data: data, kind: kind) {
        return config
      }
      return try NativeConfig.decode(toml: String(decoding: data, as: UTF8.self))
    }
  }
}
