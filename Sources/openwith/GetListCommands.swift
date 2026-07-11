import ArgumentParser
import Foundation
import OpenWithCore

struct GetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "get",
    abstract: "Show the current default app for a target."
  )

  @Argument(help: "md | ext:md | uti:public.html | url:mailto | /path/to/file")
  var target: String

  @Option(help: "Role to query: viewer, editor or all.")
  var role: Role = .all

  @Flag(help: "Machine-readable output (pinned shape).")
  var json = false

  func run() throws {
    let engine = Engine.live()
    let parsed = try Target.parse(target)
    let resolved = try engine.resolve(parsed)
    let app = engine.currentDefault(for: resolved, role: role)

    if json {
      let payload = JSONOutput.GetJSON(
        target: JSONOutput.TargetJSON(input: target, target: parsed, resolved: resolved),
        role: role, app: app)
      print(try JSONOutput.encode(payload))
      return
    }

    print(formatTargetHeader(input: target, target: parsed, resolved: resolved, role: role))
    if let app {
      print("default: \(formatApp(app))")
    } else {
      print("default: none")
    }
  }
}

struct ListCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List all apps registered to handle a target."
  )

  @Argument(help: "md | ext:md | uti:public.html | url:mailto | /path/to/file")
  var target: String

  @Option(help: "Role to query: viewer, editor or all.")
  var role: Role = .all

  @Flag(help: "Machine-readable output (pinned shape).")
  var json = false

  func run() throws {
    let engine = Engine.live()
    let parsed = try Target.parse(target)
    let resolved = try engine.resolve(parsed)
    let apps: [AppInfo]
    switch resolved {
    case .contentType(let uti):
      apps = engine.provider.handlers(forContentType: uti, role: role)
    case .scheme(let scheme):
      apps = engine.provider.handlers(forScheme: scheme)
    }
    let current = engine.currentDefault(for: resolved, role: role)

    if json {
      let payload = JSONOutput.ListJSON(
        target: JSONOutput.TargetJSON(input: target, target: parsed, resolved: resolved),
        role: role, apps: apps)
      print(try JSONOutput.encode(payload))
      return
    }

    print(formatTargetHeader(input: target, target: parsed, resolved: resolved, role: role))
    if apps.isEmpty {
      print("no registered handlers")
      return
    }
    for app in apps {
      let marker = app.bundleID == current?.bundleID ? "*" : " "
      print("\(marker) \(formatApp(app))")
    }
  }
}
