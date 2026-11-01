import CandySignCore
import Foundation

@main
struct Probe {
  @MainActor
  static func main() async {
    do {
      let input = FileHandle.standardInput.readDataToEndOfFile()
      guard let text = String(data: input, encoding: .utf8) else { throw MCPError.invalidEndpoint }
      let client = MCPClient(endpoint: try MCPClient.validatedURL(text))
      let facts = try await client.read("get_machine_facts", as: MachineFacts.self)
      let device = try await client.read("get_device_info", as: DeviceInfo.self)
      let details = try await client.read("get_port_details", as: PortDetails.self)
      let charging = try await client.read("get_charging_status", as: ChargingStatus.self)
      let temperature = try await client.read("get_temperature_mode", as: TemperatureMode.self)
      print("Model: \(facts.friendlyNameEn) (\(facts.productFamily))")
      print("Device: \(device.psn); firmware: \(device.appVersion)")
      print("Ports: \(facts.ports.count); capacity: \(facts.maxPowerBudget) W")
      print("Temperature: \(temperature.label)")
      for port in facts.ports {
        guard let reading = details.ports.first(where: { $0.port == port.index }) else {
          throw MCPError.invalidResponse
        }
        print(
          "\(port.name): connected=\(reading.connected), charging=\(charging.isCharging(port: port.index)), watts=\(reading.watts)"
        )
      }
    } catch let error as MCPError {
      print(error.localizedDescription)
      exit(1)
    } catch {
      print("Live verification failed. No credential or raw server error was logged.")
      exit(1)
    }
  }
}
