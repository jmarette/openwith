import Testing

@testable import OpenWithCore

@Suite("Doctor")
struct DoctorTests {
  private func diagnostics(_ associations: [Association]) -> [Diagnostic] {
    Engine(provider: FakeProvider.standard()).doctorConfig(Config(associations: associations))
  }

  @Test func cleanConfigReportsOK() {
    let result = diagnostics([
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"))
    ])
    #expect(result.count == 1)
    #expect(result[0].severity == .ok)
  }

  @Test func missingAppIsAnError() {
    let result = diagnostics([
      Association(target: .ext("md"), app: AppRef(bundleID: "com.example.ghost"))
    ])
    #expect(result.contains { $0.severity == .error && $0.message.contains("com.example.ghost") })
  }

  @Test func pathFallbackIsAWarning() {
    let result = diagnostics([
      Association(
        target: .ext("md"),
        app: AppRef(bundleID: "com.example.ghost", path: "/Applications/Firefox.app"))
    ])
    #expect(result.contains { $0.severity == .warning && $0.message.contains("app_path") })
    #expect(!result.contains { $0.severity == .error })
  }

  @Test func undeclaredUTIIsAWarning() {
    let result = diagnostics([
      Association(target: .uti("com.example.mystery"), app: AppRef(bundleID: "com.apple.Safari"))
    ])
    #expect(result.contains { $0.severity == .warning && $0.message.contains("not declared") })
  }

  @Test func unknownExtensionIsAnError() {
    let result = diagnostics([
      Association(target: .ext("zzz"), app: AppRef(bundleID: "com.apple.Safari"))
    ])
    #expect(result.contains { $0.severity == .error && $0.message.contains("'zzz'") })
  }

  @Test func roleOnSchemeIsAnError() {
    let result = diagnostics([
      Association(
        target: .urlScheme("mailto"), app: AppRef(bundleID: "com.microsoft.Outlook"),
        role: .viewer)
    ])
    #expect(result.contains { $0.severity == .error && $0.message.contains("no roles") })
  }

  @Test func conflictingEntriesAreErrors() {
    let result = diagnostics([
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode")),
      Association(target: .ext("md"), app: AppRef(bundleID: "com.apple.Safari")),
    ])
    #expect(result.contains { $0.severity == .error && $0.message.contains("conflicts") })
  }

  @Test func duplicateEntriesAreWarnings() {
    let result = diagnostics([
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode")),
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode")),
    ])
    #expect(result.contains { $0.severity == .warning && $0.message.contains("duplicate") })
  }

  @Test func sameTargetDifferentRolesDoNotConflict() {
    let result = diagnostics([
      Association(target: .ext("md"), app: AppRef(bundleID: "com.microsoft.VSCode"), role: .editor),
      Association(target: .ext("md"), app: AppRef(bundleID: "com.apple.Safari"), role: .viewer),
    ])
    #expect(!result.contains { $0.severity == .error })
  }
}
