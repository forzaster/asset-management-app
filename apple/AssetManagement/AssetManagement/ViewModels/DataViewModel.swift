import Foundation
import AssetCore

@MainActor
@Observable
final class DataViewModel {
    private let container: AppContainer

    var lastResult: ImportResult?
    var lastImportedAt: Date?
    var errorMessage: String?
    var isImporting: Bool = false

    init(container: AppContainer) {
        self.container = container
    }

    func importZip(at url: URL) async {
        isImporting = true
        errorMessage = nil
        do {
            let service = ImportService(container: container)
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            let result = try await service.importZip(at: url)
            self.lastResult = result
            self.lastImportedAt = Date()
        } catch {
            self.errorMessage = String(describing: error)
        }
        isImporting = false
    }
}
