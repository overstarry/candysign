import AppKit
import CandySignCore
import SwiftUI

final class SettingsWindowController {
  private let store: DeviceStore
  private(set) var window: NSWindow?

  init(store: DeviceStore) {
    self.store = store
  }

  func show() {
    let window = window ?? makeWindow()
    if window.isMiniaturized { window.deminiaturize(nil) }
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let controller = NSHostingController(rootView: SettingsView(store: store))
    let window = NSWindow(contentViewController: controller)
    window.title = L10n.text("Settings…").replacingOccurrences(of: "…", with: "")
    window.identifier = NSUserInterfaceItemIdentifier("CandySign.Settings")
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.collectionBehavior.insert(.moveToActiveSpace)
    window.setContentSize(NSSize(width: 490, height: 440))
    window.center()
    self.window = window
    return window
  }
}
