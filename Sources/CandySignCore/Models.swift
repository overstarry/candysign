import Foundation

public struct MachineFacts: Decodable, Sendable {
  public let productFamily: String
  public let friendlyNameEn: String
  public let friendlyNameZh: String?
  public var friendlyName: String {
    L10n.language == "zh-Hans" ? (friendlyNameZh ?? friendlyNameEn) : friendlyNameEn
  }
  public let maxPowerBudget: Double
  public let ports: [PortSpecification]
}

public struct PortSpecification: Decodable, Identifiable, Sendable {
  public let index: Int
  public let name: String
  public let power: Double
  public var id: Int { index }
}

public struct DeviceInfo: Decodable, Sendable {
  public let psn: String
  public let appVersion: String
  public let ssid: String?
  public let rssi: Int?
}

public struct PortDetails: Decodable, Sendable {
  public let ports: [PortReading]
}

public struct PortReading: Decodable, Identifiable, Sendable {
  public let port: Int
  public let connected: Bool
  public let voutMv: Double
  public let ioutMa: Double
  public let fcProtocol: String
  public let dieTemperature: String?
  public let deviceNameEn: String?
  public let powerBudget: Double?
  public var id: Int { port }
  public var watts: Double { voutMv * ioutMa / 1_000_000 }
}

public struct ChargingStatus: Decodable, Sendable {
  public let statusBitmask: Int

  public func isCharging(port: Int) -> Bool {
    guard (1...63).contains(port) else { return false }
    return statusBitmask & (1 << (port - 1)) != 0
  }
}

public struct TemperatureMode: Decodable, Sendable {
  public let mode: Int
  public var label: String {
    switch mode {
    case 0: L10n.text("Power priority")
    case 1: L10n.text("Temperature priority")
    default: L10n.text("Unknown mode")
    }
  }
}

public struct Snapshot: Sendable {
  public let facts: MachineFacts
  public let device: DeviceInfo
  public let details: PortDetails
  public let charging: ChargingStatus
  public let temperature: TemperatureMode?
  public let observedAt: Date

  public init(
    facts: MachineFacts, device: DeviceInfo, details: PortDetails,
    charging: ChargingStatus, temperature: TemperatureMode?, observedAt: Date = .now
  ) {
    self.facts = facts
    self.device = device
    self.details = details
    self.charging = charging
    self.temperature = temperature
    self.observedAt = observedAt
  }

  public var totalWatts: Double { details.ports.reduce(0) { $0 + $1.watts } }
  public var chargingCount: Int { facts.ports.filter { charging.isCharging(port: $0.index) }.count }
  /// Seconds after which a reading is stale and a sampling gap breaks the power curve.
  public static let maxAge: TimeInterval = 75
}

public struct PowerSample: Identifiable, Sendable {
  public let timestamp: Date
  public let watts: Double
  public let segment: Int
  public var id: Date { timestamp }
}

public struct PowerHistory: Sendable {
  public private(set) var samples: [Int: [PowerSample]] = [:]
  private var previousTime: Date?
  private var previousConnections: [Int: Bool] = [:]
  private var segments: [Int: Int] = [:]
  public init() {}

  public mutating func append(_ details: PortDetails, at timestamp: Date) {
    for reading in details.ports {
      let interrupted =
        previousTime.map { timestamp.timeIntervalSince($0) > Snapshot.maxAge } ?? false
      let reconnected = previousConnections[reading.port].map { $0 != reading.connected } ?? false
      if interrupted || reconnected { segments[reading.port, default: 0] += 1 }
      samples[reading.port, default: []].append(
        PowerSample(
          timestamp: timestamp, watts: reading.watts, segment: segments[reading.port, default: 0])
      )
      samples[reading.port]?.removeAll { timestamp.timeIntervalSince($0.timestamp) > 3_600 }
      if let count = samples[reading.port]?.count, count > 240 {
        samples[reading.port]?.removeFirst(count - 240)
      }
      previousConnections[reading.port] = reading.connected
    }
    previousTime = timestamp
  }
}

public enum DeviceDecoder {
  public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(type, from: data)
  }
}
