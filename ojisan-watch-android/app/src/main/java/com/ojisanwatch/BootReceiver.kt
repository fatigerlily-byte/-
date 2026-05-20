package com.ojisanwatch

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** 端末起動時にオーバーレイサービスを自動開始する */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val serviceIntent = Intent(context, OjisanOverlayService::class.java)
            context.startForegroundService(serviceIntent)
        }
    }
}
