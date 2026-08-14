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
                    y: .value("金額", item.totalProfit)
                )
                .foregroundStyle(by: .value("種類", "損益"))
                BarMark(
                    x: .value("年", String(item.year)),
                    y: .value("金額", -item.totalTax)
                )
                .foregroundStyle(by: .value("種類", "税金"))
            }
            .chartForegroundStyleScale(["損益": .blue, "税金": .pink.opacity(0.7)])
            .chartLegend(position: .bottom, alignment: .center)
            .yenAxisY()
            .frame(height: 250)
        }
    }

    private func cumulativeChart(_ vm: ProfitTrendViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("累積損益").font(.headline)
            Chart(vm.cumulative, id: \.year) { item in
                LineMark(
                    x: .value("年", String(item.year)),
                    y: .value("累積", item.gross)
                )
                .foregroundStyle(by: .value("種類", "税引前"))
                LineMark(
                    x: .value("年", String(item.year)),
                    y: .value("累積", item.net)
                )
                .foregroundStyle(by: .value("種類", "税引後"))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            .chartForegroundStyleScale(["税引前": .blue, "税引後": .red])
            .chartLegend(position: .bottom, alignment: .center)
            .yenAxisY()
            .frame(height: 250)
        }
    }

    private func annualTable(_ vm: ProfitTrendViewModel) -> some View {
        VStack(alignment: .leading) {
            Text("年次サマリー").font(.headline)
            ForEach(vm.annual, id: \.year) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(item.year)).frame(width: 60, alignment: .leading)
                        Spacer()
                        ProfitLossText(amount: item.totalProfit)
                        Text("税金: ¥\(format(item.totalTax))").foregroundStyle(.secondary).font(.caption)
                        ProfitLossText(amount: item.netProfit)
                    }
                    .font(.callout)

                    let breakdown = vm.profitTypeBreakdown(for: item.year)
                    if !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(breakdown, id: \.profitType) { b in
                                Text("\(b.profitType): ¥\(format(b.amount))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 60)
                    }
                }
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
