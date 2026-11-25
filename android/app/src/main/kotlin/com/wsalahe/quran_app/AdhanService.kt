package com.wsalahe.quran_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/** خدمة تشغيل الأذان: صوت من تيار المنبه، تعمل والتطبيق مغلق، مع زر إيقاف. */
class AdhanService : Service() {
    companion object {
        const val ACTION_PLAY = "com.wsalahe.quran_app.PLAY"
        const val ACTION_STOP = "com.wsalahe.quran_app.STOP"
        const val CHANNEL = "adhan_play_v1"
        const val NOTIF_ID = 7001
    }

    private var player: MediaPlayer? = null
    private var wake: PowerManager.WakeLock? = null
    private var focusReq: Any? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                val ch = NotificationChannel(CHANNEL, "Adhan", NotificationManager.IMPORTANCE_HIGH)
                ch.setSound(null, null)
                ch.enableVibration(false)
                ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun stopNow() {
        try { player?.stop() } catch (e: Exception) {}
        try { player?.release() } catch (e: Exception) {}
        player = null
        try { if (Build.VERSION.SDK_INT >= 26) (focusReq as? android.media.AudioFocusRequest)?.let { (getSystemService(AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it) } } catch (e: Exception) {}
        try { if (wake?.isHeld == true) wake?.release() } catch (e: Exception) {}
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else stopForeground(true)
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopNow()
            return START_NOT_STICKY
        }
        ensureChannel()
        val title = intent?.getStringExtra("title") ?: "Adhan"
        val body = intent?.getStringExtra("body") ?: ""
        val stopPi = PendingIntent.getService(this, 1, Intent(this, AdhanService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val open = PendingIntent.getActivity(this, 2, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val icon = resources.getIdentifier("ic_stat_adhan", "drawable", packageName).let { if (it != 0) it else resources.getIdentifier("ic_stat_adhan", "mipmap", packageName) }
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(0, "⏹", stopPi)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) else startForeground(NOTIF_ID, n)
        } catch (e: Exception) {
            getSharedPreferences(AdhanNative.PREFS, MODE_PRIVATE).edit().putString(AdhanNative.KEY_LAST_ERR, "fg: $e").apply()
        }
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "muslimplus:adhan").also { it.acquire(10 * 60 * 1000L) }
        } catch (e: Exception) {}
        try { player?.release() } catch (e: Exception) {}
        val mp = MediaPlayer()
        player = mp
        try {
            mp.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            val uri = intent?.getStringExtra("uri") ?: ""
            val raw = intent?.getStringExtra("raw") ?: ""
            if (uri.isNotEmpty()) {
                mp.setDataSource(this, Uri.parse(uri))
            } else {
                val id = resources.getIdentifier(raw, "raw", packageName)
                val afd = resources.openRawResourceFd(id)
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            }
            try {
                val am = getSystemService(AUDIO_SERVICE) as AudioManager
                if (Build.VERSION.SDK_INT >= 26) {
                    val fr = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                        .setOnAudioFocusChangeListener { }.build()
                    focusReq = fr
                    am.requestAudioFocus(fr)
                }
            } catch (e: Exception) {}
            mp.setOnCompletionListener { stopNow() }
            mp.setOnErrorListener { _, w, e ->
                getSharedPreferences(AdhanNative.PREFS, MODE_PRIVATE).edit().putString(AdhanNative.KEY_LAST_ERR, "mp: $w/$e").apply()
                stopNow(); true
            }
            mp.prepare()
            mp.start()
        } catch (e: Exception) {
            getSharedPreferences(AdhanNative.PREFS, MODE_PRIVATE).edit().putString(AdhanNative.KEY_LAST_ERR, "play: $e").apply()
            stopNow()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        try { player?.release() } catch (e: Exception) {}
        try { if (wake?.isHeld == true) wake?.release() } catch (e: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
