package com.example.apk_idk

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.app.AlarmManager
import org.json.JSONObject
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "colpad/system_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openSoundSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unavailable", "Pengaturan suara Android tidak dapat dibuka.", null)
                    }
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "colpad/habit_alarm")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "history" -> result.success(ReminderHistoryStore(this).use { it.latest() })
                        "enabled" -> result.success(HabitAlarm.enabled(this))
                        "setEnabled" -> { HabitAlarm.setEnabled(this, call.argument<Boolean>("enabled") == true); result.success(null) }
                        "schedule" -> {
                            val r = JSONObject()
                            for (key in listOf("id", "habit", "title", "body", "at", "weekly", "sound", "vibration")) r.put(key, call.argument<Any>(key))
                            HabitAlarm.save(this, r); result.success(null)
                        }
                        "cancelHabit" -> { HabitAlarm.cancelHabit(this, call.argument<Int>("habit")!!); result.success(null) }
                        "clearHabit" -> { HabitAlarm.cancelHabit(this, call.argument<Int>("habit")!!, true); result.success(null) }
                        "cancelAll" -> { HabitAlarm.cancelAll(this); result.success(null) }
                        "exactAllowed" -> result.success(Build.VERSION.SDK_INT < 31 || (getSystemService(ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms())
                        "openExactSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("alarm_error", e.message, null) }
            }
    }
}
