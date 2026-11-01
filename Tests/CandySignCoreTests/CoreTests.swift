import Foundation
import Testing

@testable import CandySignCore

private func data(_ text: String) -> Data { Data(text.utf8) }

@Test func readsActualSnakeCaseFieldsAndMillivoltUnits() throws {
  let details = try DeviceDecoder.decode(
    PortDetails.self,
    from: data(
      """
      {"ports":[{"port":4,"connected":true,"vout_mv":5008,"iout_ma":3,
      "fc_protocol":"Not Charging","die_temperature":"cool"}]}
      """))
  let reading = try #require(details.ports.first)
  #expect(abs(reading.watts - 0.015024) < 0.000001)
  #expect(reading.deviceNameEn == nil)
  #expect(reading.powerBudget == nil)
  #expect(reading.connected)
  let status = try DeviceDecoder.decode(ChargingStatus.self, from: data("{\"status_bitmask\":0}"))
  #expect(!status.isCharging(port: 4))
}

@Test func decodesOneIndexedChargingBits() throws {
  let status = try DeviceDecoder.decode(ChargingStatus.self, from: data("{\"status_bitmask\":9}"))
  #expect(status.isCharging(port: 1))
  #expect(status.isCharging(port: 4))
  #expect(!status.isCharging(port: 2))
  #expect(!status.isCharging(port: 0))
  #expect(!status.isCharging(port: 64))
}

@Test func parsesRawSSEStreamWithBlankLineBoundaries() throws {
  let stream = """
    : heartbeat\n\nevent: message\r\ndata: {"jsonrpc":"2.0",\r\ndata: "id":7,"result":{"ok":true}}\r\n\r\n\n\
    data: {"jsonrpc":"2.0","id":8,"result":{}}\n\ndata: unterminated\n
    """
  var parser = SSEDecoder()
  let events = stream.utf8.compactMap { parser.consume($0) }
  #expect(events.count == 2)
  #expect(try MCPCodec.result(from: events[0], expectedID: 7)["ok"] == .bool(true))
  #expect(try MCPCodec.result(from: events[1], expectedID: 8) == .object([:]))
}

@Test func rejectsMismatchedResponseAndRedactsRPCErrors() throws {
  #expect(throws: MCPError.invalidResponse) {
    try MCPCodec.result(from: data("{\"jsonrpc\":\"2.0\",\"id\":9,\"result\":{}}"), expectedID: 8)
  }
  #expect(throws: MCPError.rpc(-32602)) {
    try MCPCodec.result(
      from: data(
        """
        {"jsonrpc":"2.0","id":8,"error":{"code":-32602,"message":"secret endpoint"}}
        """), expectedID: 8)
  }
}

@Test func extractsStructuredAndTextToolDataAndRejectsToolErrors() throws {
  let structured = JSONValue.object(["structuredContent": .object(["mode": .number(0)])])
  #expect(
    try DeviceDecoder.decode(TemperatureMode.self, from: MCPCodec.toolData(from: structured)).mode
      == 0)
  let text = JSONValue.object([
    "content": .array([
      .object(["type": .string("text"), "text": .string("{\"mode\":1}")])
    ])
  ])
  #expect(
    try DeviceDecoder.decode(TemperatureMode.self, from: MCPCodec.toolData(from: text)).mode == 1)
  #expect(throws: MCPError.toolFailure) {
    try MCPCodec.toolData(from: .object(["isError": .bool(true), "content": .array([])]))
  }
}

@Test @MainActor func rejectsInsecureOrCredentialBearingAuthority() {
  for endpoint in [
    "http://example.com/mcp", "https://user:password@example.com/mcp",
    "https://example.com/mcp#token", "garbage",
  ] {
    #expect(throws: MCPError.invalidEndpoint) { try MCPClient.validatedURL(endpoint) }
  }
  #expect(throws: Never.self) { try MCPClient.validatedURL("https://example.com/device/token/mcp") }
}

