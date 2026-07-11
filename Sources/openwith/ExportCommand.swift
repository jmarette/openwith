import ArgumentParser
import Foundation
import OpenWithCore

enum ExportFormat: String, ExpressibleByArgument {
  case native
  case utiluti
}

struct ExportCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "export",
    abstract: "Snapshot the current defaults into a config file.",
    discussion: """
      Exports the current default app for each of openwith's curated types,
      extensions and URL schemes. The native format is TOML; --format utiluti
      writes utiluti-compatible plists instead (lossy: utiluti has no roles,
      and types and URLs are split into two files).
      """
  )

  @Argument(help: "Output file (stdout if omitted; required for --format utiluti).")
  var file: String?

  @Option(help: "native | utiluti")
  var format: ExportFormat = .native

  func validate() throws {
    if format == .utiluti && file == nil {
      throw ValidationError(
        "--format utiluti needs an output file: it writes <file>-types.plist and <file>-urls.plist."
      )
    }
  }

  func run() throws {
    let engine = Engine.live()
    let config = engine.exportCurrentDefaults()

    switch format {
    case .native:
      try writeOutput(try NativeConfig.encode(config), to: file)
      if let file {
        note("exported \(config.associations.count) association(s) to \(file)")
      }
    case .utiluti:
      let base = utilutiBase(file!)
      let typesPath = base + "-types.plist"
      let urlsPath = base + "-urls.plist"
      try Utiluti.exportTypePlist(config).write(to: URL(fileURLWithPath: typesPath))
      try Utiluti.exportURLPlist(config).write(to: URL(fileURLWithPath: urlsPath))
      note("exported \(typesPath) and \(urlsPath)")
      note("note: the utiluti format cannot express roles; role information was dropped.")
    }
  }

  private func utilutiBase(_ path: String) -> String {
    let expanded = (path as NSString).expandingTildeInPath
    return expanded.hasSuffix(".plist") ? String(expanded.dropLast(".plist".count)) : expanded
  }
}
