import Foundation

public struct ImportMeta: Codable, Sendable {
    public struct TableCounts: Codable, Sendable {
        public let transactions: Int
        public let holdings: Int
        public let snapshots: Int
    }

    public let schemaVersion: Int
    public let exportedAt: String
    public let tables: TableCounts

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case tables
    }

    public static let supportedSchemaVersions: Set<Int> = [1]

    public static func decode(from data: Data) throws -> ImportMeta {
        let meta: ImportMeta
        do {
            meta = try JSONDecoder().decode(ImportMeta.self, from: data)
        } catch {
            throw ImportError.malformedMeta(String(describing: error))
        }
        guard supportedSchemaVersions.contains(meta.schemaVersion) else {
            throw ImportError.unsupportedSchemaVersion(meta.schemaVersion)
        }
        return meta
    }
}
