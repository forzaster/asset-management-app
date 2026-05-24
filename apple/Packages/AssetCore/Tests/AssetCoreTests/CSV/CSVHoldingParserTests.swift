import Testing
import Foundation
@testable import AssetCore

@Test func parsesHoldingsCsvWithNullablePrice() throws {
    let csv = """
    ticker_code,ticker_name,account_type,category,quantity,avg_cost,total_cost,yf_ticker,last_price,last_updated
    TST1,テスト銘柄A,特定口座,国内株,100,2000,200000,TST1.T,2500,2024-03-15
    ,テスト投信B,特定口座,投資信託,1234567,1.2345,1500,,,
    """
    let rows = try CSVHoldingParser.parse(csv: csv)
    #expect(rows.count == 2)
    #expect(rows[0].lastPrice == 2500)
    #expect(rows[1].yfTicker == nil)
    #expect(rows[1].lastPrice == nil)
}
