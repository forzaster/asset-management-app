import SwiftUI
import Charts
import AssetCore

struct TransactionsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm: TransactionsViewModel?

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView() }
        }
        .task {
            if vm == nil { vm = TransactionsViewModel(container: env.container) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: TransactionsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary(vm)
                filterSection(vm)
                listSection(vm)
                chartSection(vm)
            }
            .padding()
        }
    }

    private func summary(_ vm: TransactionsViewModel) -> some View {
        HStack {
            KPICard(title: "件数", value: "\(vm.filtered.count)")
            KPICard(title: "損益合計", value: "¥\(formatInt(vm.totalProfit))")
            KPICard(title: "税金合計", value: "¥\(formatInt(vm.totalTax))")
        }
    }

    private func filterSection(_ vm: TransactionsViewModel) -> some View {
        @Bindable var bindable = vm
        return DisclosureGroup("フィルター") {
            VStack(alignment: .leading, spacing: 8) {
                multiSelectChips("年", options: vm.years.map { String($0) },
                    selected: Binding(
                        get: { Set(bindable.selectedYears.map { String($0) }) },
                        set: { newVal in
                            bindable.selectedYears = Set(newVal.compactMap(Int.init))
                            bindable.applyFilter()
                        }
                    )
                )
                multiSelectChips("口座", options: vm.accounts,
                    selected: Binding(get: { bindable.selectedAccounts },
                                      set: { bindable.selectedAccounts = $0; bindable.applyFilter() }))
                multiSelectChips("分類", options: vm.categories,
                    selected: Binding(get: { bindable.selectedCategories },
                                      set: { bindable.selectedCategories = $0; bindable.applyFilter() }))
                TextField("銘柄名検索", text: $bindable.keyword)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: bindable.keyword) { _, _ in bindable.applyFilter() }
            }
        }
    }

    private func multiSelectChips(_ title: String, options: [String], selected: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(options, id: \.self) { opt in
                        Toggle(opt, isOn: Binding(
                            get: { selected.wrappedValue.contains(opt) },
                            set: { isOn in
                                if isOn { selected.wrappedValue.insert(opt) }
                                else { selected.wrappedValue.remove(opt) }
                            }
                        ))
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func listSection(_ vm: TransactionsViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("取引一覧").font(.headline)
            ForEach(vm.filtered) { t in
                HStack {
                    VStack(alignment: .leading) {
                        Text(t.tickerName).font(.body)
                        Text("\(format(t.tradeDate)) · \(t.profitType) · \(t.category)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProfitLossText(amount: t.profitLoss)
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
    }

    private func chartSection(_ vm: TransactionsViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("カテゴリ別").font(.headline)
            Chart(vm.byCategory, id: \.category) { item in
                BarMark(
                    x: .value("損益", item.profit),
                    y: .value("分類", item.category)
                )
                .foregroundStyle(item.profit >= 0 ? .blue : .red)
            }
            .frame(height: CGFloat(max(150, vm.byCategory.count * 30)))

            Text("銘柄別").font(.headline).padding(.top)
            Chart(vm.byTicker, id: \.name) { item in
                BarMark(
                    x: .value("損益", item.profit),
                    y: .value("銘柄", item.name)
                )
                .foregroundStyle(item.profit >= 0 ? .blue : .red)
            }
            .frame(height: CGFloat(max(200, vm.byTicker.count * 22)))
        }
    }

    private func format(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: d)
    }
    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
