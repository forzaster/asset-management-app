import SwiftUI
import AssetCore

@main
struct AssetManagementApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
