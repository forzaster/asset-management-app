import Foundation
import GRDB

public final class SQLiteAnnualAggregatesRepository: AnnualAggregatesRepository, @unchecked Sendable {
    private let reader: any DatabaseReader

    public init(reader: any DatabaseReader) {
        self.reader = reader
    }

    public func byYear() async throws -> [AnnualSummary] {
        try await reader.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT year, SUM(profit_loss) AS total_profit, SUM(tax) AS total_tax
                FROM transactions
                GROUP BY year
                ORDER BY year
            """)
            return rows.map { row in
                let profit = row["total_profit"] as Int? ?? 0
                let tax = row["total_tax"] as Int? ?? 0
                return AnnualSummary(
                    year: row["year"] ?? 0,
                    totalProfit: profit,
                    totalTax: tax,
                    netProfit: profit - tax
                )
            }
        }
    }

    public func byYearAndProfitType() async throws -> [YearProfitTypeSummary] {
        try await reader.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT year, profit_type, SUM(profit_loss) AS amount
                FROM transactions
                GROUP BY year, profit_type
                ORDER BY year, profit_type
            """)
            return rows.map { row in
                YearProfitTypeSummary(
                    year: row["year"] ?? 0,
                    profitType: row["profit_type"] ?? "",
                    amount: row["amount"] as Int? ?? 0
                )
            }
        }
    }

    public func byYearAndCategory() async throws -> [CategoryYearSummary] {
        try await reader.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT year, category,
                       SUM(profit_loss) AS profit_loss,
                       SUM(tax) AS tax
                FROM transactions
                GROUP BY year, category
                ORDER BY year, category
            """)
            return rows.map { row in
                CategoryYearSummary(
                    year: row["year"] ?? 0,
                    category: row["category"] ?? "",
                    profitLoss: row["profit_loss"] as Int? ?? 0,
                    tax: row["tax"] as Int? ?? 0
                )
            }
        }
    }
}
