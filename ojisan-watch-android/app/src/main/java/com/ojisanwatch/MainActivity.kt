package com.ojisanwatch

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.appcompat.app.AppCompatActivity
import com.ojisanwatch.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupButtons()
        updatePermissionStatus()
    }

    override fun onResume() {
        super.onResume()
        updatePermissionStatus()
        startStatsUpdate()
    }

    override fun onPause() {
        super.onPause()
        updateRunnable?.let { handler.removeCallbacks(it) }
    }

    // ── ボタン設定 ────────────────────────────────────────────────────

    private fun setupButtons() {
        binding.btnGrantOverlay.setOnClickListener {
            startActivity(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            )
        }

        binding.btnGrantUsageStats.setOnClickListener {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }

        binding.btnGrantAccessibility.setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }

        binding.btnStart.setOnClickListener {
            if (!allPermissionsGranted()) return@setOnClickListener
            startForegroundService(Intent(this, OjisanOverlayService::class.java))
            updatePermissionStatus()
        }

        binding.btnStop.setOnClickListener {
            stopService(Intent(this, OjisanOverlayService::class.java))
            ScoreManager.reset()
            updatePermissionStatus()
            updateStats(0f, 0, 0)
        }
    }

    // ── パーミッション確認 ────────────────────────────────────────────

    private fun allPermissionsGranted() =
        hasOverlayPermission() && hasUsageStatsPermission() && isAccessibilityEnabled()

    private fun hasOverlayPermission() = Settings.canDrawOverlays(this)

    private fun hasUsageStatsPermission(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(), packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains(packageName, ignoreCase = true)
    }

    private fun updatePermissionStatus() {
        val ok  = "✅ 許可済み"
        val ng  = "❌ 未許可"
        val on  = "✅ 有効"
        val off = "❌ 無効"

        binding.statusOverlay.text      = if (hasOverlayPermission())      ok  else ng
        binding.statusUsageStats.text   = if (hasUsageStatsPermission())   ok  else ng
        binding.statusAccessibility.text= if (isAccessibilityEnabled())    on  else off

        val ready = allPermissionsGranted()
        binding.btnStart.isEnabled = ready
        binding.btnGrantOverlay.isEnabled      = !hasOverlayPermission()
        binding.btnGrantUsageStats.isEnabled   = !hasUsageStatsPermission()
        binding.btnGrantAccessibility.isEnabled= !isAccessibilityEnabled()
    }

    // ── リアルタイム統計 ──────────────────────────────────────────────

    private fun startStatsUpdate() {
        updateRunnable = object : Runnable {
            override fun run() {
                val score = ScoreManager.getScore()
                val swipes = ScoreManager.swipeCount
                val seconds = ScoreManager.getSessionSeconds()
                updateStats(score, swipes, seconds)
                handler.postDelayed(this, 1_000L)
            }
        }
        handler.post(updateRunnable!!)
    }

    private fun updateStats(score: Float, swipes: Int, seconds: Int) {
        val min = seconds / 60
        val sec = seconds % 60
        binding.tvScore.text   = "${score.toInt()}%"
        binding.tvSwipes.text  = "${swipes}回"
        binding.tvTime.text    = "${min}分${String.format("%02d", sec)}秒"
        binding.progressScore.progress = score.toInt()

        binding.tvScoreLabel.text = when {
            score >= 80f -> "🚨 深刻な中毒状態！"
            score >= 60f -> "⚠️ 使いすぎ注意"
            score >= 40f -> "😟 そろそろ休憩を"
            score >= 20f -> "😐 少し増えてます"
            else         -> "😊 良好"
        }
    }
}
