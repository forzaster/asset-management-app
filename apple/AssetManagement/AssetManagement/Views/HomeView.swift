import SwiftUI
import AssetCore

struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm: HomeViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                vm = HomeViewModel(container: env.container)
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snap = vm.latestSnapshot {
                    kpiRow(snap)
                }
                if vm.holdings.isEmpty {
                    EmptyStateView(
                        title: "保有銘柄がありません",
                        message: "「データ管理」からCSVをインポートしてください。",
                        systemImage: "tray.fill"
                    )
                } else {
                    holdingList(vm.holdings)
                }
            }
            .padding()
        }
    }

    private func kpiRow(_ snap: PortfolioSnapshot) -> some View {
        VStack(spacing: 12) {
            KPICard(title: "総資産", value: yen(snap.totalAssets))
            KPICard(title: "実現損益累計", value: yen(snap.realizedCumulative))
            KPICard(title: "含み損益", value: yen(snap.unrealizedGains))
        }
    }

    private func holdingList(_ items: [Holding]) -> some View {
        let grouped = Dictionary(grouping: items) {
            GroupKey(accountType: $0.accountType, category: $0.category)
        }
        let keys = AccountGroupOrder.sortedKeys(Set(grouped.keys))
        return VStack(alignment: .leading, spacing: 16) {
            Text("保有銘柄 (\(items.count))").font(.headline)
            ForEach(keys, id: \.self) { key in
                let rows = grouped[key] ?? []
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(key.displayLabel) (\(rows.count))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(rows) { h in
                        holdingRow(h)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func holdingRow(_ h: Holding) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(h.tickerName).font(.body)
                Text("\(h.category) / \(h.accountType)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let p = h.lastPrice {
                    Text(yen(p)).font(.caption)
                }
                ProfitLossText(amount: unrealized(h))
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func unrealized(_ h: Holding) -> Int {
        guard let p = h.lastPrice else { return 0 }
        return Int(p * h.quantity - h.totalCost)
    }

    private func yen(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "JPY"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "¥\(Int(v))"
    }
}
