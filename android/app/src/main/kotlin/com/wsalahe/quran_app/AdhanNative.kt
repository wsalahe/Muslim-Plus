package com.wsalahe.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** جدولة الأذان عبر AlarmManager مباشرة (لا تعتمد على صوت الإشعار). */
object AdhanNative {
    const val PREFS = "adhan_native"
    const val KEY_ITEMS = "items"
    const val KEY_LAST = "last_fired"
    const val KEY_LAST_ERR = "last_err"

    fun canExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    private fun pending(ctx: Context, id: Int, item: JSONObject?): PendingIntent {
        val i = Intent(ctx, AdhanReceiver::class.java).setAction("com.wsalahe.quran_app.ADHAN_$id")
        if (item != null) {
            i.putExtra("title", item.optString("title"))
            i.putExtra("body", item.optString("body"))
            i.putExtra("raw", item.optString("raw"))
            i.putExtra("uri", item.optString("uri"))
            i.putExtra("id", id)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(ctx, id, i, flags)
    }

    /** يلغي الجدولة القديمة ويجدول العناصر المستقبلية. يعيد: (عدد المجدول, هل دقيق). */
    fun schedule(ctx: Context, items: JSONArray, saveOnly: Boolean = false): Pair<Int, Boolean> {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // ألغِ القديم
        val old = try { JSONArray(prefs.getString(KEY_ITEMS, "[]")) } catch (e: Exception) { JSONArray() }
        for (k in 0 until old.length()) {
            val o = old.getJSONObject(k)
            try { am.cancel(pending(ctx, o.getInt("id"), null)) } catch (e: Exception) {}
        }
        if (!saveOnly) prefs.edit().putString(KEY_ITEMS, items.toString()).apply()
        val now = System.currentTimeMillis()
        val exact = canExact(ctx)
        var n = 0
        for (k in 0 until items.length()) {
            val o = items.getJSONObject(k)
            val at = o.getLong("at")
            if (at <= now) continue
            val pi = pending(ctx, o.getInt("id"), o)
            try {
                if (exact) {
                    // setAlarmClock: الأكثر موثوقية، يعمل في وضع Doze
                    val show = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                }
                n++
            } catch (e: Exception) {
                prefs.edit().putString(KEY_LAST_ERR, e.toString()).apply()
            }
        }
        return Pair(n, exact)
    }

    /** يعيد جدولة المحفوظ بعد إعادة التشغيل أو تغيير الوقت. */
    fun rescheduleSaved(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val s = prefs.getString(KEY_ITEMS, null) ?: return
        try { schedule(ctx, JSONArray(s), true) } catch (e: Exception) { prefs.edit().putString(KEY_LAST_ERR, e.toString()).apply() }
    }
}
