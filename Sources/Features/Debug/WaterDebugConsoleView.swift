#if canImport(UIKit)
import SwiftUI
import UIKit
import WaterBridgeCore

public extension View {
    /// DEBUG 빌드에서 화면 위에 앱 내 로그 콘솔 버튼을 표시합니다.
    @ViewBuilder
    func waterDebugConsole(isEnabled: Bool = true) -> some View {
#if DEBUG
        modifier(WaterDebugConsoleModifier(isEnabled: isEnabled))
#else
        self
#endif
    }
}

#if DEBUG
private struct WaterDebugConsoleModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isPresented = false

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content

            if isEnabled, !isPresented {
                Button {
                    WaterDebugLogger.event("디버그 로그 콘솔을 열었습니다.")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = true
                    }
                } label: {
                    Label("로그", systemImage: "terminal.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.black.opacity(0.82), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22)))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                .padding(16)
                .accessibilityLabel("디버그 로그 열기")
            }

            if isEnabled, isPresented {
                WaterDebugConsoleView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

private struct WaterDebugConsoleView: View {
    let onClose: () -> Void
    @State private var selectedCategory: WaterDebugLogCategory?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let entries = filteredEntries(
                WaterDebugLogCenter.shared.entries().reversed()
            )

            ZStack {
                Color.black.opacity(0.94)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(entryCount: entries.count)
                    categoryFilter
                    Divider().overlay(.white.opacity(0.16))

                    if entries.isEmpty {
                        ContentUnavailableView(
                            "표시할 로그가 없습니다",
                            systemImage: "terminal",
                            description: Text("화면에서 동작한 뒤 로그를 다시 확인해 주세요.")
                        )
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(entries) { entry in
                                    logRow(entry)
                                }
                            }
                            .padding(14)
                        }
                    }
                }
                .safeAreaPadding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(entryCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
            Text("Water Logs")
                .font(.headline.monospaced())
            Text("\(entryCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Button("복사", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = WaterDebugLogCenter.shared.exportText()
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            Button("초기화", systemImage: "trash") {
                WaterDebugLogCenter.shared.clear()
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            Button("닫기", systemImage: "xmark.circle.fill", action: onClose)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.body)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(title: "ALL", category: nil)
                ForEach(WaterDebugLogCategory.allCases, id: \.self) { category in
                    categoryButton(title: category.rawValue, category: category)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private func categoryButton(
        title: String,
        category: WaterDebugLogCategory?
    ) -> some View {
        let isSelected = selectedCategory == category
        return Button(title) {
            selectedCategory = category
        }
        .font(.caption2.bold().monospaced())
        .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.green : Color.white.opacity(0.1), in: Capsule())
    }

    private func logRow(_ entry: WaterDebugLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .foregroundStyle(.white.opacity(0.5))
                Text(entry.category.rawValue)
                    .foregroundStyle(categoryColor(entry.category))
                Text(entry.level.rawValue)
                    .foregroundStyle(levelColor(entry.level))
            }
            .font(.caption2.monospaced())

            Text(entry.message)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func filteredEntries(
        _ entries: ReversedCollection<[WaterDebugLogEntry]>
    ) -> [WaterDebugLogEntry] {
        entries.filter { entry in
            selectedCategory == nil || entry.category == selectedCategory
        }
    }

    private func categoryColor(_ category: WaterDebugLogCategory) -> Color {
        switch category {
        case .event: .mint
        case .api: .cyan
        case .bridge: .orange
        case .webView: .blue
        case .crash: .pink
        case .custom: .purple
        }
    }

    private func levelColor(_ level: WaterDebugLogLevel) -> Color {
        switch level {
        case .debug: .gray
        case .info: .green
        case .warning: .yellow
        case .error: .red
        }
    }
}
#endif
#endif
