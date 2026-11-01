import CandySignCore
import Charts
import SwiftUI

enum PowerFormat {
  static func string(_ watts: Double) -> String {
    watts.formatted(.number.precision(.fractionLength(watts > 0 && watts < 0.1 ? 3 : 1))) + " W"
  }
}

struct ChargerPanel: View {
  @Bindable var store: DeviceStore
  let showSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(20)
      Divider().padding(.horizontal, 20)

      if let snapshot = store.snapshot {
        summary(snapshot)
        if let message = store.errorMessage {
          Label {
            Text(message)
          } icon: {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
          }
          .font(.callout)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 20)
          .padding(.bottom, 12)
        }
        ScrollView {
          VStack(spacing: 0) {
            ForEach(snapshot.facts.ports) { port in
              PortRow(
                specification: port,
                reading: snapshot.details.ports.first { $0.port == port.index },
                charging: snapshot.charging.isCharging(port: port.index),
                samples: store.history.samples[port.index] ?? [],
                expanded: store.selectedPort == port.index
              ) {
                store.selectedPort = store.selectedPort == port.index ? nil : port.index
              }
              if port.index != snapshot.facts.ports.last?.index {
                Divider().padding(.leading, 52)
              }
            }
          }
          .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: store.selectedPort == nil ? 285 : 445)

        HStack(spacing: 6) {
          Image(systemName: "thermometer.medium")
          Text(snapshot.temperature?.label ?? L10n.text("Temperature mode unavailable"))
          Spacer()
          Text("v" + snapshot.device.appVersion)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
      } else {
        emptyState
      }

