#if canImport(UIKit)
import SwiftUI

// 크래쉬 리포트 뷰
public struct WaterCrashReportsView: View {
    @State private var reports: [URL] = []
    @State private var errorMessage: String?
    @State private var confirmsDeletion = false
    @Environment(\.dismiss) private var dismiss
    
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("수집기 상태") {
                    Text(WaterCrashReporter.shared.isEnabled ? "크래시 수집 활성화" : "크래시 수집 비활성화")
                    Text("디버거 연결 중에는 비활성화됩니다. 저장된 보고서는 다음 실행에서 표시되며 최근 10개까지 보관됩니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if reports.isEmpty {
                    ContentUnavailableView("저장된 보고서가 없습니다", systemImage: "doc.text", description: Text("크래시가 발생한 뒤 앱을 다시 실행하면 보고서가 표시됩니다."))
                } else {
                    Section("크래시 로그") {
                        ForEach(reports, id: \.self) { url in
                            NavigationLink(url.lastPathComponent) { CrashReportDetail(url: url) }
                        }
                    }
                }
            }
            .navigationTitle("크래시 보고서")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("전체 삭제", role: .destructive) { confirmsDeletion = true }
                        .disabled(reports.isEmpty)
                }
            }
            .task { refresh() }
            .refreshable { refresh() }
            .confirmationDialog("저장된 크래시 보고서를 모두 삭제할까요?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                Button("전체 삭제", role: .destructive) {
                    do {
                        try WaterCrashReporter.shared.removeAllReports()
                        refresh()
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        }
    }

    private func refresh() {
        do {
            reports = try WaterCrashReporter.shared.reportURLs()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct CrashReportDetail: View {
    let url: URL
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text).font(.system(.caption, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
        }
        .navigationTitle("크래시 로그")
        .toolbar { ShareLink(item: url) }
        .task {
            do { text = try String(contentsOf: url, encoding: .utf8) }
            catch { text = "보고서 읽기 실패: \(error.localizedDescription)" }
        }
    }
}

#endif
