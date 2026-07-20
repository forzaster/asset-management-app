import Testing
import Foundation
@testable import AssetCore

@Test func holdingInitialization() {
    let h = Holding(
        id: nil,
        tickerCode: "TST1",
        tickerName: "テスト銘柄A",
        accountType: "特定口座",
        category: "国内株",
        quantity: 100.0,
        avgCost: 2000.0,
        totalCost: 200000.0,
        yfTicker: "TST1.T",
        lastPrice: 2500.0,
        lastUpdated: "2024-03-15"
    )
    #expect(h.quantity == 100.0)
    #expect(h.yfTicker == "TST1.T")
    #expect(h.lastPrice == 2500.0)
}

@Test func holdingNullablePriceAndYfTicker() {
    let h = Holding(
        id: nil, tickerCode: "", tickerName: "テスト投信B",
        accountType: "特定口座", category: "投資信託",
        quantity: 1_234_567.0, avgCost: 1.2345, totalCost: 1500.0,
        yfTicker: nil, lastPrice: nil, lastUpdated: ""
    )
    #expect(h.yfTicker == nil)
    #expect(h.lastPrice == nil)
}
