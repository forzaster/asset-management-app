import Foundation
import GRDB

struct TransactionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "transactions"

    var id: Int64?
    var accountType: String
    var tickerCode: String
    var tickerName: String
    var tradeDate: String         // YYYY-MM-DD
    var tradeType: String
    var profitType: String
    var quantity: String
    var saleAmount: Int
    var costAmount: Int
    var profitLoss: Int
    var tax: Int
    var category: String
    var year: Int
    var month: Int
    var acqDate: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountType = "account_type"
        case tickerCode = "ticker_code"
        case tickerName = "ticker_name"
        case tradeDate = "trade_date"
        case tradeType = "trade_type"
        case profitType = "profit_type"
        case quantity
        case saleAmount = "sale_amount"
        case costAmount = "cost_amount"
        case profitLoss = "profit_loss"
        case tax, category, year, month
        case acqDate = "acq_date"
    }
}

extension TransactionRow {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()

    init(from tx: Transaction) {
        self.id = tx.id
        self.accountType = tx.accountType
        self.tickerCode = tx.tickerCode
        self.tickerName = tx.tickerName
        self.tradeDate = TransactionRow.dateFormatter.string(from: tx.tradeDate)
        self.tradeType = tx.tradeType
        self.profitType = tx.profitType
        self.quantity = tx.quantity
        self.saleAmount = tx.saleAmount
        self.costAmount = tx.costAmount
        self.profitLoss = tx.profitLoss
        self.tax = tx.tax
        self.category = tx.category
        self.year = tx.year
        self.month = tx.month
        self.acqDate = tx.acqDate
    }

    func toModel() -> Transaction {
        Transaction(
            id: id, accountType: accountType, tickerCode: tickerCode,
            tickerName: tickerName,
            tradeDate: TransactionRow.dateFormatter.date(from: tradeDate) ?? Date(),
            tradeType: tradeType, profitType: profitType, quantity: quantity,
            saleAmount: saleAmount, costAmount: costAmount,
            profitLoss: profitLoss, tax: tax, category: category,
            year: year, month: month, acqDate: acqDate
        )
    }
}

struct HoldingRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "holdings"

    var id: Int64?
    var tickerCode: String
    var tickerName: String
    var accountType: String
    var category: String
    var quantity: Double
    var avgCost: Double
    var totalCost: Double
    var yfTicker: String?
    var lastPrice: Double?
    var lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case id
        case tickerCode = "ticker_code"
        case tickerName = "ticker_name"
        case accountType = "account_type"
        case category, quantity
        case avgCost = "avg_cost"
        case totalCost = "total_cost"
        case yfTicker = "yf_ticker"
        case lastPrice = "last_price"
        case lastUpdated = "last_updated"
    }

    init(from h: Holding) {
        self.id = h.id
        self.tickerCode = h.tickerCode
        self.tickerName = h.tickerName
        self.accountType = h.accountType
        self.category = h.category
        self.quantity = h.quantity
        self.avgCost = h.avgCost
        self.totalCost = h.totalCost
        self.yfTicker = h.yfTicker
        self.lastPrice = h.lastPrice
        self.lastUpdated = h.lastUpdated
    }

    func toModel() -> Holding {
        Holding(
            id: id, tickerCode: tickerCode, tickerName: tickerName,
            accountType: accountType, category: category,
            quantity: quantity, avgCost: avgCost, totalCost: totalCost,
            yfTicker: yfTicker, lastPrice: lastPrice, lastUpdated: lastUpdated
        )
    }
}

struct SnapshotRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "portfolio_snapshots"

    var id: Int64?
    var snapshotDate: String          // YYYY-MM-DD
    var totalAssets: Double
    var realizedCumulative: Double
    var realizedAnnual: Double
    var unrealizedGains: Double

    enum CodingKeys: String, CodingKey {
        case id
        case snapshotDate = "snapshot_date"
        case totalAssets = "total_assets"
        case realizedCumulative = "realized_cumulative"
        case realizedAnnual = "realized_annual"
        case unrealizedGains = "unrealized_gains"
    }

    init(from s: PortfolioSnapshot) {
        self.id = s.id
        self.snapshotDate = TransactionRow.dateFormatter.string(from: s.snapshotDate)
        self.totalAssets = s.totalAssets
        self.realizedCumulative = s.realizedCumulative
        self.realizedAnnual = s.realizedAnnual
        self.unrealizedGains = s.unrealizedGains
    }

    func toModel() -> PortfolioSnapshot {
        PortfolioSnapshot(
            id: id,
            snapshotDate: TransactionRow.dateFormatter.date(from: snapshotDate) ?? Date(),
            totalAssets: totalAssets,
            realizedCumulative: realizedCumulative,
            realizedAnnual: realizedAnnual,
            unrealizedGains: unrealizedGains
        )
    }
}
