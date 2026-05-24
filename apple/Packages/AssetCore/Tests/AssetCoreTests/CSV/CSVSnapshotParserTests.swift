import Testing
import Foundation
@testable import AssetCore

@Test func parsesSnapshotsCsv() throws {
    let csv = """
    snapshot_date,total_assets,realized_cumulative,realized_annual,unrealized_gains
    2024-01-01,10000000,500000,100000,200000
    2024-06-01,12000000,600000,150000,250000
    """
    let rows = try CSVSnapshotParser.parse(csv: csv)
    #expect(rows.count == 2)
    #expect(rows[0].totalAssets == 10_000_000)
    #expect(rows[1].realizedAnnual == 150_000)
}
