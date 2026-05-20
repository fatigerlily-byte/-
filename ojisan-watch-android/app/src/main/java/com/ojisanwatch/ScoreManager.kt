package com.ojisanwatch

/**
 * スワイプ速度 + 視聴時間からおじさんの「侵食度」(0〜100%)を計算するシングルトン。
 *
 * スコア設計：
 *  - スワイプのたびに速度比例で加算（最大+14/回）
 *  - 毎秒 +0.15 のじわじわタイムボーナス（10分で最大15%分）
 *  - 最後のスワイプから4秒経過するとじわじわ減衰
 */
object ScoreManager {

    private var swipeScore: Float = 0f
    private var sessionSeconds: Int = 0
    private var lastSwipeAt: Long = 0L
    var swipeCount: Int = 0
        private set

    private var listener: ((score: Float, swipes: Int, seconds: Int) -> Unit)? = null

    fun setListener(l: (score: Float, swipes: Int, seconds: Int) -> Unit) {
        listener = l
    }

    /** AccessibilityService から呼ばれる */
    fun onSwipe(speedPxPerSec: Float) {
        val normalized = (speedPxPerSec / 3000f).coerceIn(0f, 1f)
        swipeScore = (swipeScore + normalized * 12f + 2f).coerceAtMost(100f)
        lastSwipeAt = System.currentTimeMillis()
        swipeCount++
        notify()
    }

    /** OjisanOverlayService の1秒タイマーから呼ばれる */
    fun onTick() {
        sessionSeconds++

        // 時間ボーナス（じわじわ）
        val timeBonus = (sessionSeconds / 600f).coerceAtMost(1f) * 0.15f
        swipeScore = (swipeScore + timeBonus).coerceAtMost(100f)

        // スワイプが止まったら減衰
        if (lastSwipeAt > 0L) {
            val secSinceSwipe = (System.currentTimeMillis() - lastSwipeAt) / 1000f
            if (secSinceSwipe > 4f) {
                val decay = 0.4f + (secSinceSwipe - 4f) * 0.08f
                swipeScore = (swipeScore - decay).coerceAtLeast(0f)
            }
        }

        notify()
    }

    fun getScore(): Float = swipeScore
    fun getSessionSeconds(): Int = sessionSeconds

    fun reset() {
        swipeScore = 0f
        sessionSeconds = 0
        lastSwipeAt = 0L
        swipeCount = 0
    }

    private fun notify() {
        listener?.invoke(swipeScore, swipeCount, sessionSeconds)
    }
}
