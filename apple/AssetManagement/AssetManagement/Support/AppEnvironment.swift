import Foundation
import AssetCore

@MainActor
@Observable
final class AppEnvironment {
    let container: AppContainer

    init() {
        let dir = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AssetManagement", isDirectory: true)
        let dbURL = dir.appendingPathComponent("assets.sqlite")
        do {
            self.container = try AppContainer.local(dbPath: dbURL)
        } catch {
            fatalError("Failed to initialize AppContainer: \(error)")
        }
    }
}
