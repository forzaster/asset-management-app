import Foundation

public struct AnnualSummary: Sendable, Equatable {
    public var year: Int
    public var totalProfit: Int       // 売却 + 配当 + 還付
    public var totalTax: Int
    public var netProfit: Int         // 税引後

    public init(year: Int, totalProfit: Int, totalTax: Int, netProfit: Int) {
        self.year = year
        self.totalProfit = totalProfit
        self.totalTax = totalTax
        self.netProfit = netProfit
    }
}

public struct CategoryYearSummary: Sendable, Equatable {
    public var year: Int
    public var category: String
    public var profitLoss: Int
    public var tax: Int

    public init(year: Int, category: String, profitLoss: Int, tax: Int) {
        self.year = year
        self.category = category
        self.profitLoss = profitLoss
        self.tax = tax
    }
}
