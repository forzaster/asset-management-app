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
        Self.protectDataDirectory(dir)
        let dbURL = dir.appendingPathComponent("assets.sqlite")
        do {
            self.container = try AppContainer.local(dbPath: dbURL)
        } catch {
            fatalError("Failed to initialize AppContainer: \(error)")
        }
    }

    /// 資産DB（WAL/SHM含む）の格納ディレクトリを保護する。
    /// - バックアップ（iCloud / Finder / Time Machine）から除外。データはStreamlit版のexport ZIPから再インポートできる
    /// - iOS/iPadOSではロック中に開かれていないファイルを暗号化（ディレクトリ配下の新規ファイルに継承される）
    private static func protectDataDirectory(_ dir: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        #if !os(macOS)
        try? fm.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: dir.path)
        #endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDir = dir
        try? mutableDir.setResourceValues(values)
    }
}
