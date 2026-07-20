import SwiftUI
import UniformTypeIdentifiers
import AssetCore

struct DataView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm: DataViewModel?
    @State private var showImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("CSVインポート").font(.headline)
                Text("Streamlit版で出力したZIPファイル（meta.json + 各CSV）を選択します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showImporter = true
                } label: {
                    Label("ZIPファイルを選択", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm?.isImporting ?? false)

                if let r = vm?.lastResult {
                    resultSummary(r, at: vm?.lastImportedAt)
                }
                if let err = vm?.errorMessage {
                    Text("エラー: \(err)").foregroundStyle(.red).font(.caption)
                }
            }
            .padding()
        }
        .task { if vm == nil { vm = DataViewModel(container: env.container) } }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await vm?.importZip(at: url) }
            case .failure(let error):
                vm?.errorMessage = error.localizedDescription
            }
        }
    }

    private func resultSummary(_ r: ImportResult, at date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("インポート完了").font(.subheadline.weight(.semibold))
            Text("取引: 追加 \(r.insertedTransactions) / スキップ \(r.skippedTransactions)")
            Text("保有銘柄: \(r.replacedHoldings) 件で置き換え")
            Text("スナップショット: 追加 \(r.appendedSnapshots) 件")
            if let date {
                Text(date, format: .dateTime).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
