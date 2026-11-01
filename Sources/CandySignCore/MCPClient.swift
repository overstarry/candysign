import Foundation

public enum MCPError: Error, LocalizedError, Equatable {
  case invalidEndpoint, invalidResponse, sessionExpired
  case http(Int)
  case rpc(Int)
  case toolFailure, unsupportedVersion

  public var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      L10n.text("Enter a valid HTTPS MCP address without a fragment or user information.")
    case .invalidResponse: L10n.text("The server returned an unexpected response. Try refreshing.")
    case .sessionExpired: L10n.text("The connection session expired. Try refreshing.")
    case .http(let status):
      L10n.format("The server returned HTTP %ld. Check the MCP address or try again.", status)
    case .rpc(let code): L10n.format("The MCP request failed (%ld). Try refreshing.", code)
    case .toolFailure: L10n.text("The device could not complete the request. Try refreshing.")
    case .unsupportedVersion: L10n.text("The server requires an unsupported MCP protocol version.")
    }
  }
}

public enum JSONValue: Codable, Sendable, Equatable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      self = .array(try container.decode([JSONValue].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .object(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }

  public subscript(_ key: String) -> JSONValue? {
    guard case .object(let object) = self else { return nil }
    return object[key]
  }

  public var string: String? { if case .string(let value) = self { value } else { nil } }
  public var array: [JSONValue]? { if case .array(let value) = self { value } else { nil } }
  public var number: Double? { if case .number(let value) = self { value } else { nil } }
}

public enum MCPCodec {
  public static func result(from data: Data, expectedID: Int) throws -> JSONValue {
    let message = try JSONDecoder().decode(JSONValue.self, from: data)
    guard message["jsonrpc"]?.string == "2.0", message["id"]?.number == Double(expectedID) else {
      throw MCPError.invalidResponse
    }
    if let error = message["error"] {
      throw MCPError.rpc(Int(error["code"]?.number ?? -1))
    }
    guard let result = message["result"] else { throw MCPError.invalidResponse }
    return result
  }

  public static func toolData(from result: JSONValue) throws -> Data {
    if result["isError"] == .bool(true) { throw MCPError.toolFailure }
    if let structured = result["structuredContent"] { return try JSONEncoder().encode(structured) }
    guard let content = result["content"]?.array else { throw MCPError.invalidResponse }
    for item in content where item["type"]?.string == "text" {
      if let text = item["text"]?.string, let data = text.data(using: .utf8),
        (try? JSONDecoder().decode(JSONValue.self, from: data)) != nil
      {
        return data
      }
    }
    throw MCPError.invalidResponse
  }
}

public struct SSEDecoder {
  private var line: [UInt8] = []
  private var data: [String] = []
  public init() {}

  /// Feeds one byte of the stream and returns an event's data once a blank line ends it.
  public mutating func consume(_ byte: UInt8) -> Data? {
    guard byte == UInt8(ascii: "\n") else {
      line.append(byte)
      return nil
    }
    defer { line.removeAll(keepingCapacity: true) }
    if line.last == UInt8(ascii: "\r") { line.removeLast() }
    if line.isEmpty {
      defer { data.removeAll(keepingCapacity: true) }
      return data.isEmpty ? nil : Data(data.joined(separator: "\n").utf8)
    }
    if line.starts(with: "data:".utf8) {
      let value = line.dropFirst(5)
      data.append(
        String(
          decoding: value.first == UInt8(ascii: " ") ? value.dropFirst() : value, as: UTF8.self))
    }
    return nil
  }
}

public struct HTTPPayload: Sendable {
  public let data: Data
  public let status: Int
  public let sessionID: String?
  public init(data: Data, status: Int, sessionID: String? = nil) {
    self.data = data
    self.status = status
    self.sessionID = sessionID
  }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) { completionHandler(nil) }
}

@MainActor
public final class MCPClient {
  public typealias Transport = @MainActor (URLRequest, Int?) async throws -> HTTPPayload
  private let endpoint: URL
  private let transport: Transport
  private var sessionID: String?
  private var initialized = false
  private var nextID = 0
  private var protocolVersion = "2025-03-26"

