# openwith

Manage macOS default applications — which app opens each file type, file
extension and URL scheme — from one place, instead of hunting through
Finder's *Get Info* panel file by file.

One Swift engine, three frontends:

- **`openwith`** — a scriptable CLI (the primary interface)
- **OpenWith.app** — a SwiftUI GUI listing every known type with a picker
- **OpenWithPane.prefPane** — a legacy System Settings pane, as a backup

It replaces the abandoned *SwiftDefaultApps* and complements the CLI-only
*duti* / *utiluti* (whose configs it can import) with a single maintained,
all-Swift project. macOS 15+, universal (Apple Silicon + Intel).

## How it works

macOS keeps the "opens with" database in LaunchServices, keyed by uniform
type identifiers (UTIs) and URL schemes. `openwith` talks to it through the
modern `NSWorkspace` APIs, dropping to the LaunchServices C API only for
viewer/editor **roles**, which `NSWorkspace` cannot express. Extensions and
file paths are resolved to their UTI at apply time; apps are identified by
bundle id (canonical), with app names and `.app` paths accepted and
normalised.

Two things follow from how macOS works, and no tool can bypass them:

- **macOS confirms every change.** Since macOS 26.4 LaunchServices shows a
  confirmation dialog for *every* file-type default change (browser and mail
  changes have always prompted). Bulk-applying a config therefore means one
  dialog per change. `openwith` never pretends: after each write it reads
  the database back and reports what macOS actually recorded, exiting
  non-zero when a change was declined.
- **There is no API that lists "all" file types.** The GUI seeds its table
  from a curated list of common types and augments it by scanning installed
  apps' declared document types and URL schemes. Types no app declares will
  not appear in the table — the CLI accepts them regardless.

## Install

```console
brew install jmarette/tap/openwith             # CLI
brew install --cask jmarette/tap/openwith-app  # GUI (unsigned: see caveats)
brew install --cask jmarette/tap/openwith-pane # System Settings pane (optional)
```

Or grab a tarball / the shell installer from the
[releases page](https://github.com/jmarette/openwith/releases); the PrefPane
also ships there as `OpenWith-Pane-<version>.zip` (unzip into
`~/Library/PreferencePanes/`). It appears at the bottom of the System
Settings sidebar.

## Commands

```console
openwith get md                        # who opens .md files?
openwith set md com.microsoft.VSCode   # change it (macOS asks to confirm)
openwith set md "Visual Studio Code"   # app names and .app paths work too
openwith set html Safari --role viewer # role-specific default
openwith list url:mailto               # every app claiming mailto:
openwith export defaults.toml          # snapshot current defaults
openwith apply defaults.toml           # re-apply them (idempotent)
openwith apply defaults.toml --dry-run # preview without writing
openwith import utiluti.plist          # migrate from utiluti
openwith doctor defaults.toml          # validate a config
openwith gui                           # launch OpenWith.app
```

Targets accept a bare extension (`md`), explicit prefixes (`ext:md`,
`uti:public.html`, `url:mailto`), or a file path whose type is inferred.
Bare tokens containing a dot are read as UTIs — use `ext:tar.gz` to force
the extension reading.

Roles: `--role viewer|editor|all` (default `all`). URL schemes have no
roles.

### Config file

One TOML document for everything, hand-editable and commentable:

```toml
schema = 1

[[type]]
uti  = "public.plain-text"
app  = "com.microsoft.VSCode"   # bundle id (canonical)
role = "editor"                 # viewer | editor | all  (default: all)

[[type]]
extension = "md"                # resolved to its UTI on apply
app       = "com.microsoft.VSCode"

[[type]]
uti      = "public.html"
app      = "org.mozilla.firefox"
app_path = "/Applications/Firefox.app"   # fallback if the bundle id is absent

[[url]]
scheme = "mailto"
app    = "com.microsoft.Outlook"
```

`apply` skips associations that already hold, verifies each write, and
reports per-entry results.

### utiluti migration

`openwith import` reads utiluti's flat type/URL plists and its
`.mobileconfig` profiles (payload types `com.scriptingosx.utiluti.type` /
`.url`), either applying them directly or converting with
`--convert-only -o openwith.toml`. utiluti has no role concept, so imported
entries get `role = all`; `openwith export --format utiluti` round-trips the
other way (lossy: roles are dropped, types and URLs split into two files).

## Scripting (JSON)

Read commands take `--json` with pinned, tested output shapes (a
`schemaVersion` field guards future changes):

```console
$ openwith get md --json
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
```

`list --json` returns the same `target` plus an `apps` array; `doctor
--json` returns `diagnostics` with `severity` (`ok`/`warning`/`error`).

## Caveats

- **Confirmation dialogs.** Every default change pops an OS confirmation
  (see *How it works*). Expect one dialog per changed entry during `apply`.
- **Unsigned app.** The project has no Apple Developer account, so the app
  and pane are ad-hoc signed and not notarized. On first launch,
  right-click → *Open*, or clear quarantine:
  `xattr -dr com.apple.quarantine /Applications/OpenWith.app`. The Homebrew
  cask prints the same instructions.
- **PrefPane is legacy.** Third-party panes appear at the bottom of the
  System Settings sidebar through the legacy mechanism; being unsigned, the
  pane needs an explicit approval on first open. It is a backup, not the
  flagship.
- **Dynamic UTIs.** Extensions no installed app declares (for example `rs`
  on a machine without a Rust editor) resolve to dynamic `dyn.*`
  identifiers. Setting a default for them works; `doctor` flags them so you
  know why they look opaque.

## Uninstall

```console
brew uninstall openwith
brew uninstall --cask openwith-app
brew uninstall --cask openwith-pane                      # or, if manual:
rm -rf ~/Library/PreferencePanes/OpenWithPane.prefPane
```

`openwith` stores nothing outside LaunchServices; removing the tool leaves
your defaults exactly as they are.

## Development

```console
swift build            # core + CLI
swift test             # unit tests (never touch your real defaults)
swift format lint --strict --recursive Package.swift Sources Tests   # CI gate
xcodegen generate --spec Apps/project.yml   # regenerate the Xcode project
scripts/package-app.sh                      # build + sign + package app/pane
```

All logic lives in `Sources/OpenWithCore`; the CLI, app and pane are thin
shells (the app and pane share their SwiftUI views via `OpenWithUI`). Tests
inject a fake LaunchServices provider — they must never mutate the
machine's real defaults.

## Releasing

Releases are cut by [dist](https://opensource.axo.dev/cargo-dist/) in
generic mode. Bump `version` in `dist-workspace.toml` **and**
`OpenWithVersion` in `Sources/OpenWithCore/Model.swift` (CI checks they
agree), update `CHANGELOG.md`, then tag `vX.Y.Z` and push the tag. CI
builds the universal binary, creates the GitHub Release, updates the
Homebrew formula on `jmarette/homebrew-tap`, and the `publish-app` job
attaches the dmg/zip and refreshes the cask. Never move or delete a
published tag — ship a new version instead.

## License

Dual-licensed under either of

- MIT license ([LICENSE-MIT](LICENSE-MIT))
- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))

at your option.
