import ArgumentParser
import Foundation
import OpenWithCore

struct ManCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "man",
    abstract: "Print the manual page (roff). Pipe to mandoc/groff or save as openwith.1.",
    discussion: """
      Examples:
        openwith man | mandoc -a
        openwith man > /usr/local/share/man/man1/openwith.1
      """
  )

  func run() throws {
    print(manPage)
  }
}

/// The single source of truth for the man page; the release pipeline stages
/// `openwith man > openwith.1` next to the binary.
let manPage = #"""
  .Dd July 11, 2026
  .Dt OPENWITH 1
  .Os macOS
  .Sh NAME
  .Nm openwith
  .Nd manage macOS default applications for file types and URL schemes
  .Sh SYNOPSIS
  .Nm
  .Ar subcommand
  .Op Ar options
  .Sh DESCRIPTION
  .Nm
  centralises the management of default applications on macOS: which app opens
  each file type (UTI), file extension and URL scheme, without visiting Finder's
  Get Info panel file by file.
  .Pp
  Targets accept several forms:
  .Bl -tag -width "uti:public.html" -compact
  .It Ar md
  a bare extension (tokens containing a dot are read as UTIs)
  .It Ar ext:md
  an explicit file extension
  .It Ar uti:public.html
  an explicit uniform type identifier
  .It Ar url:mailto
  a URL scheme
  .It Ar ./notes.md
  a file path; its content type is inferred
  .El
  .Pp
  Apps are referenced by bundle id (canonical), app name, or .app path.
  .Sh SUBCOMMANDS
  .Bl -tag -width "completions"
  .It Cm get Ar target Op Fl -role Ar role Op Fl -json
  Show the current default app for a target.
  .It Cm set Ar target Ar app Op Fl -role Ar role
  Set the default app. Roles: viewer, editor, all (default all; URL schemes
  support all only).
  .It Cm list Ar target Op Fl -role Ar role Op Fl -json
  List every app registered to handle the target; the current default is
  marked with *.
  .It Cm apply Ar file Op Fl -dry-run
  Apply a native TOML config.
  .It Cm export Op Ar file Op Fl -format Ar native|utiluti
  Snapshot the current defaults for the curated targets into a config.
  .It Cm import Ar file Oo Fl -from Ar auto|utiluti-plist|mobileconfig|native Oc \
  Oo Fl -convert-only Fl o Ar out Oc
  Import a utiluti config: apply it, or convert it to native TOML.
  .It Cm doctor Op Ar file Op Fl -json
  Environment sanity checks, or config validation.
  .It Cm gui
  Launch OpenWith.app if installed.
  .It Cm completions Ar zsh|bash|fish
  Print a shell completion script.
  .It Cm man
  Print this manual page.
  .El
  .Sh CONFIRMATION DIALOGS
  macOS asks the user to confirm every default-app change (one dialog per
  change since macOS 26.4; browser and mail changes have always prompted).
  This is an OS-level guard that applies to every tool. Consequently
  .Cm apply
  cannot change defaults silently in bulk.
  .Nm
  reads the state back after each write and reports honestly, exiting non-zero
  when a change was not recorded.
  .Sh EXIT STATUS
  .Ex -std
  Exits 1 when a change was declined or failed, or when
  .Cm doctor
  finds errors.
  .Sh EXAMPLES
  .Dl openwith get md
  .Dl openwith set md com.microsoft.VSCode --role editor
  .Dl openwith list url:mailto --json
  .Dl openwith export defaults.toml
  .Dl openwith apply defaults.toml --dry-run
  .Dl openwith import utiluti-types.plist --convert-only -o openwith.toml
  .Sh SEE ALSO
  .Xr duti 1 ,
  .Xr open 1
  .Pp
  https://github.com/jmarette/openwith
  .Sh AUTHORS
  .An Jonathan Marette
  """#
