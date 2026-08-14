import SwiftUI
import Charts

enum YenAxisFormatter {
    static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        let man = value / 10_000.0
        if abs(man) >= 100 { return String(format: "%.0f万", man) }
        return String(format: "%.1f万", man)
    }
}

extension View {
    func yenAxisY() -> some View {
        self.chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(YenAxisFormatter.format(v))
                    }
                }
            }
        }
    }

    func yenAxisX() -> some View {
        self.chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(YenAxisFormatter.format(v))
                    }
                }
            }
        }
    }
}
