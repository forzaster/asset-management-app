import Testing
import Foundation
import GRDB
@testable import AssetCore

@Test func schemaCreatesAllTables() throws {
    let dbQueue = try DatabaseQueue()
    try Schema.migrate(dbQueue)

    try dbQueue.read { db in
        let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        #expect(tables.contains("transactions"))
        #expect(tables.contains("holdings"))
        #expect(tables.contains("portfolio_snapshots"))
    }
}

@Test func schemaCreatesUniqueIndexOnTransactions() throws {
    let dbQueue = try DatabaseQueue()
    try Schema.migrate(dbQueue)

    try dbQueue.read { db in
        let indexes = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='transactions'")
        #expect(indexes.contains("uq_transaction"))
    }
}

@Test func schemaIsIdempotent() throws {
    let dbQueue = try DatabaseQueue()
    try Schema.migrate(dbQueue)
    try Schema.migrate(dbQueue)  // re-run should not throw
}