      Divider().padding(.horizontal, 20)
      footer
    }
    .frame(width: 390)
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "bolt.horizontal.circle.fill")
        .font(.system(size: 27, weight: .medium))
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(store.displayName)
          .font(.headline)
          .lineLimit(1)
          .help(store.displayName)
        Text(store.snapshot?.facts.friendlyName ?? L10n.text("Charging monitor"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      let status = connectionStatus
      Label {
        Text(status.0).foregroundStyle(.primary)
      } icon: {
        Image(systemName: status.1).foregroundStyle(status.2)
      }
      .font(.caption.weight(.medium))
    }
  }

  private var connectionStatus: (String, String, Color) {
    if !store.isConfigured { return (L10n.text("Set up"), "link", .secondary) }
    if store.errorMessage != nil { return (L10n.text("Offline"), "wifi.slash", .orange) }
    if store.snapshot == nil {
      return (L10n.text("Connecting"), "arrow.triangle.2.circlepath", .secondary)
    }
    if store.isStale { return (L10n.text("Stale"), "clock", .orange) }
    return (L10n.text("Connected"), "checkmark.circle.fill", .green)
  }

  private func summary(_ snapshot: Snapshot) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(PowerFormat.string(snapshot.totalWatts))
          .font(.system(size: 30, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .accessibilityLabel(
            L10n.format("Total output, %@", PowerFormat.string(snapshot.totalWatts)))
        Spacer()
        Text(
          snapshot.chargingCount == 0
            ? L10n.text("No active charging") : L10n.format("%ld charging", snapshot.chargingCount)
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      ProgressView(
        value: min(max(snapshot.totalWatts, 0), snapshot.facts.maxPowerBudget),
        total: max(snapshot.facts.maxPowerBudget, 1)
      )
      .tint(.orange)
      .accessibilityLabel(L10n.text("Output relative to rated capacity"))
      HStack {
        Text(L10n.format("%ld W total capacity", Int(snapshot.facts.maxPowerBudget)))
        Spacer()
        Text(
          store.isStale || store.errorMessage != nil
            ? L10n.text("Last known reading") : L10n.text("Live output"))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(20)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      if store.isRefreshing {
        ProgressView()
        Text(L10n.text("Connecting to your charger…")).font(.headline)
      } else {
        Image(systemName: store.isConfigured ? "wifi.exclamationmark" : "powerplug")
          .font(.system(size: 32))
          .foregroundStyle(.secondary)
        Text(
          store.isConfigured ? L10n.text("Charger unavailable") : L10n.text("Connect your CoCan")
        )
        .font(.headline)
        Text(
          store.errorMessage
            ?? L10n.text("Add your MCP connection in Settings to see live charging data.")
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        if store.isConfigured {
          Button(L10n.text("Try Again")) { store.refresh() }
        } else {
          Button(L10n.text("Open Settings…"), action: showSettings)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Button {
          store.refresh()
        } label: {
          Label(
            store.isRefreshing ? L10n.text("Refreshing…") : L10n.text("Refresh"),
            systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r")
        .disabled(store.isRefreshing || !store.isConfigured)
        Spacer()
        if let date = store.snapshot?.observedAt {
          Text(date, format: .dateTime.hour().minute().second())
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .help(L10n.text("Last successful reading"))
        }
      }
      HStack {
        Button(action: showSettings) { Label(L10n.text("Settings…"), systemImage: "gearshape") }
          .keyboardShortcut(",")
        Spacer()
        Button(L10n.text("Quit CandySign")) { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q")
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
    .font(.callout)
    .padding(20)
  }
}

private struct PortRow: View {
  let specification: PortSpecification
  let reading: PortReading?
  let charging: Bool
  let samples: [PowerSample]
  let expanded: Bool
  let toggle: () -> Void

  private var state: String {
    guard let reading else { return L10n.text("Data unavailable") }
    if charging { return L10n.text("Charging") }
    return reading.connected ? L10n.text("Connected · not charging") : L10n.text("Not connected")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: toggle) {
        HStack(spacing: 10) {
          Text(specification.name)
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .frame(width: 30, alignment: .leading)
          VStack(alignment: .leading, spacing: 4) {
            Text(
              reading?.connected == true
                ? (reading?.deviceNameEn ?? L10n.text("Unidentified device"))
                : L10n.text("No device")
            )
            .font(.callout.weight(.medium))
            .lineLimit(1)
            Text(state)
              .font(.caption)
              .foregroundStyle(charging ? Color.primary : Color.secondary)
          }
          Spacer(minLength: 4)
          Text(reading.map { PowerFormat.string($0.watts) } ?? "— W")
            .font(.callout.weight(.semibold))
            .monospacedDigit()
          Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        L10n.format(
          "Port %@, %@, %@", specification.name, state,
          reading.map { PowerFormat.string($0.watts) } ?? L10n.text("unavailable"))
      )
      .accessibilityHint(
        expanded ? L10n.text("Collapse details") : L10n.text("Expand details and power history"))

      if expanded {
        details
          .padding(.leading, 40)
          .padding(.bottom, 14)
      }
    }
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let reading {
        HStack {
          Text("\((reading.voutMv / 1_000).formatted(.number.precision(.fractionLength(3)))) V")
          Text("·")
          Text("\(reading.ioutMa.formatted(.number.precision(.fractionLength(0)))) mA")
          Spacer()
          Text(reading.dieTemperature.map { L10n.text($0) } ?? L10n.text("Unknown temperature"))
        }
        .font(.caption)
        .monospacedDigit()
        Text(
          L10n.format(
            "%@ · %ld W port limit", L10n.text(reading.fcProtocol), Int(specification.power))
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      if samples.count > 1 {
        Chart(samples) { sample in
          LineMark(
            x: .value(L10n.text("Time"), sample.timestamp),
            y: .value(L10n.text("Power"), sample.watts),
            series: .value(L10n.text("Segment"), sample.segment)
          )
          .foregroundStyle(.orange)
          .lineStyle(StrokeStyle(lineWidth: 1.8))
        }
        .chartYScale(domain: 0...max(1, (samples.map(\.watts).max() ?? 0) * 1.15))
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartXAxis(.hidden)
        .frame(height: 80)
        .accessibilityLabel(
          L10n.format("Port %@ power history in watts, current app session", specification.name))
        HStack {
          if let first = samples.first {
            Text(first.timestamp, format: .dateTime.hour().minute())
          }
          Spacer()
          if let last = samples.last {
            Text(last.timestamp, format: .dateTime.hour().minute())
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
      } else {
        Text(L10n.text("Collecting samples…"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(height: 50)
      }
      Text(L10n.text("Current session · up to 1 hour · W"))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}
