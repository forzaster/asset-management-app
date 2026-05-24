import Foundation

public protocol SnapshotRepository: Sendable {
    func latest() async throws -> PortfolioSnapshot?
    func history(limit: Int) async throws -> [PortfolioSnapshot]
    func append(_ snapshot: PortfolioSnapshot) async throws
}
