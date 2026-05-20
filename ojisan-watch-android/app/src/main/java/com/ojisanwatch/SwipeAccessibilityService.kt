package com.ojisanwatch

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

/**
 * TikTok・YouTube など動画アプリのスクロールイベントを捕捉し、
 * スワイプ速度を ScoreManager に伝える Accessibility サービス。
 *
 * スワイプ速度の推定：
 *   連続するスクロールイベント間の時間差 (dt) が短いほど速いスワイプと判定する。
 *   dt=50ms  → 6000 px/s 相当（高速スワイプ）
 *   dt=300ms → 1000 px/s 相当（ゆっくりスクロール）
 */
class SwipeAccessibilityService : AccessibilityService() {

    /** 監視対象アプリのパッケージ名 */
    private val targetPackages = setOf(
        "com.zhiliaoapp.musically",   // TikTok (グローバル)
        "com.ss.android.ugc.aweme",   // TikTok (中国/一部地域)
        "com.google.android.youtube", // YouTube / YouTube Shorts
        "com.instagram.android",      // Instagram Reels
        "com.twitter.android",        // Twitter/X
        "com.snapchat.android",       // Snapchat
        "jp.tiktok.android",          // TikTok (日本向け)
    )

    private var lastScrollTime: Long = 0L

    override fun onServiceConnected() {
        serviceInfo = serviceInfo.also {
            it.eventTypes = AccessibilityEvent.TYPE_VIEW_SCROLLED
            it.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            it.packageNames = targetPackages.toTypedArray()
            it.notificationTimeout = 50
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_SCROLLED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in targetPackages) return

        val now = System.currentTimeMillis()
        val dt = (now - lastScrollTime).coerceAtLeast(1L)

        // 同セッション内のスワイプのみカウント（2秒以上空いたら新セッション）
        if (lastScrollTime > 0L && dt < 2_000L) {
            // dt が短いほどスワイプが速い（300px 分の仮想距離として換算）
            val estimatedSpeedPxPerSec = 300_000f / dt
            ScoreManager.onSwipe(estimatedSpeedPxPerSec)
        }

        lastScrollTime = now
    }

    override fun onInterrupt() {}
}
