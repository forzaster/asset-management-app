import Foundation
import AssetCore

@MainActor
@Observable
final class HomeViewModel {
    private let container: AppContainer

    var latestSnapshot: PortfolioSnapshot?
    var holdings: [Holding] = []
    var isLoading: Bool = false
    var errorMessage: String?

    init(container: AppContainer) {
        self.container = container
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let snapshotTask = container.snapshots.latest()
            async let holdingsTask = container.holdings.all()
            self.latestSnapshot = try await snapshotTask
            self.holdings = try await holdingsTask
        } catch {
            self.errorMessage = String(describing: error)
        }
        isLoading = false
    }
}
