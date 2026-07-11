import Foundation
import Testing

@testable import OpenWithCore

@Suite("Engine")
struct EngineTests {
  @Test func resolvesExtensionsToUTIs() throws {
    let engine = Engine(provider: FakeProvider.standard())
    #expect(try engine.resolve(.ext("md")) == .contentType("net.daringfireball.markdown"))
    #expect(try engine.resolve(.uti("public.html")) == .contentType("public.html"))
    #expect(try engine.resolve(.urlScheme("mailto")) == .scheme("mailto"))
    #expect(throws: OpenWithError.unknownExtension("nope")) {
      try engine.resolve(.ext("nope"))
    }
  }

  @Test func resolvesAppReferences() throws {
    let engine = Engine(provider: FakeProvider.standard())
    #expect(try engine.resolveApp("com.microsoft.VSCode") == .vscode)
    #expect(try engine.resolveApp("Visual Studio Code") == .vscode)
    #expect(try engine.resolveApp("/Applications/Safari.app") == .safari)
    #expect(throws: OpenWithError.appNotFound("com.example.ghost")) {
      try engine.resolveApp("com.example.ghost")
    }
  }

  @Test func appRefFallsBackFromBundleIDToPathToName() throws {
    let engine = Engine(provider: FakeProvider.standard())
    #expect(
      try engine.resolveApp(
        AppRef(bundleID: "com.example.ghost", path: "/Applications/Firefox.app"))
        == .firefox)
    #expect(
      try engine.resolveApp(AppRef(bundleID: "com.example.ghost", name: "Safari")) == .safari)
  }

  @Test func readsCurrentDefaults() throws {
    let engine = Engine(provider: FakeProvider.standard())
    #expect(try engine.currentDefault(for: .ext("html"))?.bundleID == "com.apple.Safari")
    #expect(try engine.currentDefault(for: .urlScheme("http"))?.bundleID == "com.apple.Safari")
    #expect(try engine.currentDefault(for: .ext("md")) == nil)
  }

  @Test func setIsIdempotent() async throws {
    let provider = FakeProvider.standard()
    let engine = Engine(provider: provider)
    let outcome = try await engine.setDefault(
      appReference: "com.apple.Safari", for: .ext("html"))
    #expect(outcome == .alreadySet(.safari))
    #expect(provider.writeLog.isEmpty)
  }

  @Test func setWritesAndVerifies() async throws {
    let provider = FakeProvider.standard()
    let engine = Engine(provider: provider)
    let outcome = try await engine.setDefault(
      appReference: "org.mozilla.firefox", for: .ext("html"))
    #expect(outcome == .applied(.firefox))
    #expect(provider.writeLog == ["type:public.html|all=org.mozilla.firefox"])
  }

  @Test func setReportsDeclinedConfirmations() async throws {
    let provider = FakeProvider.standard { $0.declineWrites = true }
    let engine = Engine(provider: provider)
    let outcome = try await engine.setDefault(
      appReference: "org.mozilla.firefox", for: .ext("html"))
    #expect(outcome == .notConfirmed(desired: .firefox, actual: .safari))
  }

  @Test func rolesGoThroughForTypes() async throws {
    let provider = FakeProvider.standard()
    let engine = Engine(provider: provider)
    let outcome = try await engine.setDefault(
      appReference: "com.microsoft.VSCode", for: .ext("md"), role: .editor)
    #expect(outcome == .applied(.vscode))
    #expect(provider.writeLog == ["type:net.daringfireball.markdown|editor=com.microsoft.VSCode"])
  }

  @Test func rolesAreRejectedForSchemes() async {
    let engine = Engine(provider: FakeProvider.standard())
    await #expect(throws: OpenWithError.roleNotSupportedForSchemes(scheme: "mailto", role: .editor))
    {
      _ = try await engine.setDefault(
        appReference: "com.microsoft.Outlook", for: .urlScheme("mailto"), role: .editor)
    }
  }

  @Test func applyIsSequentialIdempotentAndHonest() async throws {
    let provider = FakeProvider.standard { $0.schemeHandlers["mailto"] = ["com.microsoft.Outlook"] }
    let engine = Engine(provider: provider)
    let config = Config(associations: [
      // Already set → skipped.
      Association(target: .uti("public.html"), app: AppRef(bundleID: "com.apple.Safari")),
      // A real change.
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode")),
      // A scheme change.
      Association(target: .urlScheme("mailto"), app: AppRef(bundleID: "com.microsoft.Outlook")),
      // An app that is not installed.
      Association(target: .ext("txt"), app: AppRef(bundleID: "com.example.ghost")),
    ])

    let results = await engine.apply(config)
    #expect(results.count == 4)
    #expect(results[0].status == .alreadySet)
    #expect(results[1].status == .applied)
    #expect(results[2].status == .applied)
    #expect(results[0].isFailure == false)
    if case .failed = results[3].status {
    } else {
      Issue.record("expected .failed, got \(results[3].status)")
    }
    #expect(
      provider.writeLog
        == [
          "type:net.daringfireball.markdown|all=com.microsoft.VSCode",
          "scheme:mailto=com.microsoft.Outlook",
        ])
  }

  @Test func applyDryRunWritesNothing() async throws {
    let provider = FakeProvider.standard()
    let engine = Engine(provider: provider)
    let config = Config(associations: [
      Association(target: .uti("public.html"), app: AppRef(bundleID: "com.apple.Safari")),
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode")),
    ])

    let results = await engine.apply(config, dryRun: true)
    #expect(results[0].status == .alreadySet)
    #expect(results[1].status == .wouldSet(current: nil))
    #expect(provider.writeLog.isEmpty)
  }

  @Test func applyReportsDeclinedChanges() async throws {
    let provider = FakeProvider.standard { $0.declineWrites = true }
    let engine = Engine(provider: provider)
    let config = Config(associations: [
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"))
    ])

    let results = await engine.apply(config)
    #expect(results[0].status == .notConfirmed(actual: nil))
    #expect(results[0].isFailure)
  }

  @Test func exportSnapshotsCurrentDefaults() throws {
    let engine = Engine(provider: FakeProvider.standard())
    let curated = [
      CuratedTarget(.uti("public.html"), "HTML", .web),
      CuratedTarget(.ext("html"), "HTML file", .web),  // same resolved UTI → deduped
      CuratedTarget(.ext("md"), "Markdown", .text),  // no default → skipped
      CuratedTarget(.urlScheme("http"), "Web links", .urlSchemes),
    ]
    let config = engine.exportCurrentDefaults(targets: curated)
    #expect(
      config.associations
        == [
          Association(
            target: .uti("public.html"),
            app: AppRef(
              bundleID: "com.apple.Safari", path: "/Applications/Safari.app", name: "Safari"),
            role: .all),
          Association(
            target: .urlScheme("http"),
            app: AppRef(
              bundleID: "com.apple.Safari", path: "/Applications/Safari.app", name: "Safari"),
            role: .all),
        ])
  }
}
