import Foundation

public enum ImportError: Error, Equatable, Sendable {
    case zipExtractionFailed(String)
    case missingFile(String)
    case malformedMeta(String)
    case unsupportedSchemaVersion(Int)
    case csvParseFailed(file: String, reason: String)
}
