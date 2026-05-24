import Testing
import Foundation
import GRDB
@testable import AssetCore

private func freshHoldingRepo() throws -> SQLiteHoldingRepository {
    let q = try DatabaseQueue()
    try Schema.migrate(q)
    return SQLiteHoldingRepository(writer: q)
}

private func makeHolding(
    code: String = "TST1",
    name: String = "テスト銘柄A",
    account: String = "特定口座",
    qty: Double = 100.0,
    avgCost: Double = 2000.0,
    yf: String? = "TST1.T",
    price: Double? = 2500.0
) -> Holding {
    Holding(
        id: nil, tickerCode: code, tickerName: name, accountType: account,
        category: "国内株", quantity: qty, avgCost: avgCost,
        totalCost: qty * avgCost, yfTicker: yf, lastPrice: price,
        lastUpdated: "2024-03-15"
    )
}

@Test func emptyAllInitially() async throws {
    let repo = try freshHoldingRepo()
    let r = try await repo.all()
    #expect(r.isEmpty)
}

@Test func replaceAllDeletesPreviousRowsThenInserts() async throws {
    let repo = try freshHoldingRepo()
    try await repo.replaceAll([makeHolding(name: "A"), makeHolding(name: "B")])
    #expect(try await repo.all().count == 2)

    try await repo.replaceAll([makeHolding(name: "C")])
    let after = try await repo.all()
    #expect(after.count == 1)
    #expect(after[0].tickerName == "C")
}

@Test func replaceAllHandlesNullableYfTickerAndPrice() async throws {
    let repo = try freshHoldingRepo()
    try await repo.replaceAll([
        makeHolding(name: "テスト投信B", yf: nil, price: nil)
    ])
    let r = try await repo.all()
    #expect(r[0].yfTicker == nil)
    #expect(r[0].lastPrice == nil)
}
