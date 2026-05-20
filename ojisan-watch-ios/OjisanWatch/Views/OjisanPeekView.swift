import SwiftUI

/// 画面左端からおじさんの顔が「侵食」するオーバーレイビュー。
///
/// スコアが 0% → コンテナ幅 0px（顔は見えない）
/// スコアが 100% → コンテナ幅 = maxSize（全顔が見える）
/// コンテナは左端 (leading) に固定され、幅が右方向へ伸びる。
/// 顔は trailing-aligned なので、右側から順に顔の中心（目・鼻）が現れてくる。
struct OjisanPeekView: View {

    @ObservedObject var scoreManager: ScoreManager

    private let maxSize: CGFloat = 320

    private var currentWidth: CGFloat {
        CGFloat(scoreManager.score / 100) * maxSize
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 0) {

                // ── おじさんの顔（左端から侵食）──────────────────────
                OjisanFaceView()
                    .frame(width: maxSize, height: maxSize)
                    // trailing-align: スコアが低いうちは顔の右側（目・鼻）から見える
                    .frame(width: max(currentWidth, 0), alignment: .trailing)
                    .clipped()
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 4, y: 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentWidth)

                // ── セリフバブル ──────────────────────────────────────
                if let msg = scoreManager.speechMessage, currentWidth > 40 {
                    SpeechBubbleView(text: msg)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7, anchor: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - セリフバブル

struct SpeechBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.black.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
            )
            .overlay(
                // しっぽ（◀）
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .offset(x: -14, y: 0),
                alignment: .leading
            )
            .padding(.leading, 10)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OjisanPeekView(scoreManager: {
            let sm = ScoreManager()
            sm.score = 65
            return sm
        }())
    }
}
