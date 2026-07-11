import AppKit
import OpenWithUI
import PreferencePanes
import SwiftUI

/// The legacy System Settings pane: the same SwiftUI UI as OpenWith.app,
/// embedded via NSHostingView. Third-party panes appear at the bottom of the
/// System Settings sidebar on Ventura and later; this bundle is a backup to
/// the standalone app, not the primary experience.
@objc(OpenWithPreferencePane)
public final class OpenWithPreferencePane: NSPreferencePane {
  public override func loadMainView() -> NSView {
    let hosting = NSHostingView(rootView: DefaultsView())
    hosting.frame = NSRect(x: 0, y: 0, width: 668, height: 560)
    hosting.autoresizingMask = [.width, .height]
    mainView = hosting
    return hosting
  }
}
