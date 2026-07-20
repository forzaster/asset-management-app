import Foundation

public struct PortfolioSnapshot: Identifiable, Codable, Sendable, Equatable {
    public var id: Int64?
    public var snapshotDate: Date
    public var totalAssets: Double
    public var realizedCumulative: Double
    public var realizedAnnual: Double
    public var unrealizedGains: Double

    public init(
        id: Int64? = nil,
        snapshotDate: Date,
        totalAssets: Double,
        realizedCumulative: Double,
        realizedAnnual: Double,
        unrealizedGains: Double
    ) {
        self.id = id
        self.snapshotDate = snapshotDate
        self.totalAssets = totalAssets
        self.realizedCumulative = realizedCumulative
        self.realizedAnnual = realizedAnnual
        self.unrealizedGains = unrealizedGains
    }
}
