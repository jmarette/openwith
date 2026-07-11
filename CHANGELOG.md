# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `OpenWithCore` engine: read, list and set default applications for file
  types (UTIs), file extensions and URL schemes, with viewer/editor/all role
  support, on top of `NSWorkspace` and LaunchServices.
- `openwith` CLI: `get`, `set`, `list`, `apply`, `export`, `import`, `doctor`,
  `gui`, `completions` and `man` subcommands; `--json` output with pinned
  shapes on read commands.
- Native TOML config format (`schema = 1`) unifying types, extensions and URL
  schemes with roles; `apply` (with `--dry-run`) and `export`.
- utiluti interoperability: import flat type/URL plists and `.mobileconfig`
  profiles, either applying directly or converting to the native format;
  lossy `export --format utiluti`.
