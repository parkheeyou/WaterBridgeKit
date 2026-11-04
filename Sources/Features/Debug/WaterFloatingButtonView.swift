//
//  File.swift
//  WaterBridgeKit
//
//  Created by hugh paak on 11/4/26.
//

import Foundation
import UIKit
import SwiftUI

// 디버그일 경우 로그 / 크래쉬 플로팅 버튼 보이게
public extension View {
    /// DEBUG 빌드에서 로그 콘솔과 크래시 보고서 플로팅 버튼을 표시합니다.
    @ViewBuilder
    func waterDebugConsole(isEnabled: Bool = true) -> some View {
#if DEBUG
        modifier(WaterDebugConsoleModifier(isEnabled: isEnabled))
#else
        self
#endif
    }
}

// 로그 / 크래쉬 플로팅 버튼 뷰
#if DEBUG
private struct WaterDebugConsoleModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isPresented = false
    @State private var showsCrashReports = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isEnabled, !isPresented {
                HStack(spacing: 8) {
                    floatingButton(
                        "크래시",
                        systemImage: "doc.text.magnifyingglass"
                    ) {
                        showsCrashReports = true
                    }
                    .accessibilityLabel("크래시 보고서 열기")

                    floatingButton(
                        "로그",
                        systemImage: "terminal.fill"
                    ) {
                        WaterDebugLogger.event(
                            "디버그 로그 콘솔을 열었습니다."
                        )
                        
                        withAnimation(
                            .easeInOut(duration: 0.2)
                        ) {
                            isPresented = true
                        }
                    }
                    .accessibilityLabel("디버그 로그 열기")
                }
                .padding(16)
            }

            if isEnabled, isPresented {
                WaterDebugConsoleView {
                    withAnimation(
                        .easeInOut(duration: 0.2)
                    ) {
                        isPresented = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showsCrashReports) {
            WaterCrashReportsView()
        }
    }

    private func floatingButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(
                title,
                systemImage: systemImage
            )
            .font(.caption.bold())
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            .black.opacity(0.82),
            in: Capsule()
        )
        .overlay(
            Capsule().stroke(
                .white.opacity(0.22)
            )
        )
        .shadow(
            color: .black.opacity(0.3),
            radius: 8,
            y: 3
        )
    }
}
#endif
