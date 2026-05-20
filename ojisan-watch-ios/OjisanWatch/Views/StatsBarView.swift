import SwiftUI

/// 画面上部の統計バー（時間・スワイプ数・中毒度）
struct StatsBarView: View {

    @ObservedObject var scoreManager: ScoreManager

    private var barColor: Color {
        switch scoreManager.score {
        case 80...: return .red
        case 50...: return .orange
        case 20...: return .yellow
        default:    return .green
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 統計チップ ────────────────────────────────────────────
            HStack {
                statChip(icon: "clock.fill",       value: scoreManager.formattedTime,          label: "視聴時間")
                Spacer()
                statChip(icon: "hand.tap.fill",     value: "\(scoreManager.swipeCount)回",      label: "スワイプ")
                Spacer()
                statChip(icon: "flame.fill",        value: "\(Int(scoreManager.score))%",        label: "中毒度")
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)  // safeArea top
            .padding(.bottom, 8)
            .background(
                LinearGradient(colors: [.black.opacity(0.7), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
            )

            // ── 中毒度プログレスバー ──────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 3)

                    Rectangle()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(scoreManager.score) / 100, height: 3)
                        .animation(.linear(duration: 0.4), value: scoreManager.score)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
