import Foundation
import AssetCore

@MainActor
@Observable
final class ProfitTrendViewModel {
    private let container: AppContainer

    var annual: [AnnualSummary] = []
    var cumulative: [(year: Int, gross: Int, net: Int)] = []
    var byCategory: [CategoryYearSummary] = []
    var isLoading: Bool = false

    init(container: AppContainer) { self.container = container }

    func load() async {
        isLoading = true
        do {
            annual = try await container.annualAggregates.byYear()
            byCategory = try await container.annualAggregates.byYearAndCategory()
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
}
