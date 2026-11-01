import AppKit
import CandySignCore
import SwiftUI

@main
struct CandySignApplication: App {
  @State private var store: DeviceStore
  @State private var settings: SettingsWindowController
  #if DEBUG
    @State private var previewDark = false
  #endif

  init() {
    let store = DeviceStore()
    _store = State(initialValue: store)
    _settings = State(initialValue: SettingsWindowController(store: store))
  }

  var body: some Scene {
    MenuBarExtra {
      ChargerPanel(store: store, showSettings: settings.show)
    } label: {
      MenuLabel(store: store, showSettings: settings.show)
    }
    .menuBarExtraStyle(.window)

    .commands {
      CommandGroup(replacing: .appSettings) {
        Button(L10n.text("Settings…"), action: settings.show)
          .keyboardShortcut(",")
      }
    }

    #if DEBUG
      Window(L10n.text("CandySign Preview"), id: "preview") {
        ChargerPanel(store: store, showSettings: settings.show)
          .preferredColorScheme(previewDark ? .dark : .light)
          .fixedSize()
      }
      .windowResizability(.contentSize)
      .commands {
        CommandMenu(L10n.text("Preview")) {
          Toggle(L10n.text("Dark Appearance"), isOn: $previewDark)
        }
      }
    #endif

  }
}

private struct MenuLabel: View {
  let store: DeviceStore
  let showSettings: () -> Void
  #if DEBUG
    @Environment(\.openWindow) private var openWindow
  #endif

  var body: some View {
    Label {
      if let snapshot = store.snapshot, !store.isStale, store.errorMessage == nil {
        Text(PowerFormat.string(snapshot.totalWatts)).monospacedDigit()
      } else {
        Text(store.isConfigured ? "— W" : "CandySign")
      }
    } icon: {
      Image(systemName: store.errorMessage == nil ? "bolt.horizontal.circle" : "wifi.slash")
    }
    .accessibilityLabel(L10n.text("CandySign charging monitor"))
    .task {
      #if DEBUG
        await Task.yield()
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "preview")
      #else
        guard !UserDefaults.standard.bool(forKey: "hasShownSetup") else { return }
        UserDefaults.standard.set(true, forKey: "hasShownSetup")
        await Task.yield()
        NSApplication.shared.activate(ignoringOtherApps: true)
        showSettings()
      #endif
    }
  }
}
