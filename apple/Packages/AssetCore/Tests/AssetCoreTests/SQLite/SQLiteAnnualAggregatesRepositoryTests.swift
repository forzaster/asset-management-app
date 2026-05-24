import Testing
import Foundation
import GRDB
@testable import AssetCore

private func freshAggRepo() throws -> (SQLiteTransactionRepository, SQLiteAnnualAggregatesRepository) {
    let q = try DatabaseQueue()
    try Schema.migrate(q)
    return (SQLiteTransactionRepository(writer: q),
            SQLiteAnnualAggregatesRepository(reader: q))
}

private func tx(_ year: Int, profitLoss: Int, tax: Int, category: String = "国内株") -> Transaction {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "Asia/Tokyo")
    return Transaction(
        id: nil, accountType: "特定口座", tickerCode: "X\(year)\(profitLoss)",
        tickerName: "T\(year)\(profitLoss)",
        tradeDate: df.date(from: "\(year)-06-15")!,
        tradeType: "売却", profitType: "売却", quantity: "100",
        saleAmount: profitLoss + 100_000, costAmount: 100_000,
        profitLoss: profitLoss, tax: tax, category: category,
        year: year, month: 6, acqDate: ""
    )
}

@Test func byYearAggregatesSumOfProfitAndTax() async throws {
    let (txRepo, aggRepo) = try freshAggRepo()
    _ = try await txRepo.bulkInsert([
        tx(2023, profitLoss: 100_000, tax: 20_000),
        tx(2023, profitLoss: 50_000, tax: 10_000),
        tx(2024, profitLoss: 200_000, tax: 40_000),
    ])
    let result = try await aggRepo.byYear()
    #expect(result.count == 2)
    let y2023 = result.first(where: { $0.year == 2023 })!
    #expect(y2023.totalProfit == 150_000)
    #expect(y2023.totalTax == 30_000)
    #expect(y2023.netProfit == 120_000)
}

@Test func byYearAndCategoryGroups() async throws {
    let (txRepo, aggRepo) = try freshAggRepo()
    _ = try await txRepo.bulkInsert([
        tx(2024, profitLoss: 100_000, tax: 20_000, category: "国内株"),
        tx(2024, profitLoss: 50_000, tax: 0, category: "投資信託"),
    ])
    let result = try await aggRepo.byYearAndCategory()
    #expect(result.count == 2)
    let kabu = result.first(where: { $0.category == "国内株" })!
    #expect(kabu.profitLoss == 100_000)
    #expect(kabu.tax == 20_000)
}
