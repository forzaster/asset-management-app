import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    var trend: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(trendColor)
            if let trend {
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%.2f%%", trend))
                }
                .font(.caption2)
                .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private var trendColor: Color {
        guard let trend else { return .primary }
        return trend >= 0 ? .blue : .red
    }

    private var backgroundFill: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor).opacity(0.7)
        #else
        Color(.secondarySystemBackground)
        #endif
    }
}

#Preview {
    HStack {
        KPICard(title: "総資産", value: "¥12,345,678")
        KPICard(title: "実現損益", value: "+¥500,000", trend: 5.2)
        KPICard(title: "含み損益", value: "-¥120,000", trend: -1.3)
    }
    .padding()
}
