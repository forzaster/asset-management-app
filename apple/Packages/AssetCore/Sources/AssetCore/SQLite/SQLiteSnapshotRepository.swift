import Foundation
import GRDB

public final class SQLiteSnapshotRepository: SnapshotRepository, @unchecked Sendable {
    private let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func latest() async throws -> PortfolioSnapshot? {
        try await writer.read { db in
            try SnapshotRow
                .order(Column("snapshot_date").desc)
                .limit(1)
                .fetchOne(db)?
                .toModel()
        }
    }

    public func history(limit: Int) async throws -> [PortfolioSnapshot] {
        try await writer.read { db in
            try SnapshotRow
                .order(Column("snapshot_date").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.toModel() }
        }
    }

    public func append(_ snapshot: PortfolioSnapshot) async throws {
        try await writer.write { db in
            let row = SnapshotRow(from: snapshot)
            try row.insert(db, onConflict: .ignore)
        }
    }
}