  public static func validatedURL(_ text: String) throws -> URL {
    guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
      url.scheme == "https", let host = url.host, !host.isEmpty,
      url.user == nil, url.password == nil, url.fragment == nil
    else {
      throw MCPError.invalidEndpoint
    }
    return url
  }

  public init(endpoint: URL, transport: Transport? = nil) {
    self.endpoint = endpoint
    self.transport = transport ?? Self.send
  }

  public func read<T: Decodable>(_ name: String, as type: T.Type) async throws -> T {
    let data = try await readData(name)
    return try DeviceDecoder.decode(type, from: data)
  }

  public func readData(_ name: String) async throws -> Data {
    let allowed = [
      "get_machine_facts", "get_device_info", "get_port_details", "get_charging_status",
      "get_temperature_mode", "get_port_pd_status",
    ]
    guard allowed.contains(name) else { throw MCPError.invalidResponse }
    try await initializeIfNeeded()
    do {
      return try await callTool(name)
    } catch MCPError.sessionExpired {
      initialized = false
      try await initializeIfNeeded()
      return try await callTool(name)
    }
  }

  private func callTool(_ name: String) async throws -> Data {
    let result = try await rpc(
      "tools/call",
      params: .object([
        "name": .string(name), "arguments": .object([:]),
      ]))
    return try MCPCodec.toolData(from: result)
  }

  private func initializeIfNeeded() async throws {
    guard !initialized else { return }
    // A stale session ID would make the server reject initialize itself with 404.
    sessionID = nil
    let result = try await rpc(
      "initialize",
      params: .object([
        "protocolVersion": .string("2025-03-26"), "capabilities": .object([:]),
        "clientInfo": .object(["name": .string("CandySign"), "version": .string("0.1.0")]),
      ]))
    guard let version = result["protocolVersion"]?.string,
      ["2024-11-05", "2025-03-26", "2025-06-18"].contains(version)
    else {
      throw MCPError.unsupportedVersion
    }
    protocolVersion = version
    _ = try await rpc("notifications/initialized", params: .object([:]), notification: true)
    initialized = true
  }

  private func rpc(_ method: String, params: JSONValue, notification: Bool = false) async throws
    -> JSONValue
  {
    try Task.checkCancellation()
    nextID += 1
    let id = nextID
    var body: [String: JSONValue] = [
      "jsonrpc": .string("2.0"), "method": .string(method), "params": params,
    ]
    if !notification { body["id"] = .number(Double(id)) }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(JSONValue.object(body))
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
    if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
    let response = try await transport(request, notification ? nil : id)
    if response.status == 404, sessionID != nil { throw MCPError.sessionExpired }
    guard (200..<300).contains(response.status) else { throw MCPError.http(response.status) }
    if let value = response.sessionID { sessionID = value }
    if notification { return .null }
    return try MCPCodec.result(from: response.data, expectedID: id)
  }

  private nonisolated static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 20
    configuration.timeoutIntervalForResource = 25
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }()

  @concurrent
  private nonisolated static func send(_ request: URLRequest, expectedID: Int?) async throws
    -> HTTPPayload
  {
    let (bytes, response) = try await session.bytes(for: request, delegate: NoRedirectDelegate())
    defer { bytes.task.cancel() }
    guard let http = response as? HTTPURLResponse else { throw MCPError.invalidResponse }
    let sessionID = http.value(forHTTPHeaderField: "Mcp-Session-Id")
    guard (200..<300).contains(http.statusCode), let expectedID else {
      return HTTPPayload(data: Data(), status: http.statusCode, sessionID: sessionID)
    }
    let isEventStream =
      http.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true
    var data = Data()
    var events = SSEDecoder()
    var count = 0
    for try await byte in bytes {
      count += 1
      guard count <= 2_000_000 else { throw MCPError.invalidResponse }
      guard isEventStream else {
        data.append(byte)
        continue
      }
      if let event = events.consume(byte),
        let message = try? JSONDecoder().decode(JSONValue.self, from: event),
        message["id"]?.number == Double(expectedID)
      {
        return HTTPPayload(data: event, status: http.statusCode, sessionID: sessionID)
      }
    }
    if isEventStream { throw MCPError.invalidResponse }
    return HTTPPayload(data: data, status: http.statusCode, sessionID: sessionID)
  }
}
