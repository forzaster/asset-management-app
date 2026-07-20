import Testing
import Foundation
import GRDB
@testable import AssetCore

private func makeTx(
    date: String = "2024-03-15",
    account: String = "特定口座",
    ticker: String = "TST1",
    name: String = "テスト銘柄A",
    profitType: String = "売却",
    tradeType: String = "売却",
    category: String = "国内株",
    profitLoss: Int = 50_000,
    tax: Int = 10_000,
    saleAmount: Int = 250_000,
    costAmount: Int = 200_000,
    acqDate: String = "2023-04-01"
) -> Transaction {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Asia/Tokyo")
    let parsed = df.date(from: date)!
    let comp = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: parsed)
    return Transaction(
        id: nil, accountType: account, tickerCode: ticker, tickerName: name,
        tradeDate: parsed, tradeType: tradeType, profitType: profitType, quantity: "100",
        saleAmount: saleAmount, costAmount: costAmount,
        profitLoss: profitLoss, tax: tax, category: category,
        year: comp.year!, month: comp.month!, acqDate: acqDate
    )
}

private func freshRepo() throws -> (SQLiteTransactionRepository, DatabaseQueue) {
    let q = try DatabaseQueue()
    try Schema.migrate(q)
    return (SQLiteTransactionRepository(writer: q), q)
}

@Test func allReturnsEmptyOnFreshDb() async throws {
    let (repo, _) = try freshRepo()
    let result = try await repo.all()
    #expect(result.isEmpty)
}

@Test func bulkInsertThenAllRoundtrip() async throws {
    let (repo, _) = try freshRepo()
    let tx = makeTx()
    let result = try await repo.bulkInsert([tx])
    #expect(result.inserted == 1)
    let all = try await repo.all()
    #expect(all.count == 1)
    #expect(all[0].tickerName == "テスト銘柄A")
    #expect(all[0].profitLoss == 50_000)
}

@Test func filteredByYear() async throws {
    let (repo, _) = try freshRepo()
    _ = try await repo.bulkInsert([
        makeTx(date: "2023-05-10", name: "A"),
        makeTx(date: "2024-05-10", name: "B"),
    ])
    let r = try await repo.filtered(years: [2024], accounts: nil, categories: nil,
                                    profitTypes: nil, tradeTypes: nil, keyword: nil)
    #expect(r.count == 1)
    #expect(r[0].tickerName == "B")
}

@Test func filteredByKeywordContainsCaseInsensitive() async throws {
    let (repo, _) = try freshRepo()
    _ = try await repo.bulkInsert([
        makeTx(ticker: "TST1", name: "テスト銘柄A"),
        makeTx(ticker: "TST2", name: "テスト銘柄B", acqDate: "2022-01-01"),
    ])
    let r = try await repo.filtered(years: nil, accounts: nil, categories: nil,
                                    profitTypes: nil, tradeTypes: nil, keyword: "銘柄B")
    #expect(r.count == 1)
    #expect(r[0].tickerName == "テスト銘柄B")
}

@Test func bulkInsertIsIdempotentOnDuplicateKey() async throws {
    let (repo, _) = try freshRepo()
    let tx = makeTx()
    let first = try await repo.bulkInsert([tx])
    #expect(first.inserted == 1)
    #expect(first.skipped == 0)

    let second = try await repo.bulkInsert([tx])
    #expect(second.inserted == 0)
    #expect(second.skipped == 1)

    let all = try await repo.all()
    #expect(all.count == 1)
}

@Test func bulkInsertAllowsDifferentAcqDateAsDistinctRow() async throws {
    let (repo, _) = try freshRepo()
    let lot1 = makeTx(acqDate: "2020-01-01")
    let lot2 = makeTx(acqDate: "2022-06-15")
    let result = try await repo.bulkInsert([lot1, lot2])
    #expect(result.inserted == 2)
    let all = try await repo.all()
    #expect(all.count == 2)
}
