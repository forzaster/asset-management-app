import Foundation

public protocol TransactionRepository: Sendable {
    func all() async throws -> [Transaction]
    func filtered(
        years: [Int]?,
        accounts: [String]?,
        categories: [String]?,
        profitTypes: [String]?,
        tradeTypes: [String]?,
        keyword: String?
    ) async throws -> [Transaction]
    func bulkInsert(_ transactions: [Transaction]) async throws -> (inserted: Int, skipped: Int)
}
