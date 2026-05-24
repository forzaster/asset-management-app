import Testing
import Foundation
@testable import AssetCore

@Test func transactionInitialization() {
    let tx = Transaction(
        id: nil,
        accountType: "特定口座",
        tickerCode: "TST1",
        tickerName: "テスト銘柄A",
        tradeDate: ISO8601DateFormatter().date(from: "2024-03-15T00:00:00Z")!,
        tradeType: "売却",
        profitType: "売却",
        quantity: "100",
        saleAmount: 250000,
        costAmount: 200000,
        profitLoss: 50000,
        tax: 10000,
        category: "国内株",
        year: 2024,
        month: 3,
        acqDate: "2023-04-01"
    )
    #expect(tx.profitLoss == 50000)
    #expect(tx.tickerName == "テスト銘柄A")
    #expect(tx.acqDate == "2023-04-01")
}

@Test func transactionIsCodable() throws {
    let tx = Transaction(
        id: 1, accountType: "NISA", tickerCode: "", tickerName: "テスト投信A",
        tradeDate: Date(timeIntervalSince1970: 1_700_000_000),
        tradeType: "売却", profitType: "売却", quantity: "1234567",
        saleAmount: 50000, costAmount: 40000, profitLoss: 10000, tax: 0,
        category: "投資信託", year: 2023, month: 11, acqDate: ""
    )
    let data = try JSONEncoder().encode(tx)
    let decoded = try JSONDecoder().decode(Transaction.self, from: data)
    #expect(decoded.profitLoss == 10000)
}
