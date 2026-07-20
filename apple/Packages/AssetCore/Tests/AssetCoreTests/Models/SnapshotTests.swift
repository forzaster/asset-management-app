import Testing
import Foundation
@testable import AssetCore

@Test func portfolioSnapshotInitialization() {
    let s = PortfolioSnapshot(
        id: nil,
        snapshotDate: Date(timeIntervalSince1970: 1_700_000_000),
        totalAssets: 10_000_000.0,
        realizedCumulative: 500_000.0,
        realizedAnnual: 100_000.0,
        unrealizedGains: 200_000.0
    )
    #expect(s.totalAssets == 10_000_000.0)
    #expect(s.realizedAnnual == 100_000.0)
}

@Test func annualSummaryNetProfitMatchesProfitMinusTax() {
    let a = AnnualSummary(year: 2024, totalProfit: 300_000, totalTax: 60_000, netProfit: 240_000)
    #expect(a.netProfit == a.totalProfit - a.totalTax)
}

@Test func categoryYearSummaryHoldsFields() {
    let c = CategoryYearSummary(year: 2024, category: "国内株", profitLoss: 100_000, tax: 20_000)
    #expect(c.category == "国内株")
}
