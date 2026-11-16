package com.example.apk_idk

import android.app.*
import android.content.*
import android.media.*
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import org.json.JSONObject
import java.util.Calendar

/** Native alarm schedules are kept separately from the accounting database.
 * SQLite remains the source of truth and Flutter reconciles on resume. */
object HabitAlarm {
    private const val PREF = "habit_alarm_v1"
    const val CHANNEL = "habit_alarm_controls_v1"
    const val FIRE = "com.example.apk_idk.ALARM_FIRE"
    const val SNOOZE_FIRE = "com.example.apk_idk.ALARM_SNOOZE_FIRE"
    const val STOP = "com.example.apk_idk.ALARM_STOP"
    const val SNOOZE = "com.example.apk_idk.ALARM_SNOOZE"
    private const val ACTIVE = "active"
    private const val FOREGROUND_ID = 1891745
    private fun prefs(c: Context) = c.getSharedPreferences(PREF, Context.MODE_PRIVATE)
    private fun manager(c: Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun pending(c: Context, id: Int, action: String): PendingIntent {
        val intent = Intent(c, HabitAlarmReceiver::class.java).setAction(action)
            .setData(android.net.Uri.parse("colpad://alarm/$action/$id"))
            .putExtra("id", id)
        return PendingIntent.getBroadcast(c, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun scheduleAt(c: Context, id: Int, action: String, at: Long) {
        val am = manager(c)
        val pi = pending(c, id, action)
        // Exact alarms are optional. Never bypass a denied special permission.
        if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
            try { am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi); return }
            catch (_: SecurityException) { /* permission may have changed */ }
        }
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    }
    fun enabled(c: Context) = prefs(c).getBoolean("enabled", false)
    fun setEnabled(c: Context, value: Boolean) { prefs(c).edit().putBoolean("enabled", value).commit() }
    fun save(c: Context, record: JSONObject) {
        val id = record.getInt("id")
        val at = record.getLong("at")
        val calendar = Calendar.getInstance().apply { timeInMillis = at }
        record.put("year", calendar.get(Calendar.YEAR)).put("month", calendar.get(Calendar.MONTH))
            .put("day", calendar.get(Calendar.DAY_OF_MONTH)).put("weekday", calendar.get(Calendar.DAY_OF_WEEK))
            .put("hour", calendar.get(Calendar.HOUR_OF_DAY)).put("minute", calendar.get(Calendar.MINUTE))
        if (!prefs(c).edit().putString("schedule_$id", record.toString()).commit()) throw IllegalStateException("Jadwal alarm gagal disimpan")
        scheduleAt(c, id, FIRE, at)
    }
    private fun keys(c: Context, prefix: String) = prefs(c).all.keys.filter { it.startsWith(prefix) }
    fun cancelHabit(c: Context, habit: Int, includeSnooze: Boolean = false) {
        for (key in keys(c, "schedule_")) {
            val r = record(c, key) ?: continue
            if (r.optInt("habit") == habit) {
                manager(c).cancel(pending(c, r.getInt("id"), FIRE)); prefs(c).edit().remove(key).commit()
            }
        }
        if (includeSnooze) {
            for (key in keys(c, "snooze_")) {
                val r = record(c, key) ?: continue
                if (r.optInt("habit") == habit) {
                    manager(c).cancel(pending(c, r.getInt("id"), SNOOZE_FIRE)); prefs(c).edit().remove(key).commit()
                }
            }
            val remaining = active(c).filter { it.optInt("habit") != habit }
            setActive(c, remaining)
            if (remaining.isEmpty()) c.stopService(Intent(c, HabitAlarmService::class.java))
        }
    }
    fun cancelAll(c: Context) {
        for (key in keys(c, "schedule_") + keys(c, "snooze_")) {
            val r = record(c, key) ?: continue
            manager(c).cancel(pending(c, r.getInt("id"), if (key.startsWith("snooze_")) SNOOZE_FIRE else FIRE))
            prefs(c).edit().remove(key).commit()
        }
        setActive(c, emptyList())
        c.stopService(Intent(c, HabitAlarmService::class.java))
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(FOREGROUND_ID)
    }
    private fun record(c: Context, key: String): JSONObject? = try {
        prefs(c).getString(key, null)?.let { JSONObject(it) }
    } catch (_: Exception) { null }
    private fun active(c: Context): List<JSONObject> = try {
        val array = org.json.JSONArray(prefs(c).getString(ACTIVE, "[]"))
        (0 until array.length()).map { array.getJSONObject(it) }
    } catch (_: Exception) { emptyList() }
    private fun setActive(c: Context, list: List<JSONObject>) {
        val array = org.json.JSONArray(); list.forEach { array.put(it) }
        prefs(c).edit().putString(ACTIVE, array.toString()).commit()
    }
    fun deliver(c: Context, id: Int, snoozed: Boolean) {
        val key = (if (snoozed) "snooze_" else "schedule_") + id
        val r = record(c, key) ?: return // stale delivery
        if (snoozed || !r.optBoolean("weekly")) prefs(c).edit().remove(key).commit()
        else {
            val next = nextWeekly(r)
            r.put("at", next); prefs(c).edit().putString(key, r.toString()).commit()
            scheduleAt(c, id, FIRE, next)
        }
        val notifications = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notifications.areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED)) {
            Log.w("HabitAlarm", "Notification permission unavailable; alarm not started without visible controls")
            return
        }
        val current = active(c).filter { it.optInt("id") != id } + r
        setActive(c, current)
        try {
            val service = Intent(c, HabitAlarmService::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(service) else c.startService(service)
        } catch (e: Exception) {
            Log.e("HabitAlarm", "Unable to start alarm service", e)
            notify(c, current)
        }
    }
    private fun nextWeekly(r: JSONObject): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, r.getInt("hour")); set(Calendar.MINUTE, r.getInt("minute"))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            val days = (r.getInt("weekday") - get(Calendar.DAY_OF_WEEK) + 7) % 7
            add(Calendar.DAY_OF_YEAR, days)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 7)
        }
        return cal.timeInMillis
    }
    fun reconcile(c: Context) {
        for (key in keys(c, "schedule_")) {
            val r = record(c, key) ?: continue
            val id = r.getInt("id")
            val at = if (r.optBoolean("weekly")) nextWeekly(r) else Calendar.getInstance().apply {
                set(r.getInt("year"), r.getInt("month"), r.getInt("day"), r.getInt("hour"), r.getInt("minute"), 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            if (at > System.currentTimeMillis()) { r.put("at", at); prefs(c).edit().putString(key, r.toString()).commit(); scheduleAt(c, id, FIRE, at) }
            else prefs(c).edit().remove(key).commit()
        }
        for (key in keys(c, "snooze_")) {
            val r = record(c, key) ?: continue
            scheduleAt(c, r.getInt("id"), SNOOZE_FIRE, maxOf(System.currentTimeMillis() + 1000, r.getLong("snoozeAt")))
        }
        // A reboot does not restart foreground audio; make an interrupted alarm
        // deliver again through AlarmManager rather than starting FGS from boot.
        val interrupted = active(c); setActive(c, emptyList())
        for (r in interrupted) {
            val id = r.getInt("id"); r.put("snoozeAt", System.currentTimeMillis() + 2000)
            prefs(c).edit().putString("snooze_$id", r.toString()).commit()
            scheduleAt(c, id, SNOOZE_FIRE, r.getLong("snoozeAt"))
        }
    }
    fun action(c: Context, snooze: Boolean) {
        val current = active(c)
        if (snooze) for (r in current) {
            val id = r.getInt("id"); r.put("snoozeAt", System.currentTimeMillis() + 10 * 60_000L)
            prefs(c).edit().putString("snooze_$id", r.toString()).commit()
            scheduleAt(c, id, SNOOZE_FIRE, r.getLong("snoozeAt"))
        }
        setActive(c, emptyList()); c.stopService(Intent(c, HabitAlarmService::class.java))
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(FOREGROUND_ID)
    }
    fun notify(c: Context, items: List<JSONObject>): Notification {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL, "Alarm habit – tombol", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(null, null); ch.enableVibration(false); nm.createNotificationChannel(ch)
        }
        val stop = PendingIntent.getBroadcast(c, 1, Intent(c, HabitAlarmReceiver::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val snooze = PendingIntent.getBroadcast(c, 2, Intent(c, HabitAlarmReceiver::class.java).setAction(SNOOZE), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val title = if (items.size == 1) items.first().optString("title", "Alarm habit") else "${items.size} alarm habit"
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        val notification = builder.setSmallIcon(c.applicationInfo.icon).setContentTitle(title)
            .setContentText("Ketuk MATIKAN atau SNOOZE 10 menit")
            .setContentIntent(open).setOngoing(true).setCategory(Notification.CATEGORY_ALARM)
            .addAction(Notification.Action.Builder(null, "MATIKAN", stop).build())
            .addAction(Notification.Action.Builder(null, "SNOOZE 10 MENIT", snooze).build()).build()
        nm.notify(FOREGROUND_ID, notification)
        return notification
    }
    fun foregroundId() = FOREGROUND_ID
    fun activeItems(c: Context) = active(c)
}

class HabitAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            when (intent.action) {
                HabitAlarm.FIRE -> HabitAlarm.deliver(context, intent.getIntExtra("id", -1), false)
                HabitAlarm.SNOOZE_FIRE -> HabitAlarm.deliver(context, intent.getIntExtra("id", -1), true)
                HabitAlarm.STOP -> HabitAlarm.action(context, false)
                HabitAlarm.SNOOZE -> HabitAlarm.action(context, true)
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> HabitAlarm.reconcile(context)
            }
        } catch (e: Exception) { Log.e("HabitAlarm", "Alarm receiver failed", e) }
    }
}

class HabitAlarmService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val items = HabitAlarm.activeItems(this)
        if (items.isEmpty()) { stopSelf(); return START_NOT_STICKY }
        startForeground(HabitAlarm.foregroundId(), HabitAlarm.notify(this, items))
        if (items.any { it.optBoolean("sound", true) } && player == null) {
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                player = MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    setDataSource(this@HabitAlarmService, uri); isLooping = true; prepare(); start()
                }
            } catch (e: Exception) { Log.e("HabitAlarm", "Alarm audio failed", e); player?.release(); player = null }
        }
        if (items.any { it.optBoolean("vibration", true) }) {
            @Suppress("DEPRECATION")
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 700, 500), 0))
        }
        return START_STICKY
    }
    override fun onDestroy() {
        try { player?.stop() } catch (_: Exception) { }
        player?.release(); player = null; vibrator?.cancel(); super.onDestroy()
    }
}
