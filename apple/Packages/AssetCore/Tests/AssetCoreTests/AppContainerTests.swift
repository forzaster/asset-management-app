import Testing
import Foundation
@testable import AssetCore

@Test func localContainerCreatesUsableRepositories() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("appcontainer_test_\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let container = try AppContainer.local(dbPath: tmp)
    let txs = try await container.transactions.all()
    #expect(txs.isEmpty)
    let holdings = try await container.holdings.all()
    #expect(holdings.isEmpty)
    let latest = try await container.snapshots.latest()
    #expect(latest == nil)
    let annual = try await container.annualAggregates.byYear()
    #expect(annual.isEmpty)
}
