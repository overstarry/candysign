import Foundation
import Testing

@testable import CandySignApp

@Test @MainActor func expirationPublishesWithoutAnotherNetworkResponse() async throws {
  let store = DeviceStore(startMonitoring: false)
  store.scheduleExpiration(observedAt: .now.addingTimeInterval(-74.98))
  #expect(!store.isStale)
  // Parallel UI tests can hold the main actor, so wait with a deadline instead of a fixed delay.
  let deadline = ContinuousClock.now + .seconds(2)
  while !store.isStale, ContinuousClock.now < deadline {
    try await Task.sleep(for: .milliseconds(20))
  }
  #expect(store.isStale)
}

@Test @MainActor func replacingSnapshotCancelsPreviousExpiration() async throws {
  let store = DeviceStore(startMonitoring: false)
  store.scheduleExpiration(observedAt: .now.addingTimeInterval(-74.98))
  store.scheduleExpiration(observedAt: .now)
  try await Task.sleep(for: .milliseconds(150))
  #expect(!store.isStale)
}

@Test @MainActor func lateSnapshotIsAlreadyStale() {
  let store = DeviceStore(startMonitoring: false)
  store.scheduleExpiration(observedAt: .now.addingTimeInterval(-80))
  #expect(store.isStale)
}
