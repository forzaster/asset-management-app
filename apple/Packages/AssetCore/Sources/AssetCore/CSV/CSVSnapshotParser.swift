import Foundation
import CodableCSV

public enum CSVSnapshotParser {
    private static let requiredColumns: [String] = [
        "snapshot_date", "total_assets", "realized_cumulative",
        "realized_annual", "unrealized_gains",
    ]
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()

    public static func parse(csv: String) throws -> [PortfolioSnapshot] {
        let stripped = csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv
        let reader: CSVReader
        do {
            reader = try CSVReader(input: stripped) { $0.headerStrategy = .firstLine }
        } catch {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: String(describing: error))
        }
        let header = reader.headers
        guard !header.isEmpty else {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "missing header")
        }
        for col in requiredColumns where !header.contains(col) {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "missing column: \(col)")
        }
        var result: [PortfolioSnapshot] = []
        do {
            while let row = try reader.readRow() {
                let dict = Dictionary(uniqueKeysWithValues: zip(header, row).map { ($0, $1) })
                let dateStr = dict["snapshot_date"] ?? ""
                guard let date = dateFormatter.date(from: dateStr) else {
                    throw ImportError.csvParseFailed(file: "snapshots.csv",
                                                     reason: "invalid date: \(dateStr)")
                }
                result.append(PortfolioSnapshot(
                    id: nil, snapshotDate: date,
                    totalAssets: Double(dict["total_assets"] ?? "0") ?? 0,
                    realizedCumulative: Double(dict["realized_cumulative"] ?? "0") ?? 0,
                    realizedAnnual: Double(dict["realized_annual"] ?? "0") ?? 0,
                    unrealizedGains: Double(dict["unrealized_gains"] ?? "0") ?? 0
                ))
            }
        } catch let err as ImportError {
            throw err
        } catch {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: String(describing: error))
        }
        return result
    }
}
