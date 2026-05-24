import Foundation

public protocol HoldingRepository: Sendable {
    func all() async throws -> [Holding]
    func replaceAll(_ holdings: [Holding]) async throws
}
