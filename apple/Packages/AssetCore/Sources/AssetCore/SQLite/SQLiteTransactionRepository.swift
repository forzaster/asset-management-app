import Foundation
import GRDB

public final class SQLiteTransactionRepository: TransactionRepository, @unchecked Sendable {
    private let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func all() async throws -> [Transaction] {
        try await writer.read { db in
            try TransactionRow
                .order(Column("trade_date").desc, Column("id").desc)
                .fetchAll(db)
                .map { $0.toModel() }
        }
    }

    public func filtered(
        years: [Int]?,
        accounts: [String]?,
        categories: [String]?,
        profitTypes: [String]?,
        tradeTypes: [String]?,
        keyword: String?
    ) async throws -> [Transaction] {
        try await writer.read { db in
            var request: QueryInterfaceRequest<TransactionRow> = TransactionRow.all()
            if let years, !years.isEmpty {
                request = request.filter(years.contains(Column("year")))
            }
            if let accounts, !accounts.isEmpty {
                request = request.filter(accounts.contains(Column("account_type")))
            }
            if let categories, !categories.isEmpty {
                request = request.filter(categories.contains(Column("category")))
            }
            if let profitTypes, !profitTypes.isEmpty {
                request = request.filter(profitTypes.contains(Column("profit_type")))
            }
            if let tradeTypes, !tradeTypes.isEmpty {
                request = request.filter(tradeTypes.contains(Column("trade_type")))
            }
            if let keyword, !keyword.isEmpty {
                let pattern = "%\(keyword)%"
                request = request.filter(Column("ticker_name").like(pattern))
            }
            return try request
                .order(Column("trade_date").desc, Column("id").desc)
                .fetchAll(db)
                .map { $0.toModel() }
        }
    }

    public func bulkInsert(_ transactions: [Transaction]) async throws -> (inserted: Int, skipped: Int) {
        try await writer.write { db in
            var inserted = 0
            var skipped = 0
            for tx in transactions {
                let row = TransactionRow(from: tx)
                do {
                    try row.insert(db, onConflict: .ignore)
                    if db.changesCount > 0 {
                        inserted += 1
                    } else {
                        skipped += 1
                    }
                } catch {
                    skipped += 1
                }
            }
            return (inserted, skipped)
        }
    }
}
