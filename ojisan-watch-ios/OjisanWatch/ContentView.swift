import SwiftUI

struct ContentView: View {

    @StateObject private var scoreManager = ScoreManager()
    @State private var showWarning = false
    @State private var warningMessage = ""
    @State private var lastWarningThreshold: Float = 0

    private let warningThresholds: [(Float, String)] = [
        (40, "最近スクロール速度が上がっています。\n脳が刺激に慣れてきているサインです。\n5分だけスマホを置いてみませんか？"),
        (75, "視聴時間がかなり長くなっています。\n動画で得られる幸福感は短命です。\n現実の体験に時間を使いましょう。"),
        (95, "おじさんは限界です。\nあなたの時間はとても大切です。\n今すぐアプリを閉じて外に出てください！"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {

            Color.black.ignoresSafeArea()

            // ── 動画フィード（最背面）────────────────────────────────
            VideoFeedView(scoreManager: scoreManager)

            // ── おじさん オーバーレイ ─────────────────────────────────
            OjisanPeekView(scoreManager: scoreManager)

            // ── 統計バー（最前面・タップ透過）────────────────────────
            StatsBarView(scoreManager: scoreManager)

            // ── 警告オーバーレイ ──────────────────────────────────────
            if showWarning {
                warningOverlay
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onAppear  { scoreManager.startSession() }
        .onDisappear { scoreManager.stopSession() }
        .onChange(of: scoreManager.score) { newScore in
            checkWarning(score: newScore)
        }
    }

    // MARK: - 警告オーバーレイ

    private var warningOverlay: some View {
        ZStack {
            Color.red.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("😰").font(.system(size: 64))
                Text("おじさんより\n緊急メッセージ")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Text(warningMessage)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Button {
                    withAnimation { showWarning = false }
                } label: {
                    Text("わかった、少し休む")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    // MARK: - 警告チェック

    private func checkWarning(score: Float) {
        for (threshold, message) in warningThresholds.reversed() {
            if score >= threshold && lastWarningThreshold < threshold {
                warningMessage = message
                lastWarningThreshold = threshold
                withAnimation { showWarning = true }
                return
            }
        }
    }
}

#Preview {
    ContentView()
}
