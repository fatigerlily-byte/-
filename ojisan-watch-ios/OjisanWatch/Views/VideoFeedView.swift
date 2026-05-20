import SwiftUI

/// TikTok 風の縦スワイプフィード。
/// DragGesture でスワイプ速度を検知し ScoreManager に渡す。
struct VideoFeedView: View {

    @ObservedObject var scoreManager: ScoreManager

    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let videos = videoData

    var body: some View {
        GeometryReader { geo in
            let pageHeight = geo.size.height

            ZStack {
                // ── ページスタック ────────────────────────────────────
                ForEach(visibleRange, id: \.self) { i in
                    VideoCardView(video: videos[i])
                        .frame(width: geo.size.width, height: pageHeight)
                        .offset(y: offsetFor(index: i, pageHeight: pageHeight))
                }
            }
            .gesture(swipeGesture(pageHeight: pageHeight))
            .clipped()
        }
        .ignoresSafeArea()
    }

    // ── 表示する範囲（前後1枚だけレンダリング）─────────────────────────
    private var visibleRange: Range<Int> {
        let lo = max(0, currentIndex - 1)
        let hi = min(videos.count, currentIndex + 2)
        return lo..<hi
    }

    private func offsetFor(index: Int, pageHeight: CGFloat) -> CGFloat {
        let base = CGFloat(index - currentIndex) * pageHeight
        return base + dragOffset
    }

    // ── スワイプジェスチャー ─────────────────────────────────────────
    private func swipeGesture(pageHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false
                handleSwipeEnd(value: value, pageHeight: pageHeight)
            }
    }

    private func handleSwipeEnd(value: DragGesture.Value, pageHeight: CGFloat) {
        let translation = value.translation.height

        // iOS 17+ は velocity プロパティが使える
        let velocity: CGFloat
        if #available(iOS 17.0, *) {
            velocity = value.velocity.height
        } else {
            velocity = (value.predictedEndTranslation.height - translation) * 2
        }

        let shouldAdvance = abs(translation) > 60 || abs(velocity) > 400

        if shouldAdvance {
            let direction = (translation < 0) ? 1 : -1
            let newIndex = (currentIndex + direction).clamped(to: 0...(videos.count - 1))

            if newIndex != currentIndex {
                let speed = Float(abs(velocity).clamped(to: 0...5000))
                scoreManager.onSwipe(speed: speed)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    currentIndex = newIndex
                    dragOffset = 0
                }
                return
            }
        }

        // スナップバック
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            dragOffset = 0
        }
    }
}

// MARK: - Comparable clamp helper
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
