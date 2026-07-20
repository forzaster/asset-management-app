import Foundation
import Zip

public struct ImportResult: Sendable, Equatable {
    public let insertedTransactions: Int
    public let skippedTransactions: Int
    public let replacedHoldings: Int
    public let appendedSnapshots: Int

    public init(
        insertedTransactions: Int,
        skippedTransactions: Int,
        replacedHoldings: Int,
        appendedSnapshots: Int
    ) {
        self.insertedTransactions = insertedTransactions
        self.skippedTransactions = skippedTransactions
        self.replacedHoldings = replacedHoldings
        self.appendedSnapshots = appendedSnapshots
    }
}

public actor ImportService {
    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func importZip(at url: URL) async throws -> ImportResult {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("assetimport_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        do {
            try Zip.unzipFile(url, destination: tmp, overwrite: true, password: nil)
        } catch {
            throw ImportError.zipExtractionFailed(String(describing: error))
        }

        let metaURL = tmp.appendingPathComponent("meta.json")
        guard let metaData = try? Data(contentsOf: metaURL) else {
            throw ImportError.missingFile("meta.json")
        }
        _ = try ImportMeta.decode(from: metaData)

        // transactions
        let txURL = tmp.appendingPathComponent("transactions.csv")
        guard let txData = try? Data(contentsOf: txURL),
              let txStr = String(data: txData, encoding: .utf8) else {
            throw ImportError.missingFile("transactions.csv")
        }
        let txs = try CSVTransactionParser.parse(csv: txStr)
        let txResult = try await container.transactions.bulkInsert(txs)

        // holdings
        let holdingURL = tmp.appendingPathComponent("holdings.csv")
        guard let holdingData = try? Data(contentsOf: holdingURL),
              let holdingStr = String(data: holdingData, encoding: .utf8) else {
            throw ImportError.missingFile("holdings.csv")
        }
        let holdings = try CSVHoldingParser.parse(csv: holdingStr)
        try await container.holdings.replaceAll(holdings)

        // snapshots
        let snapshotURL = tmp.appendingPathComponent("snapshots.csv")
        guard let snapData = try? Data(contentsOf: snapshotURL),
              let snapStr = String(data: snapData, encoding: .utf8) else {
            throw ImportError.missingFile("snapshots.csv")
        }
        let snapshots = try CSVSnapshotParser.parse(csv: snapStr)
        var appended = 0
        for s in snapshots {
            try await container.snapshots.append(s)
            appended += 1
        }

        return ImportResult(
            insertedTransactions: txResult.inserted,
            skippedTransactions: txResult.skipped,
            replacedHoldings: holdings.count,
            appendedSnapshots: appended
        )
    }
}
