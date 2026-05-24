import Foundation

public protocol AnnualAggregatesRepository: Sendable {
    func byYear() async throws -> [AnnualSummary]
    func byYearAndCategory() async throws -> [CategoryYearSummary]
}
