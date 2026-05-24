import Testing
import Foundation
@testable import AssetCore

@Test func validMetaParses() throws {
    let json = """
    {
      "schema_version": 1,
      "exported_at": "2024-03-15T12:00:00+09:00",
      "tables": { "transactions": 100, "holdings": 5, "snapshots": 3 }
    }
    """.data(using: .utf8)!
    let meta = try ImportMeta.decode(from: json)
    #expect(meta.schemaVersion == 1)
    #expect(meta.tables.transactions == 100)
}

@Test func unsupportedSchemaVersionThrows() throws {
    let json = """
    { "schema_version": 999, "exported_at": "2024-03-15T12:00:00+09:00",
      "tables": { "transactions": 0, "holdings": 0, "snapshots": 0 } }
    """.data(using: .utf8)!
    do {
        _ = try ImportMeta.decode(from: json)
        Issue.record("expected throw")
    } catch ImportError.unsupportedSchemaVersion(let v) {
        #expect(v == 999)
    }
}

@Test func malformedJsonThrows() throws {
    let bad = "not json".data(using: .utf8)!
    do {
        _ = try ImportMeta.decode(from: bad)
        Issue.record("expected throw")
    } catch {
        // ok
    }
}
