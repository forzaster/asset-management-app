import Foundation
import GRDB

public struct AppContainer: Sendable {
    public let transactions: any TransactionRepository
    public let holdings: any HoldingRepository
    public let snapshots: any SnapshotRepository
    public let annualAggregates: any AnnualAggregatesRepository

    public init(
        transactions: any TransactionRepository,
        holdings: any HoldingRepository,
        snapshots: any SnapshotRepository,
        annualAggregates: any AnnualAggregatesRepository
    ) {
        self.transactions = transactions
        self.holdings = holdings
        self.snapshots = snapshots
        self.annualAggregates = annualAggregates
    }

    public static func local(dbPath: URL) throws -> AppContainer {
        try FileManager.default.createDirectory(
            at: dbPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        let dbQueue = try DatabaseQueue(path: dbPath.path, configuration: config)
        try Schema.migrate(dbQueue)
        return AppContainer(
            transactions: SQLiteTransactionRepository(writer: dbQueue),
            holdings: SQLiteHoldingRepository(writer: dbQueue),
            snapshots: SQLiteSnapshotRepository(writer: dbQueue),
            annualAggregates: SQLiteAnnualAggregatesRepository(reader: dbQueue)
        )
    }
}
