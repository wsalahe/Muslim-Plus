package com.wsalahe.quran_app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mp/native").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openSettings" -> {
                        val kind = call.argument<String>("kind") ?: "app"
                        val pkg = Uri.parse("package:" + packageName)
                        val i = when (kind) {
                            "notif" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            "exact" -> if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg) else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
                            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
                            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
                        }
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(i)
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(true)
                    }
                    "isIgnoringBattery" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "scheduleAdhan" -> {
                        val arr = org.json.JSONArray(call.argument<String>("items") ?: "[]")
                        val r = AdhanNative.schedule(applicationContext, arr)
                        result.success(listOf(r.first, r.second))
                    }
                    "playAdhan" -> {
                        val i = Intent(applicationContext, AdhanService::class.java).setAction(AdhanService.ACTION_PLAY)
                            .putExtra("title", call.argument<String>("title")).putExtra("body", call.argument<String>("body"))
                            .putExtra("raw", call.argument<String>("raw")).putExtra("uri", call.argument<String>("uri"))
                        androidx.core.content.ContextCompat.startForegroundService(applicationContext, i)
                        result.success(true)
                    }
                    "stopAdhan" -> {
                        startService(Intent(applicationContext, AdhanService::class.java).setAction(AdhanService.ACTION_STOP))
                        result.success(true)
                    }
                    "diagnostics" -> {
                        val m = HashMap<String, Any?>()
                        m["model"] = Build.MANUFACTURER + " " + Build.MODEL
                        m["android"] = Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")"
                        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                        m["notif"] = nm.areNotificationsEnabled()
                        m["exact"] = AdhanNative.canExact(applicationContext)
                        m["battery"] = (getSystemService(POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(packageName)
                        m["dnd"] = if (Build.VERSION.SDK_INT >= 23) nm.currentInterruptionFilter else 0
                        val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
                        m["alarmVol"] = am.getStreamVolume(android.media.AudioManager.STREAM_ALARM)
                        m["alarmMax"] = am.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM)
                        val pr = getSharedPreferences(AdhanNative.PREFS, MODE_PRIVATE)
                        m["lastFired"] = pr.getLong(AdhanNative.KEY_LAST, 0L)
                        m["lastErr"] = pr.getString(AdhanNative.KEY_LAST_ERR, "") ?: ""
                        m["saved"] = try { org.json.JSONArray(pr.getString(AdhanNative.KEY_ITEMS, "[]")).length() } catch (e: Exception) { 0 }
                        result.success(m)
                    }
                    "registerSound" -> {
                        val path = call.argument<String>("path")!!
                        val name = call.argument<String>("name") ?: "adhan"
                        val old = call.argument<String>("old")
                        result.success(registerSound(path, name, old))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERR", e.message, null)
            }
        }
    }

    // ينسخ الملف إلى مجلد Notifications العام عبر MediaStore ليقرأه النظام كصوت إشعار (أندرويد 10+).
    private fun registerSound(path: String, name: String, old: String?): String? {
        if (Build.VERSION.SDK_INT < 29) return null
        if (old != null && old.isNotEmpty()) {
            try { contentResolver.delete(Uri.parse(old), null, null) } catch (e: Exception) {}
        }
        val ext = File(path).extension.lowercase().ifEmpty { "mp3" }
        val mime = when (ext) {
            "m4a", "aac" -> "audio/mp4"
            "ogg" -> "audio/ogg"
            "wav" -> "audio/wav"
            else -> "audio/mpeg"
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, "muslimplus_" + System.currentTimeMillis() + "." + ext)
            put(MediaStore.Audio.Media.TITLE, name)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/MuslimPlus")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        contentResolver.openOutputStream(uri)?.use { out -> File(path).inputStream().use { it.copyTo(out) } }
        val done = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
        contentResolver.update(uri, done, null, null)
        return uri.toString()
    }
}
