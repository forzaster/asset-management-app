import Testing
import Foundation
import GRDB
@testable import AssetCore

private func freshSnapshotRepo() throws -> SQLiteSnapshotRepository {
    let q = try DatabaseQueue()
    try Schema.migrate(q)
    return SQLiteSnapshotRepository(writer: q)
}

private func makeSnap(dateStr: String, total: Double = 10_000_000) -> PortfolioSnapshot {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return PortfolioSnapshot(
        id: nil, snapshotDate: df.date(from: dateStr)!,
        totalAssets: total, realizedCumulative: 500_000,
        realizedAnnual: 100_000, unrealizedGains: 200_000
    )
}

@Test func latestReturnsNilOnEmpty() async throws {
    let repo = try freshSnapshotRepo()
    let latest = try await repo.latest()
    #expect(latest == nil)
}

@Test func appendThenLatestReturnsMostRecent() async throws {
    let repo = try freshSnapshotRepo()
    try await repo.append(makeSnap(dateStr: "2024-01-01"))
    try await repo.append(makeSnap(dateStr: "2024-06-01", total: 12_000_000))
    let latest = try await repo.latest()
    #expect(latest?.totalAssets == 12_000_000)
}

@Test func historyReturnsAtMostLimit() async throws {
    let repo = try freshSnapshotRepo()
    for i in 1...10 {
        try await repo.append(makeSnap(dateStr: "2024-\(String(format: "%02d", i))-01"))
    }
    let h = try await repo.history(limit: 5)
    #expect(h.count == 5)
}

@Test func appendIsIdempotentOnSameDate() async throws {
    let repo = try freshSnapshotRepo()
    try await repo.append(makeSnap(dateStr: "2024-01-01"))
    try await repo.append(makeSnap(dateStr: "2024-01-01"))
    let h = try await repo.history(limit: 100)
    #expect(h.count == 1)
}
