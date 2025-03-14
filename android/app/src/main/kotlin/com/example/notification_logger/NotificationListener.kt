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

            // Try to extract expanded text content
            val expandedText = extractExpandedText(extras)

            val notificationData = JSONObject().apply {
                put("title", title)
                put("text", text)
                put("packageName", packageName)
                put("timestamp", timestamp)
                put("expandedText", expandedText)
                put("hasExpandedContent", expandedText.isNotEmpty() && expandedText != text)
                put("notificationId", sbn.id)
                put("notificationKey", sbn.key)
            }

            // Save to local storage
            if (packageName.equals("com.whatsapp")) {
                saveNotification(notificationData)
            }

            Log.d(TAG, "Notification saved: $title from $packageName")
            if (expandedText.isNotEmpty() && expandedText != text) {
                Log.d(TAG, "Expanded content captured: $expandedText")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    private fun extractExpandedText(extras: Bundle): String {
        // Try to get expanded text from different possible sources
        val expandedText = StringBuilder()

        // Try to extract BigTextStyle content
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        if (!bigText.isNullOrEmpty()) {
            expandedText.append(bigText)
        }

        // Try to extract InboxStyle content (list of messages)
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (textLines != null && textLines.isNotEmpty()) {
            for (line in textLines) {
                if (expandedText.isNotEmpty()) expandedText.append("\n")
                expandedText.append(line)
            }
        }

        // Try to extract summary text
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