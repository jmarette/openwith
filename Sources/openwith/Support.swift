import ArgumentParser
import Foundation
import OpenWithCore

extension Role: ExpressibleByArgument {}
extension Utiluti.Kind: ExpressibleByArgument {}

/// Prints to stderr, keeping stdout clean for data (`--json`, TOML, plists).
func note(_ message: String) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
}

func formatApp(_ app: AppInfo) -> String {
  "\(app.name) (\(app.bundleID)) — \(app.path)"
}

func formatTargetHeader(input: String, target: Target, resolved: ResolvedTarget, role: Role)
  -> String
{
  var line = "target: \(input)"
  if input != resolved.value {
    line += " → \(resolved.value)"
  }
  if case .contentType = resolved {
    line += " [role: \(role.rawValue)]"
  }
  return line
}

/// Shared by `apply` and `import`: runs a config against the live engine and
/// prints one line per association plus a summary. Returns the exit code.
func runApply(config: Config, dryRun: Bool) async -> Int32 {
  let engine = Engine.live()
  if !dryRun && !config.associations.isEmpty {
    note("note: macOS will ask you to confirm each change.")
  }
  let results = await engine.apply(config, dryRun: dryRun)

  var applied = 0
  var already = 0
  var would = 0
  var notConfirmed = 0
  var failed = 0
  for result in results {
    let target = result.association.target.description
    let app = result.association.app.bundleID
    switch result.status {
    case .wouldSet(let current):
      would += 1
      let from = current.map { " (now \($0.bundleID))" } ?? " (no current default)"
      print("would set   \(target) → \(app)\(from)")
    case .alreadySet:
      already += 1
      print("already set \(target) → \(app)")
    case .applied:
      applied += 1
      print("applied     \(target) → \(app)")
    case .notConfirmed(let actual):
      notConfirmed += 1
      let now = actual.map { "still \($0)" } ?? "no default recorded"
      print("declined    \(target) → \(app) (confirmation dialog not accepted; \(now))")
    case .failed(let message):
      failed += 1
      print("failed      \(target) → \(app): \(message)")
    }
  }

  var summary: [String] = []
  if dryRun { summary.append("\(would) would change") }
  if applied > 0 || !dryRun { summary.append("\(applied) applied") }
  summary.append("\(already) already set")
  if notConfirmed > 0 { summary.append("\(notConfirmed) not confirmed") }
  if failed > 0 { summary.append("\(failed) failed") }
  print("—— \(summary.joined(separator: ", "))")

  return (notConfirmed + failed) > 0 ? 1 : 0
}

func readFile(_ path: String) throws -> Data {
  let expanded = (path as NSString).expandingTildeInPath
  guard let data = FileManager.default.contents(atPath: expanded) else {
    throw OpenWithError.fileNotFound(path)
  }
  return data
}

func writeOutput(_ text: String, to path: String?) throws {
  guard let path else {
    print(text, terminator: text.hasSuffix("\n") ? "" : "\n")
    return
  }
  let expanded = (path as NSString).expandingTildeInPath
  try text.write(toFile: expanded, atomically: true, encoding: .utf8)
}