@Test func historyKeepsGapsAndConnectionBoundariesAndIsBounded() throws {
  let connected = try DeviceDecoder.decode(
    PortDetails.self,
    from: data(
      """
      {"ports":[{"port":1,"connected":true,"vout_mv":5000,"iout_ma":1000,"fc_protocol":"PD"}]}
      """))
  let disconnected = try DeviceDecoder.decode(
    PortDetails.self,
    from: data(
      """
      {"ports":[{"port":1,"connected":false,"vout_mv":0,"iout_ma":0,"fc_protocol":"Not Charging"}]}
      """))
  var history = PowerHistory()
  let start = Date(timeIntervalSince1970: 100)
  history.append(connected, at: start)
  history.append(connected, at: start.addingTimeInterval(30))
  history.append(connected, at: start.addingTimeInterval(300))
  history.append(disconnected, at: start.addingTimeInterval(330))
  let samples = try #require(history.samples[1])
  #expect(samples.map(\.segment) == [0, 0, 1, 2])
  #expect(samples.map(\.watts) == [5, 5, 5, 0])
  for index in 1...300 {
    history.append(connected, at: start.addingTimeInterval(330 + Double(index)))
  }
  #expect(history.samples[1]?.count == 240)
  history.append(connected, at: start.addingTimeInterval(10_000))
  #expect(history.samples[1]?.count == 1)
}

@Test @MainActor func initializesReusesSessionAndRecoversExpiredSession() async throws {
  var methods: [String] = []
  var calls = 0
  var initializations = 0
  var observedSessions: [String?] = []
  let endpoint = try MCPClient.validatedURL("https://example.com/mcp")
  let client = MCPClient(endpoint: endpoint) { request, expectedID in
    let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.httpBody))
    let method = try #require(body["method"]?.string)
    methods.append(method)
    observedSessions.append(request.value(forHTTPHeaderField: "Mcp-Session-Id"))
    if method == "notifications/initialized" { return HTTPPayload(data: Data(), status: 202) }
    let result: JSONValue
    if method == "initialize" {
      initializations += 1
      result = .object(["protocolVersion": .string("2025-03-26")])
    } else {
      calls += 1
      if calls == 2 { return HTTPPayload(data: Data(), status: 404) }
      result = .object(["structuredContent": .object(["mode": .number(0)])])
    }
    let response = JSONValue.object([
      "jsonrpc": .string("2.0"), "id": .number(Double(try #require(expectedID))), "result": result,
    ])
    return HTTPPayload(
      data: try JSONEncoder().encode(response), status: 200,
      sessionID: method == "initialize" ? "session-\(initializations)" : nil)
  }
  let first = try await client.read("get_temperature_mode", as: TemperatureMode.self)
  let second = try await client.read("get_temperature_mode", as: TemperatureMode.self)
  #expect(first.mode == 0 && second.mode == 0)
  #expect(initializations == 2)
  #expect(
    methods == [
      "initialize", "notifications/initialized", "tools/call", "tools/call",
      "initialize", "notifications/initialized", "tools/call",
    ])
  #expect(observedSessions[0] == nil && observedSessions[4] == nil)
  #expect(observedSessions[2] == "session-1" && observedSessions[6] == "session-2")
}

@Test @MainActor func reinitializesWithoutStaleSessionAfterFailedHandshake() async throws {
  var initializeSessions: [String?] = []
  var notifications = 0
  let client = MCPClient(endpoint: try MCPClient.validatedURL("https://example.com/mcp")) {
    request, expectedID in
    let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.httpBody))
    switch body["method"]?.string {
    case "initialize":
      let session = request.value(forHTTPHeaderField: "Mcp-Session-Id")
      initializeSessions.append(session)
      if session != nil { return HTTPPayload(data: Data(), status: 404) }
    case "notifications/initialized":
      notifications += 1
      return HTTPPayload(data: Data(), status: notifications == 1 ? 500 : 202)
    default:
      let result: JSONValue = .object(["structuredContent": .object(["mode": .number(1)])])
      let response = JSONValue.object([
        "jsonrpc": .string("2.0"), "id": .number(Double(try #require(expectedID))),
        "result": result,
      ])
      return HTTPPayload(data: try JSONEncoder().encode(response), status: 200)
    }
    let response = JSONValue.object([
      "jsonrpc": .string("2.0"), "id": .number(Double(try #require(expectedID))),
      "result": .object(["protocolVersion": .string("2025-03-26")]),
    ])
    return HTTPPayload(data: try JSONEncoder().encode(response), status: 200, sessionID: "session")
  }
  await #expect(throws: MCPError.http(500)) {
    try await client.read("get_temperature_mode", as: TemperatureMode.self)
  }
  #expect(try await client.read("get_temperature_mode", as: TemperatureMode.self).mode == 1)
  #expect(initializeSessions == [nil, nil])
}

@Test @MainActor func refusesControlToolsBeforeNetworkAccess() async throws {
  let client = MCPClient(endpoint: try MCPClient.validatedURL("https://example.com/mcp")) { _, _ in
    Issue.record("A write tool reached the transport")
    throw MCPError.invalidResponse
  }
  await #expect(throws: MCPError.invalidResponse) { try await client.readData("turn_off_port") }
}
