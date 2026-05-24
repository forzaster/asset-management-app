import Foundation

public struct Holding: Identifiable, Codable, Sendable, Equatable {
    public var id: Int64?
    public var tickerCode: String
    public var tickerName: String
    public var accountType: String
    public var category: String
    public var quantity: Double
    public var avgCost: Double
    public var totalCost: Double
    public var yfTicker: String?
    public var lastPrice: Double?
    public var lastUpdated: String

    public init(
        id: Int64? = nil,
        tickerCode: String,
        tickerName: String,
        accountType: String,
        category: String,
        quantity: Double,
        avgCost: Double,
        totalCost: Double,
        yfTicker: String?,
        lastPrice: Double?,
        lastUpdated: String
    ) {
        self.id = id
        self.tickerCode = tickerCode
        self.tickerName = tickerName
        self.accountType = accountType
        self.category = category
        self.quantity = quantity
        self.avgCost = avgCost
        self.totalCost = totalCost
        self.yfTicker = yfTicker
        self.lastPrice = lastPrice
        self.lastUpdated = lastUpdated
    }
}
