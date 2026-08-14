import Foundation
import AssetCore

@MainActor
@Observable
final class ProfitTrendViewModel {
    private let container: AppContainer

    var annual: [AnnualSummary] = []
    var cumulative: [(year: Int, gross: Int, net: Int)] = []
    var byCategory: [CategoryYearSummary] = []
    var byProfitType: [YearProfitTypeSummary] = []
    var isLoading: Bool = false

    init(container: AppContainer) { self.container = container }

    func load() async {
        isLoading = true
        do {
            annual = try await container.annualAggregates.byYear()
            byCategory = try await container.annualAggregates.byYearAndCategory()
            byProfitType = try await container.annualAggregates.byYearAndProfitType()
            var gross = 0
            var net = 0
            cumulative = annual.sorted { $0.year < $1.year }.map { a in
                gross += a.totalProfit
                net += a.netProfit
                return (a.year, gross, net)
            }
        } catch {
            print("load error: \(error)")
        }
        isLoading = false
    }

    func profitTypeBreakdown(for year: Int) -> [(profitType: String, amount: Int)] {
        byProfitType
            .filter { $0.year == year }
            .map { ($0.profitType, $0.amount) }
    }
}
