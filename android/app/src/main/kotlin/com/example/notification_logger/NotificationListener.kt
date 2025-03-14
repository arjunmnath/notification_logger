// File: android/app/src/main/kotlin/com/example/notification_logger/NotificationListener.kt

package com.example.notification_logger

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.IBinder
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

class NotificationListener : NotificationListenerService() {
    private val TAG = "NotificationListener"

    override fun onCreate() {
        super.onCreate()
        Log.w(TAG, "Notification Listener Service created")
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

            // Try to extract expanded text content
            val expandedText = extractExpandedText(extras)

            val notificationData = JSONObject().apply {
                put("title", title)
                put("text", text)
                put("packageName", packageName)
                put("timestamp", timestamp)
                put("expandedText", expandedText)
                // Explicitly convert to Boolean to resolve ambiguity
                put("hasExpandedContent", java.lang.Boolean.valueOf(expandedText.isNotEmpty() && expandedText != text))
                put("notificationId", sbn.id)
                put("notificationKey", sbn.key)
            }

            // Save to local storage for WhatsApp notifications
            if (packageName.equals("com.whatsapp")) {
                saveNotification(notificationData)
            }

            Log.w(TAG, "Notification saved: $title from $packageName")
            if (expandedText.isNotEmpty() && expandedText != text) {
                Log.w(TAG, "Expanded content captured: $expandedText")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    private fun extractExpandedText(extras: Bundle): String {
        // Try to get expanded text from different possible sources
        val expandedText = StringBuilder()

        // BigTextStyle content
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        if (!bigText.isNullOrEmpty()) {
            expandedText.append(bigText)
        }

        // InboxStyle content (list of messages)
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (textLines != null && textLines.isNotEmpty()) {
            for (line in textLines) {
                if (expandedText.isNotEmpty()) expandedText.append("\n")
                expandedText.append(line)
            }
        }

        // Summary text
        val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()
        if (!summaryText.isNullOrEmpty() && !expandedText.contains(summaryText)) {
            if (expandedText.isNotEmpty()) expandedText.append("\n")
            expandedText.append(summaryText)
        }

        return expandedText.toString()
    }

    private fun saveNotification(notification: JSONObject) {
        try {
            val file = File(applicationContext.filesDir, "notifications.json")
            Log.w(TAG, "Saving to file: ${file.absolutePath}")

            // Create file if it doesn't exist
            if (!file.exists()) {
                file.createNewFile()
                file.writeText("[]")
                Log.w(TAG, "Created new notifications file")
            }

            // Read existing notifications with error handling
            var jsonArray = JSONArray()
            try {
                val content = file.readText()
                if (content.isNotEmpty()) {
                    jsonArray = JSONArray(content)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading existing notifications, starting fresh", e)
                jsonArray = JSONArray()
            }

            // Add new notification
            jsonArray.put(notification)

            // Write the updated notifications array back to the file
            try {
                val contentToWrite = jsonArray.toString()
                file.writeText(contentToWrite)
                Log.w(TAG, "Successfully wrote notification to file. Total count: ${jsonArray.length()}")
                Log.w(TAG, "File content now: $contentToWrite")
            } catch (e: Exception) {
                Log.e(TAG, "Error writing to notifications file", e)
                // Fallback: try writing to cache directory
                val fallbackFile = File(applicationContext.cacheDir, "notifications_backup.json")
                try {
                    fallbackFile.writeText(jsonArray.toString())
                    Log.w(TAG, "Wrote to fallback location: ${fallbackFile.absolutePath}")
                } catch (e2: Exception) {
                    Log.e(TAG, "Even fallback write failed", e2)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Critical error saving notification", e)
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    private fun startForeground() {
        val channelId = createNotificationChannel()

        // Use a default system icon as fallback
        val notification = Notification.Builder(this, channelId)
            .setContentTitle("Notification Logger Running")
            .setContentText("Monitoring and logging notifications")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        startForeground(1001, notification)
    }

    private fun createNotificationChannel(): String {
        val channelId = "notification_logger_service"
        val channelName = "Notification Logger Service"

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                channelName,
                android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps notification logger running"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        return channelId
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground()
        return START_STICKY
    }
}
