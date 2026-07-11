import ArgumentParser
import OpenWithCore

@main
struct OpenWithCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "openwith",
    abstract: "Manage macOS default applications for file types, extensions and URL schemes.",
    discussion: """
      Targets accept several forms:
        md                a bare extension (tokens with a dot are read as UTIs)
        ext:md            an explicit file extension
        uti:public.html   an explicit uniform type identifier
        url:mailto        a URL scheme
        ./notes.md        a file path — its content type is inferred

      Apps are referenced by bundle id (canonical), app name, or .app path.

      Note: macOS asks you to confirm every default-app change with a dialog
      (one per change since macOS 26.4; browser and mail changes have always
      prompted). This applies to every tool, not just openwith. After each
      write, openwith reads the real state back and reports it honestly.
      """,
    version: OpenWithVersion.string,
    subcommands: [
      GetCommand.self,
      SetCommand.self,
      ListCommand.self,
      ApplyCommand.self,
      ExportCommand.self,
      ImportCommand.self,
      DoctorCommand.self,
      GuiCommand.self,
      CompletionsCommand.self,
      ManCommand.self,
    ]
  )
}
