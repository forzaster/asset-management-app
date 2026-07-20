import SwiftUI

struct ProfitLossText: View {
    let amount: Int

    var body: some View {
        Text(formatted)
            .foregroundStyle(amount >= 0 ? Color.blue : Color.red)
            .monospacedDigit()
    }

    private var formatted: String {
        let sign = amount >= 0 ? "+" : "-"
        let abs = abs(amount)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return "\(sign)¥\(f.string(from: NSNumber(value: abs)) ?? "0")"
    }
}
