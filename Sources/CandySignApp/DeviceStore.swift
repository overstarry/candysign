import AppKit
import CandySignCore
import Foundation
import Observation

@Observable
final class DeviceStore {
  var snapshot: Snapshot?
  var history = PowerHistory()
  var errorMessage: String?
  var isRefreshing = false
  var isStale = true
  var displayName = UserDefaults.standard.string(forKey: "deviceName") ?? L10n.text("CoCan 2838")
  var selectedPort: Int?
  var isConfigured: Bool { endpoint != nil }
  private var endpoint: URL?
  private var client: MCPClient?
  private var pollingTask: Task<Void, Never>?
  private var refreshTask: Task<Void, Never>?
  private var freshnessTask: Task<Void, Never>?
  private var generation = 0
  private var sleeping = false
  private var facts: MachineFacts?
  private var device: DeviceInfo?
  private var metadataReadAt: Date?
  private var sleepObserver: NSObjectProtocol?
  private var wakeObserver: NSObjectProtocol?

  init(startMonitoring: Bool = true) {
    guard startMonitoring else { return }
    let center = NSWorkspace.shared.notificationCenter
    sleepObserver = center.addObserver(
      forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in self?.sleep() }
    }
    wakeObserver = center.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in self?.wake() }
    }
    do {
      if let endpoint = try Credentials.load() { connect(endpoint) }
    } catch {
      errorMessage = L10n.text("Could not load the saved connection. Open Settings to reconnect.")
    }
  }

  func configure(endpoint: URL, name: String) throws {
    try Credentials.save(endpoint)
    rename(name)
    connect(endpoint)
  }

  /// A blank name restores the default.
  func rename(_ name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      UserDefaults.standard.removeObject(forKey: "deviceName")
      displayName = L10n.text("CoCan 2838")
    } else {
      UserDefaults.standard.set(trimmed, forKey: "deviceName")
      displayName = trimmed
    }
  }

  func refresh() {
    guard !sleeping, !isRefreshing, let client else { return }
    let currentGeneration = generation
    isRefreshing = true
    refreshTask = Task { [weak self] in
      guard let self else { return }
      defer {
        if currentGeneration == generation {
          isRefreshing = false
          refreshTask = nil
        }
      }
      do {
        let needsMetadata = metadataReadAt.map { Date.now.timeIntervalSince($0) > 300 } ?? true
        let nextFacts: MachineFacts
        let nextDevice: DeviceInfo
        if let facts, let device, !needsMetadata {
          nextFacts = facts
          nextDevice = device
        } else {
          nextFacts = try await client.read("get_machine_facts", as: MachineFacts.self)
          nextDevice = try await client.read("get_device_info", as: DeviceInfo.self)
        }
        let details = try await client.read("get_port_details", as: PortDetails.self)
        let observedAt = Date.now
        let charging = try await client.read("get_charging_status", as: ChargingStatus.self)
        let temperature = try? await client.read("get_temperature_mode", as: TemperatureMode.self)
        try Task.checkCancellation()
        guard currentGeneration == generation else { return }
        if snapshot?.device.psn != nextDevice.psn { history = PowerHistory() }
        facts = nextFacts
        device = nextDevice
        if needsMetadata { metadataReadAt = .now }
        snapshot = Snapshot(
          facts: nextFacts, device: nextDevice, details: details,
          charging: charging, temperature: temperature, observedAt: observedAt)
        scheduleExpiration(observedAt: observedAt)
        history.append(details, at: observedAt)
        errorMessage = nil
      } catch {
        guard currentGeneration == generation, !Task.isCancelled else { return }
        if let error = error as? MCPError {
          errorMessage = error.localizedDescription
        } else if error is DecodingError {
          errorMessage = L10n.text("Some device data could not be read. Try refreshing.")
        } else {
          errorMessage = L10n.text(
            "Cannot reach the charger. Check your network and try refreshing.")
        }
      }
    }
  }

  private func connect(_ endpoint: URL) {
    stopTasks()
    self.endpoint = endpoint
    snapshot = nil
    history = PowerHistory()
    facts = nil
    device = nil
    metadataReadAt = nil
    selectedPort = nil
    errorMessage = nil
    if !sleeping { startPolling() }
  }

  private func startPolling() {
    guard let endpoint else { return }
    pollingTask?.cancel()
    // A cancelled refresh may still be suspended on the old client; a new client keeps
    // its session state from interleaving with this run.
    client = MCPClient(endpoint: endpoint)
    refresh()
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(30)) } catch { return }
        guard let self else { return }
        refresh()
      }
    }
  }

  private func stopTasks() {
    generation += 1
    pollingTask?.cancel()
    refreshTask?.cancel()
    freshnessTask?.cancel()
    pollingTask = nil
    refreshTask = nil
    freshnessTask = nil
    isRefreshing = false
    isStale = true
  }

  func scheduleExpiration(observedAt: Date) {
    freshnessTask?.cancel()
    let remaining = max(0, Snapshot.maxAge - Date.now.timeIntervalSince(observedAt))
    isStale = remaining == 0
    freshnessTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
      guard let self, !Task.isCancelled else { return }
      isStale = true
    }
  }

  private func sleep() {
    sleeping = true
    stopTasks()
  }
  private func wake() {
    sleeping = false
    metadataReadAt = nil
    startPolling()
  }
}
