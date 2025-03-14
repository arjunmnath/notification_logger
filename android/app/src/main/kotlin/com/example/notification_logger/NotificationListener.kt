// File: android/app/src/main/kotlin/com/example/notification_logger/NotificationListener.kt

package com.example.notification_logger

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONArray
import org.json.JSONObject

class NotificationListener : NotificationListenerService() {
    private val TAG = "NotificationListener"

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Notification Listener Service created")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val notification = sbn.notification
            val extras = notification.extras

            val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val packageName = sbn.packageName

            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                .format(Date(sbn.postTime))

            val notificationData = JSONObject().apply {
                put("title", title)
                put("text", text)
                put("packageName", packageName)
                put("timestamp", timestamp)
            }

            // Save to local storage directly since we can't use method channel from service
            saveNotification(notificationData)

            Log.d(TAG, "Notification saved: $title from $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    private fun saveNotification(notification: JSONObject) {
        try {
            val file = File(applicationContext.filesDir, "notifications.json")

            // Create file if it doesn't exist
            if (!file.exists()) {
                file.createNewFile()
                FileWriter(file).use { writer ->
                    writer.write("[]")
                    writer.flush()
                }
            }

            // Read existing notifications
            val content = file.readText()
            val jsonArray = if (content.isBlank()) JSONArray() else JSONArray(content)

            // Add new notification
            jsonArray.put(notification)

            // Write back to file
            FileWriter(file).use { writer ->
                writer.write(jsonArray.toString())
                writer.flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving notification", e)
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }
}