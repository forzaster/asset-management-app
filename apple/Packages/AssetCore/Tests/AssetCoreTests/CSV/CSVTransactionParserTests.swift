import Testing
import Foundation
@testable import AssetCore

@Test func parsesValidTransactionCsv() throws {
    let csv = """
    account_type,ticker_code,ticker_name,trade_date,trade_type,profit_type,quantity,sale_amount,cost_amount,profit_loss,tax,category,year,month,acq_date
    特定口座,TST1,テスト銘柄A,2024-03-15,売却,売却,100,250000,200000,50000,10000,国内株,2024,3,2023-04-01
    NISA,,テスト銘柄B,2023-11-01,売却,売却,1234567,50000,40000,10000,0,投資信託,2023,11,
    """
    let rows = try CSVTransactionParser.parse(csv: csv)
    #expect(rows.count == 2)
    #expect(rows[0].tickerName == "テスト銘柄A")
    #expect(rows[0].profitLoss == 50000)
    #expect(rows[0].acqDate == "2023-04-01")
    #expect(rows[1].acqDate == "")
    #expect(rows[1].tickerCode == "")
}

@Test func parsesUtf8BomCsv() throws {
    let bom = "\u{FEFF}"
    let csv = bom + """
    account_type,ticker_code,ticker_name,trade_date,trade_type,profit_type,quantity,sale_amount,cost_amount,profit_loss,tax,category,year,month,acq_date
    特定口座,TST1,テスト銘柄A,2024-03-15,売却,売却,100,250000,200000,50000,10000,国内株,2024,3,
    """
    let rows = try CSVTransactionParser.parse(csv: csv)
    #expect(rows.count == 1)
    #expect(rows[0].tickerName == "テスト銘柄A")
}

@Test func missingRequiredColumnThrows() throws {
    let csv = "account_type,ticker_name\n特定口座,テスト"
    do {
        _ = try CSVTransactionParser.parse(csv: csv)
        Issue.record("expected throw")
    } catch ImportError.csvParseFailed {
        // ok
    }
}
