import Foundation
import CodableCSV

public enum CSVTransactionParser {
    private static let requiredColumns: [String] = [
        "account_type", "ticker_code", "ticker_name", "trade_date",
        "trade_type", "profit_type", "quantity",
        "sale_amount", "cost_amount", "profit_loss", "tax",
        "category", "year", "month", "acq_date",
    ]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()

    public static func parse(csv: String) throws -> [Transaction] {
        let stripped = csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv
        let reader: CSVReader
        do {
            reader = try CSVReader(input: stripped) {
                $0.headerStrategy = .firstLine
            }
        } catch {
            throw ImportError.csvParseFailed(file: "transactions.csv", reason: String(describing: error))
        }

        let header = reader.headers
        guard !header.isEmpty else {
            throw ImportError.csvParseFailed(file: "transactions.csv", reason: "missing header")
        }
        for col in requiredColumns where !header.contains(col) {
            throw ImportError.csvParseFailed(file: "transactions.csv", reason: "missing column: \(col)")
        }

        var result: [Transaction] = []
        do {
            while let row = try reader.readRow() {
                let dict = Dictionary(uniqueKeysWithValues: zip(header, row).map { ($0, $1) })
                let tradeDateStr = dict["trade_date"] ?? ""
                guard let tradeDate = dateFormatter.date(from: tradeDateStr) else {
                    throw ImportError.csvParseFailed(file: "transactions.csv",
                                                     reason: "invalid trade_date: \(tradeDateStr)")
                }
                result.append(Transaction(
                    id: nil,
                    accountType: dict["account_type"] ?? "",
                    tickerCode: dict["ticker_code"] ?? "",
                    tickerName: dict["ticker_name"] ?? "",
                    tradeDate: tradeDate,
                    tradeType: dict["trade_type"] ?? "",
                    profitType: dict["profit_type"] ?? "",
                    quantity: dict["quantity"] ?? "",
                    saleAmount: Int(dict["sale_amount"] ?? "0") ?? 0,
                    costAmount: Int(dict["cost_amount"] ?? "0") ?? 0,
                    profitLoss: Int(dict["profit_loss"] ?? "0") ?? 0,
                    tax: Int(dict["tax"] ?? "0") ?? 0,
                    category: dict["category"] ?? "",
                    year: Int(dict["year"] ?? "0") ?? 0,
                    month: Int(dict["month"] ?? "0") ?? 0,
                    acqDate: dict["acq_date"] ?? ""
                ))
            }
        } catch let err as ImportError {
            throw err
        } catch {
            throw ImportError.csvParseFailed(file: "transactions.csv", reason: String(describing: error))
        }
        return result
    }
}
