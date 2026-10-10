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
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "unreadable CSV")
        }
        let header = reader.headers
        guard !header.isEmpty else {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "missing header")
        }
        for col in requiredColumns where !header.contains(col) {
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "missing column: \(col)")
        }
        var result: [PortfolioSnapshot] = []
        // エラー理由にはセル値を含めず行番号のみを入れる（金額・銘柄名の漏洩防止）
        var rowNumber = 1
        do {
            while let row = try reader.readRow() {
                rowNumber += 1
                let dict = Dictionary(uniqueKeysWithValues: zip(header, row).map { ($0, $1) })
                let dateStr = dict["snapshot_date"] ?? ""
                guard let date = dateFormatter.date(from: dateStr) else {
                    throw ImportError.csvParseFailed(file: "snapshots.csv",
                                                     reason: "invalid snapshot_date at line \(rowNumber)")
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
            throw ImportError.csvParseFailed(file: "snapshots.csv", reason: "malformed row near line \(rowNumber + 1)")
        }
        return result
    }
}
