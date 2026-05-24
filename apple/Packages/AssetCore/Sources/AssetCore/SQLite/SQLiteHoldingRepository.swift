import Foundation
import GRDB

public final class SQLiteHoldingRepository: HoldingRepository, @unchecked Sendable {
    private let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func all() async throws -> [Holding] {
        try await writer.read { db in
            try HoldingRow
                .order(Column("category"), Column("account_type"), Column("ticker_name"))
                .fetchAll(db)
                .map { $0.toModel() }
        }
    }

    public func replaceAll(_ holdings: [Holding]) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM holdings")
            for h in holdings {
                let row = HoldingRow(from: h)
                try row.insert(db)
            }
        }
    }
}
