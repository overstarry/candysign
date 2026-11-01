import CandySignCore
import SwiftUI

struct SettingsView: View {
  @Bindable var store: DeviceStore
  @State private var endpoint = ""
  @State private var name = ""
  @State private var message: String?
  @State private var failed = false

  var body: some View {
    Form {
      Section(L10n.text("Device")) {
        TextField(L10n.text("Display name"), text: $name)
        SecureField(
          store.isConfigured
            ? L10n.text("New MCP address (optional)") : L10n.text("HTTPS MCP address"),
          text: $endpoint
        )
        .textContentType(.password)
        .autocorrectionDisabled()
        Text(
          L10n.text(
            "Your connection address is stored in macOS Keychain. Leave it blank to keep the saved connection."
          )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        HStack {
          Spacer()
          Button(L10n.text("Save Connection")) {
            apply {
              if endpoint.isEmpty, store.isConfigured {
                store.rename(name)
              } else {
                try store.configure(endpoint: MCPClient.validatedURL(endpoint), name: name)
              }
            }
          }
          .keyboardShortcut(.defaultAction)
        }
        if let message {
          Label {
            Text(message).foregroundStyle(.primary)
          } icon: {
            Image(systemName: failed ? "exclamationmark.triangle" : "checkmark.circle")
              .foregroundStyle(failed ? Color.orange : Color.secondary)
          }
          .font(.callout)
        }
      }
      Section {
        LabeledContent("CandySign", value: "0.1.0")
      }
    }
    .formStyle(.grouped)
    .frame(width: 490)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear { name = store.displayName }
  }

  private func apply(_ operation: () throws -> Void) {
    do {
      try operation()
      endpoint = ""
      name = store.displayName
      failed = false
      message = L10n.text("Saved. Connection status appears in the menu bar panel.")
    } catch {
      failed = true
      message = error.localizedDescription
    }
  }
}
