// File: android/app/src/main/kotlin/com/example/notification_logger/MainActivity.kt

package com.example.notification_logger

import android.content.Intent
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.notification_logger/service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "isServiceEnabled" -> {
                    val enabled = isNotificationServiceEnabled()
                    result.success(enabled)
                }
                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                "disableService" -> {
                    disableNotificationService()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Start notification service if enabled
        if (isNotificationServiceEnabled()) {
            val serviceIntent = Intent(this, NotificationListener::class.java)
            startService(serviceIntent)
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(pkgName)
    }

    private fun requestNotificationPermission() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun disableNotificationService() {
        // This will direct to the settings where user can disable the service
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }
}