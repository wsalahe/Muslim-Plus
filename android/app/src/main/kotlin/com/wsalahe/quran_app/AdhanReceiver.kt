package com.wsalahe.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val prefs = ctx.getSharedPreferences(AdhanNative.PREFS, Context.MODE_PRIVATE)
        prefs.edit().putLong(AdhanNative.KEY_LAST, System.currentTimeMillis()).apply()
        val svc = Intent(ctx, AdhanService::class.java).setAction(AdhanService.ACTION_PLAY)
            .putExtra("title", intent.getStringExtra("title"))
            .putExtra("body", intent.getStringExtra("body"))
            .putExtra("raw", intent.getStringExtra("raw"))
            .putExtra("uri", intent.getStringExtra("uri"))
        try {
            ContextCompat.startForegroundService(ctx, svc)
        } catch (e: Exception) {
            prefs.edit().putString(AdhanNative.KEY_LAST_ERR, "start: $e").apply()
        }
    }
}

class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        AdhanNative.rescheduleSaved(ctx)
    }
}
