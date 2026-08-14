import Foundation

struct GroupKey: Hashable {
    let accountType: String
    let category: String

    var displayLabel: String { "\(accountType) / \(category)" }
}

enum AccountGroupOrder {
    static let accounts: [String] = ["NISA", "特定口座", "一般口座"]
    static let categories: [String] = ["投資信託", "個別株", "外国株ETF"]

    static func sortedKeys(_ pairs: Set<GroupKey>) -> [GroupKey] {
        let accountIndex: (String) -> Int = { name in
            accounts.firstIndex(of: name) ?? Int.max
        }
        let categoryIndex: (String) -> Int = { name in
            categories.firstIndex(of: name) ?? Int.max
        }
        return pairs.sorted { lhs, rhs in
            let la = accountIndex(lhs.accountType)
            let ra = accountIndex(rhs.accountType)
            if la != ra { return la < ra }
            if lhs.accountType != rhs.accountType { return lhs.accountType < rhs.accountType }
            let lc = categoryIndex(lhs.category)
            let rc = categoryIndex(rhs.category)
            if lc != rc { return lc < rc }
            return lhs.category < rhs.category
        }
    }
}
