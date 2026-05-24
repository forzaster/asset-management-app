import SwiftUI
import Charts
import AssetCore

struct ProfitTrendView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm: ProfitTrendViewModel?

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView() }
        }
        .task {
            if vm == nil { vm = ProfitTrendViewModel(container: env.container) }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: ProfitTrendViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                annualChart(vm)
                cumulativeChart(vm)
                annualTable(vm)
            }
            .padding()
        }
    }

    private func annualChart(_ vm: ProfitTrendViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("年次損益").font(.headline)
            Chart(vm.annual, id: \.year) { item in
                BarMark(
                    x: .value("年", String(item.year)),
                    y: .value("損益(税引前)", item.totalProfit)
                )
                .foregroundStyle(item.totalProfit >= 0 ? .blue : .red)
                BarMark(
                    x: .value("年", String(item.year)),
                    y: .value("税金", -item.totalTax)
                )
                .foregroundStyle(.pink.opacity(0.5))
            }
            .frame(height: 250)
        }
    }

    private func cumulativeChart(_ vm: ProfitTrendViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("累積損益").font(.headline)
            Chart(vm.cumulative, id: \.year) { item in
                LineMark(
                    x: .value("年", String(item.year)),
                    y: .value("累積(税引前)", item.gross)
                )
                .foregroundStyle(.blue)
                LineMark(
                    x: .value("年", String(item.year)),
                    y: .value("累積(税引後)", item.net)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            .frame(height: 250)
        }
    }

    private func annualTable(_ vm: ProfitTrendViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("年次サマリー").font(.headline)
            ForEach(vm.annual, id: \.year) { item in
                HStack {
                    Text(String(item.year)).frame(width: 60, alignment: .leading)
                    Spacer()
                    ProfitLossText(amount: item.totalProfit)
                    Text("税金: ¥\(format(item.totalTax))").foregroundStyle(.secondary).font(.caption)
                    ProfitLossText(amount: item.netProfit)
                }
                .font(.callout)
                Divider()
            }
        }
    }

    private func format(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
