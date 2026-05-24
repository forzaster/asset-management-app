import Testing
import Foundation
import Zip
@testable import AssetCore

private func makeSampleZip(at dir: URL) throws -> URL {
    let staging = dir.appendingPathComponent("staging_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

    let meta = """
    {
      "schema_version": 1,
      "exported_at": "2024-03-15T12:00:00+09:00",
      "tables": { "transactions": 2, "holdings": 1, "snapshots": 1 }
    }
    """
    try meta.write(to: staging.appendingPathComponent("meta.json"), atomically: true, encoding: .utf8)

    let tx = """
    account_type,ticker_code,ticker_name,trade_date,trade_type,profit_type,quantity,sale_amount,cost_amount,profit_loss,tax,category,year,month,acq_date
    特定口座,TST1,テスト銘柄A,2024-03-15,売却,売却,100,250000,200000,50000,10000,国内株,2024,3,2023-04-01
    NISA,,テスト銘柄B,2023-11-01,売却,売却,1000,50000,40000,10000,0,投資信託,2023,11,
    """
    try tx.write(to: staging.appendingPathComponent("transactions.csv"), atomically: true, encoding: .utf8)

    let holdings = """
    ticker_code,ticker_name,account_type,category,quantity,avg_cost,total_cost,yf_ticker,last_price,last_updated
    TST1,テスト銘柄A,特定口座,国内株,100,2000,200000,TST1.T,2500,2024-03-15
    """
    try holdings.write(to: staging.appendingPathComponent("holdings.csv"), atomically: true, encoding: .utf8)

    let snap = """
    snapshot_date,total_assets,realized_cumulative,realized_annual,unrealized_gains
    2024-03-15,10000000,500000,100000,200000
    """
    try snap.write(to: staging.appendingPathComponent("snapshots.csv"), atomically: true, encoding: .utf8)

    let zipURL = dir.appendingPathComponent("sample_\(UUID().uuidString).zip")
    try Zip.zipFiles(
        paths: [
            staging.appendingPathComponent("meta.json"),
            staging.appendingPathComponent("transactions.csv"),
            staging.appendingPathComponent("holdings.csv"),
            staging.appendingPathComponent("snapshots.csv"),
        ],
        zipFilePath: zipURL,
        password: nil,
        progress: nil
    )
    try FileManager.default.removeItem(at: staging)
    return zipURL
}

@Test func importServiceLoadsZipEndToEnd() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("itest_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let dbPath = tmpDir.appendingPathComponent("app.sqlite")
    let container = try AppContainer.local(dbPath: dbPath)
    let service = ImportService(container: container)

    let zipURL = try makeSampleZip(at: tmpDir)
    let result = try await service.importZip(at: zipURL)

    #expect(result.insertedTransactions == 2)
    #expect(result.replacedHoldings == 1)
    #expect(result.appendedSnapshots == 1)

    let txs = try await container.transactions.all()
    #expect(txs.count == 2)
    let holdings = try await container.holdings.all()
    #expect(holdings[0].tickerName == "テスト銘柄A")
    let snap = try await container.snapshots.latest()
    #expect(snap?.totalAssets == 10_000_000)
}

@Test func importIsIdempotentOnReImport() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("itest_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let container = try AppContainer.local(dbPath: tmpDir.appendingPathComponent("a.sqlite"))
    let service = ImportService(container: container)
    let zipURL = try makeSampleZip(at: tmpDir)

    _ = try await service.importZip(at: zipURL)
    let second = try await service.importZip(at: zipURL)

    #expect(second.insertedTransactions == 0)
    #expect(second.skippedTransactions == 2)
    let txs = try await container.transactions.all()
    #expect(txs.count == 2)
}

@Test func malformedZipThrows() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("itest_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let badZip = tmpDir.appendingPathComponent("bad.zip")
    try Data("not a zip".utf8).write(to: badZip)

    let container = try AppContainer.local(dbPath: tmpDir.appendingPathComponent("a.sqlite"))
    let service = ImportService(container: container)

    do {
        _ = try await service.importZip(at: badZip)
        Issue.record("expected throw")
    } catch ImportError.zipExtractionFailed {
        // ok
    }
}
