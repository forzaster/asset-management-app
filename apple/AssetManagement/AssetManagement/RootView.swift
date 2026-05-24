import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tabSelection: AppSection = .home
    @State private var sidebarSelection: AppSection? = .home

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            tabView
        } else {
            splitView
        }
        #else
        splitView
        #endif
    }

    private var tabView: some View {
        TabView(selection: $tabSelection) {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    sectionView(section)
                        .navigationTitle(section.title)
                }
                .tabItem {
                    Label(section.title, systemImage: section.systemImage)
                }
                .tag(section)
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $sidebarSelection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("AssetManagement")
        } detail: {
            NavigationStack {
                let s = sidebarSelection ?? .home
                sectionView(s)
                    .navigationTitle(s.title)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ s: AppSection) -> some View {
        switch s {
        case .home: HomeView()
        case .profitTrend: ProfitTrendView()
        case .transactions: TransactionsView()
        case .data: DataView()
        }
    }
}
