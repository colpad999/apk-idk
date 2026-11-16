package com.example.apk_idk

import android.content.Intent
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
    }
}
