import Foundation
import Combine

/// スワイプ速度 + 視聴時間から中毒度(0〜100)を算出するマネージャー。
///
/// スコア設計:
///  - スワイプのたびに速度比例で加算（最大 +14/回）
///  - 毎秒 +0.15 の時間ボーナス（10分で上限15%分）
///  - 最後のスワイプから4秒経過するとじわじわ減衰
@MainActor
final class ScoreManager: ObservableObject {

    @Published var score: Float = 0          // 0〜100
    @Published var swipeCount: Int = 0
    @Published var sessionSeconds: Int = 0
    @Published var lastSwipeSpeed: Float = 0

    private var lastSwipeDate: Date?
    private var timer: AnyCancellable?

    // MARK: - セッション管理

    func startSession() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stopSession() {
        timer?.cancel()
        timer = nil
    }

    func reset() {
        score = 0
        swipeCount = 0
        sessionSeconds = 0
        lastSwipeDate = nil
        lastSwipeSpeed = 0
    }

    // MARK: - スワイプ入力

    func onSwipe(speed: Float) {
        let normalized = min(speed / 3000, 1)
        score = min(score + normalized * 12 + 2, 100)
        lastSwipeDate = Date()
        swipeCount += 1
        lastSwipeSpeed = speed
    }

    // MARK: - 毎秒ティック

    private func tick() {
        sessionSeconds += 1

        // 時間ボーナス
        let timeBonus = min(Float(sessionSeconds) / 600, 1) * 0.15
        score = min(score + timeBonus, 100)

        // 減衰
        if let lastSwipe = lastSwipeDate {
            let elapsed = Float(Date().timeIntervalSince(lastSwipe))
            if elapsed > 4 {
                let decay = 0.4 + (elapsed - 4) * 0.08
                score = max(score - decay, 0)
            }
        }
    }

    // MARK: - ヘルパー

    var formattedTime: String {
        let m = sessionSeconds / 60
        let s = sessionSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var addictionLabel: String {
        switch score {
        case 80...: return "🚨 深刻な中毒状態！"
        case 60...: return "⚠️ 使いすぎ注意"
        case 40...: return "😟 そろそろ休憩を"
        case 20...: return "😐 少し増えてます"
        default:    return "😊 良好"
        }
    }

    var speechMessage: String? {
        switch score {
        case 95...: return "頼む…もう休んでくれ…😭"
        case 82...: return "青春が溶けていくよ！⏳"
        case 65...: return "スマホ置いてみなよ…"
        case 45...: return "もう少し休んだら？"
        case 22...: return "そんなに見てて大丈夫？"
        default:    return nil
        }
    }
}
