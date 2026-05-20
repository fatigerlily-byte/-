package com.ojisanwatch

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * フォアグラウンドサービス。
 * - 画面の左端からおじさんの顔をオーバーレイ表示する。
 * - スコアが上がるほど顔が大きくなり（左から侵食）、スワイプをやめると徐々に縮む。
 */
class OjisanOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var overlayRoot: FrameLayout
    private lateinit var ojisanView: OjisanView
    private lateinit var speechView: TextView
    private lateinit var wmParams: WindowManager.LayoutParams

    private val handler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null

    private var lastSpeechMsg: String? = null

    /** おじさんの最大サイズ (dp → px は onCreate で変換) */
    private var maxSizePx: Int = 0

    companion object {
        const val CHANNEL_ID = "ojisan_channel"
        const val NOTIF_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        maxSizePx = (resources.displayMetrics.density * 320).toInt()

        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())

        setupOverlay()
        startTickLoop()

        ScoreManager.setListener { score, swipes, seconds ->
            handler.post { onScoreUpdate(score, swipes, seconds) }
        }
    }

    // ── オーバーレイの構築 ────────────────────────────────────────────

    private fun setupOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        // おじさん本体（右端に配置 → コンテナが左から広がると顔が現れる）
        ojisanView = OjisanView(this)
        val ojParams = FrameLayout.LayoutParams(maxSizePx, maxSizePx, Gravity.END or Gravity.CENTER_VERTICAL)

        // セリフバブル（おじさんの右に表示）
        speechView = TextView(this).apply {
            textSize = 13f
            setTextColor(0xFF333333.toInt())
            setPadding(28, 16, 28, 16)
            background = buildBubbleDrawable()
            visibility = View.GONE
        }
        val speechParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.END or Gravity.CENTER_VERTICAL
        ).apply { rightMargin = maxSizePx + 24 }

        overlayRoot = FrameLayout(this).apply {
            addView(ojisanView, ojParams)
            addView(speechView, speechParams)
        }

        wmParams = WindowManager.LayoutParams(
            0,                          // 初期幅 = 0（見えない）
            maxSizePx,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
        }

        windowManager.addView(overlayRoot, wmParams)
    }

    // ── スコア更新 → おじさんサイズ変更 ──────────────────────────────

    private fun onScoreUpdate(score: Float, swipes: Int, seconds: Int) {
        val targetWidth = ((score / 100f) * maxSizePx).toInt()
        wmParams.width = targetWidth
        try {
            windowManager.updateViewLayout(overlayRoot, wmParams)
        } catch (_: Exception) {}

        // セリフバブル
        val msg = speechMessageFor(score)
        if (msg != null && msg != lastSpeechMsg) {
            lastSpeechMsg = msg
            showSpeech(msg)
        }

        // 通知テキスト更新
        updateNotification(score, swipes, seconds)
    }

    private fun speechMessageFor(score: Float): String? = when {
        score >= 95f -> "頼む…もう休んでくれ…😭"
        score >= 82f -> "青春が溶けていくよ！⏳"
        score >= 65f -> "スマホ置いてみなよ…"
        score >= 45f -> "もう少し休んだら？"
        score >= 22f -> "そんなに見てて大丈夫？"
        else         -> null
    }

    private fun showSpeech(msg: String) {
        speechView.text = msg
        speechView.visibility = View.VISIBLE
        handler.removeCallbacksAndMessages("speech")
        handler.postAtTime({
            speechView.visibility = View.GONE
            lastSpeechMsg = null
        }, "speech", android.os.SystemClock.uptimeMillis() + 3500)
    }

    // ── 1秒タイマー ──────────────────────────────────────────────────

    private fun startTickLoop() {
        tickRunnable = object : Runnable {
            override fun run() {
                ScoreManager.onTick()
                handler.postDelayed(this, 1_000L)
            }
        }
        handler.post(tickRunnable!!)
    }

    // ── ライフサイクル ────────────────────────────────────────────────

    override fun onDestroy() {
        super.onDestroy()
        tickRunnable?.let { handler.removeCallbacks(it) }
        try { windowManager.removeView(overlayRoot) } catch (_: Exception) {}
        ScoreManager.reset()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── 通知 ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        val ch = NotificationChannel(
            CHANNEL_ID, "おじさんウォッチ", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "動画視聴習慣を監視しています" }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }

    private fun buildNotification(
        score: Float = 0f, swipes: Int = 0, seconds: Int = 0
    ): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val min = seconds / 60
        val sec = seconds % 60
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("おじさんウォッチ 監視中 👴")
            .setContentText("中毒度 ${score.toInt()}%  |  スワイプ ${swipes}回  |  ${min}分${sec}秒")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }

    private fun updateNotification(score: Float, swipes: Int, seconds: Int) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification(score, swipes, seconds))
    }

    private fun buildBubbleDrawable() =
        android.graphics.drawable.GradientDrawable().apply {
            setColor(0xFFFFFFFF.toInt())
            cornerRadius = 24f
            setStroke(2, 0xFFDDDDDD.toInt())
        }
}
