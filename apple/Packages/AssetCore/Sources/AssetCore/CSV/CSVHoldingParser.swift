import Foundation
import CodableCSV

public enum CSVHoldingParser {
    private static let requiredColumns: [String] = [
        "ticker_code", "ticker_name", "account_type", "category",
        "quantity", "avg_cost", "total_cost", "yf_ticker",
        "last_price", "last_updated",
    ]

    public static func parse(csv: String) throws -> [Holding] {
        let stripped = csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv
        let reader: CSVReader
        do {
            reader = try CSVReader(input: stripped) { $0.headerStrategy = .firstLine }
        } catch {
            throw ImportError.csvParseFailed(file: "holdings.csv", reason: "unreadable CSV")
        }
        let header = reader.headers
        guard !header.isEmpty else {
            throw ImportError.csvParseFailed(file: "holdings.csv", reason: "missing header")
        }
        for col in requiredColumns where !header.contains(col) {
            throw ImportError.csvParseFailed(file: "holdings.csv", reason: "missing column: \(col)")
        }

        var result: [Holding] = []
        // エラー理由にはセル値を含めず行番号のみを入れる（金額・銘柄名の漏洩防止）
        var rowNumber = 1
        do {
            while let row = try reader.readRow() {
                rowNumber += 1
                let dict = Dictionary(uniqueKeysWithValues: zip(header, row).map { ($0, $1) })
                let yfRaw = dict["yf_ticker"] ?? ""
                let yf = yfRaw.isEmpty ? nil : yfRaw
                let priceStr = dict["last_price"] ?? ""
                let price: Double? = priceStr.isEmpty ? nil : Double(priceStr)
                result.append(Holding(
                    id: nil,
                    tickerCode: dict["ticker_code"] ?? "",
                    tickerName: dict["ticker_name"] ?? "",
                    accountType: dict["account_type"] ?? "",
                    category: dict["category"] ?? "",
                    quantity: Double(dict["quantity"] ?? "0") ?? 0,
                    avgCost: Double(dict["avg_cost"] ?? "0") ?? 0,
                    totalCost: Double(dict["total_cost"] ?? "0") ?? 0,
                    yfTicker: yf,
                    lastPrice: price,
                    lastUpdated: dict["last_updated"] ?? ""
                ))
            }
        } catch let err as ImportError {
            throw err
        } catch {
            throw ImportError.csvParseFailed(file: "holdings.csv", reason: "malformed row near line \(rowNumber + 1)")
        }
        return result
    }
}
