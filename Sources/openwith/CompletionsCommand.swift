import ArgumentParser
import Foundation

struct CompletionsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "completions",
    abstract: "Print a shell completion script (zsh, bash or fish).",
    discussion: """
      Examples:
        openwith completions zsh  > ~/.zsh/completions/_openwith
        openwith completions bash > /usr/local/etc/bash_completion.d/openwith
        openwith completions fish > ~/.config/fish/completions/openwith.fish
      """
  )

  enum Shell: String, ExpressibleByArgument, CaseIterable {
    case zsh
    case bash
    case fish
  }

  @Argument(help: "zsh | bash | fish")
  var shell: Shell = .zsh

  func run() throws {
    // ArgumentParser generates completions via a flag on the root command;
    // re-exec ourselves so the subcommand stays the documented interface.
    guard let executable = Bundle.main.executablePath else {
      throw ValidationError("cannot locate the openwith executable")
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = ["--generate-completion-script", shell.rawValue]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
      throw ExitCode(process.terminationStatus)
    }
  }
}
