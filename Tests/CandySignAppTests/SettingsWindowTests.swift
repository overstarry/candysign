import AppKit
import Testing

@testable import CandySignApp

@Test @MainActor func settingsWindowCanBeOpenedClosedAndReused() {
  _ = NSApplication.shared
  let presenter = SettingsWindowController(store: DeviceStore(startMonitoring: false))
  #expect(presenter.window == nil)

  presenter.show()
  let first = presenter.window
  #expect(first?.isVisible == true)
  #expect(first?.canBecomeKey == true)
  #expect(first?.identifier?.rawValue == "CandySign.Settings")

  first?.close()
  #expect(first?.isVisible == false)
  presenter.show()
  #expect(presenter.window === first)
  #expect(first?.isVisible == true)

  presenter.show()
  #expect(presenter.window === first)
  first?.close()
}
