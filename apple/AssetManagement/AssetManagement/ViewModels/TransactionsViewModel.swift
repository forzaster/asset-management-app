import Foundation
import AssetCore

@MainActor
@Observable
final class TransactionsViewModel {
    private let container: AppContainer

    var all: [Transaction] = []
    var filtered: [Transaction] = []
    var years: [Int] = []
    var accounts: [String] = []
    var categories: [String] = []
    var profitTypes: [String] = []
    var tradeTypes: [String] = []

    var selectedYears: Set<Int> = []
    var selectedAccounts: Set<String> = []
    var selectedCategories: Set<String> = []
    var selectedProfitTypes: Set<String> = []
    var selectedTradeTypes: Set<String> = []
    var keyword: String = ""

    init(container: AppContainer) {
        self.container = container
    }

    func load() async {
        do {
            all = try await container.transactions.all()
            years = Array(Set(all.map { $0.year })).sorted(by: >)
            accounts = Array(Set(all.map { $0.accountType })).sorted()
            categories = Array(Set(all.map { $0.category })).sorted()
            profitTypes = Array(Set(all.map { $0.profitType })).sorted()
            tradeTypes = Array(Set(all.map { $0.tradeType })).sorted()
            if selectedYears.isEmpty { selectedYears = Set(years) }
            if selectedAccounts.isEmpty { selectedAccounts = Set(accounts) }
            if selectedCategories.isEmpty { selectedCategories = Set(categories) }
            if selectedProfitTypes.isEmpty { selectedProfitTypes = Set(profitTypes) }
            if selectedTradeTypes.isEmpty { selectedTradeTypes = Set(tradeTypes) }
            applyFilter()
        } catch {
            print("load error: \(error)")
        }
    }

    func applyFilter() {
        filtered = all.filter { t in
            selectedYears.contains(t.year)
            && selectedAccounts.contains(t.accountType)
            && selectedCategories.contains(t.category)
            && selectedProfitTypes.contains(t.profitType)
            && selectedTradeTypes.contains(t.tradeType)
            && (keyword.isEmpty || t.tickerName.lowercased().contains(keyword.lowercased()))
        }
    }

    var totalProfit: Int { filtered.reduce(0) { $0 + $1.profitLoss } }
    var totalTax: Int { filtered.reduce(0) { $0 + $1.tax } }
    var byCategory: [(category: String, profit: Int)] {
        Dictionary(grouping: filtered, by: { $0.category })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.profitLoss }) }
            .sorted { $0.1 > $1.1 }
    }
    var byTicker: [(name: String, profit: Int)] {
        Dictionary(grouping: filtered, by: { $0.tickerName })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.profitLoss }) }
            .sorted { $0.1 > $1.1 }
    }
}
