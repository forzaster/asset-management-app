import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home, profitTrend, transactions, data

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "ホーム"
        case .profitTrend: return "利益推移"
        case .transactions: return "取引履歴"
        case .data: return "データ管理"
        }
    }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .profitTrend: return "chart.line.uptrend.xyaxis"
        case .transactions: return "list.bullet.rectangle"
        case .data: return "arrow.down.doc"
        }
    }
}
