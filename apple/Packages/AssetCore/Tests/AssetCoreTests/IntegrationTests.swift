import Testing
import Foundation
@testable import AssetCore

@Test func endToEndFlowFromContainer() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("e2e_\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let container = try AppContainer.local(dbPath: tmp)

    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Asia/Tokyo")

    let tx2023 = Transaction(
        id: nil, accountType: "特定口座", tickerCode: "X1", tickerName: "AAA",
        tradeDate: df.date(from: "2023-03-15")!,
        tradeType: "売却", profitType: "売却", quantity: "100",
        saleAmount: 200_000, costAmount: 100_000, profitLoss: 100_000, tax: 20_000,
        category: "国内株", year: 2023, month: 3, acqDate: "2022-01-01"
    )
    let tx2024 = Transaction(
        id: nil, accountType: "特定口座", tickerCode: "X2", tickerName: "BBB",
        tradeDate: df.date(from: "2024-08-10")!,
        tradeType: "売却", profitType: "売却", quantity: "50",
        saleAmount: 300_000, costAmount: 200_000, profitLoss: 100_000, tax: 20_000,
        category: "投資信託", year: 2024, month: 8, acqDate: "2020-05-10"
    )
    let r = try await container.transactions.bulkInsert([tx2023, tx2024])
    #expect(r.inserted == 2)

    let summary = try await container.annualAggregates.byYear()
    #expect(summary.map { $0.year }.sorted() == [2023, 2024])

    let holding = Holding(
        id: nil, tickerCode: "X1", tickerName: "AAA",
        accountType: "特定口座", category: "国内株",
        quantity: 100, avgCost: 1000, totalCost: 100_000,
        yfTicker: "X1.T", lastPrice: 2_500, lastUpdated: "2024-09-01"
    )
    try await container.holdings.replaceAll([holding])
    #expect(try await container.holdings.all().count == 1)

    let snap = PortfolioSnapshot(
        id: nil, snapshotDate: df.date(from: "2024-09-01")!,
        totalAssets: 5_000_000, realizedCumulative: 200_000,
        realizedAnnual: 100_000, unrealizedGains: 150_000
    )
    try await container.snapshots.append(snap)
    let latest = try await container.snapshots.latest()
    #expect(latest?.totalAssets == 5_000_000)
}
