import AppKit
import ArgumentParser
import Foundation
import OpenWithCore

struct GuiCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "gui",
    abstract: "Launch OpenWith.app if installed."
  )

  func run() async throws {
    let provider = LaunchServicesProvider()
    guard
      let app = provider.app(forBundleID: Branding.guiBundleID) ?? provider.app(named: "OpenWith")
    else {
      throw OpenWithError.guiNotInstalled
    }
    let url = URL(fileURLWithPath: app.path)
    _ = try await NSWorkspace.shared.openApplication(
      at: url, configuration: NSWorkspace.OpenConfiguration())
    print("launched \(formatApp(app))")
  }
}
