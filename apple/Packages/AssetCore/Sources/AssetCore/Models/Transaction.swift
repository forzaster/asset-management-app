import Foundation

public struct Transaction: Identifiable, Codable, Sendable, Equatable {
    public var id: Int64?
    public var accountType: String
    public var tickerCode: String
    public var tickerName: String
    public var tradeDate: Date
    public var tradeType: String
    public var profitType: String
    public var quantity: String
    public var saleAmount: Int
    public var costAmount: Int
    public var profitLoss: Int
    public var tax: Int
    public var category: String
    public var year: Int
    public var month: Int
    public var acqDate: String

    public init(
        id: Int64? = nil,
        accountType: String,
        tickerCode: String,
        tickerName: String,
        tradeDate: Date,
        tradeType: String,
        profitType: String,
        quantity: String,
        saleAmount: Int,
        costAmount: Int,
        profitLoss: Int,
        tax: Int,
        category: String,
        year: Int,
        month: Int,
        acqDate: String
    ) {
        self.id = id
        self.accountType = accountType
        self.tickerCode = tickerCode
        self.tickerName = tickerName
        self.tradeDate = tradeDate
        self.tradeType = tradeType
        self.profitType = profitType
        self.quantity = quantity
        self.saleAmount = saleAmount
        self.costAmount = costAmount
        self.profitLoss = profitLoss
        self.tax = tax
        self.category = category
        self.year = year
        self.month = month
        self.acqDate = acqDate
    }
}
