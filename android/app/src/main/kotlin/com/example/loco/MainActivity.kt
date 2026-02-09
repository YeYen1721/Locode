package com.example.loco

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "Loco"
        private const val SCAN_CHANNEL = "com.loco/scan"
        private const val URL_EVENT_CHANNEL = "com.loco/url_events"
        private const val NOTIF_CHANNEL = "com.loco/notifications"
        private const val NOTIFICATION_CHANNEL_ID = "loco_security"
        private const val VERDICT_NOTIFICATION_ID = 3001
        var lastScannedUrl: String? = null
    }

    private var urlEventSink: EventChannel.EventSink? = null
    private var pendingUrl: String? = null
    private var isFlutterReady = false
    private var lastHandledUrl: String? = null
    private var lastHandledTime: Long = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called with extras: ${intent?.extras}")
        Log.d(TAG, "open_safe_url extra: ${intent?.getStringExtra("open_safe_url")}")
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        // Check if this is a "open in safe browser" tap from notification
        val openSafeUrl = intent?.getStringExtra("open_safe_url")
        val openSafeVerdict = intent?.getStringExtra("open_safe_verdict") ?: "suspicious"
        val openSafeSummary = intent?.getStringExtra("open_safe_summary") ?: ""
        val openSafeRiskScore = intent?.getIntExtra("open_safe_risk_score", 0) ?: 0
        if (openSafeUrl != null) {
            Log.d(TAG, "Opening safe browser for: $openSafeUrl")
            val event = "OPEN_SAFE:$openSafeVerdict|$openSafeRiskScore|$openSafeSummary|$openSafeUrl"
            if (urlEventSink != null) {
                urlEventSink?.success(event)
            } else {
                pendingUrl = event
            }
            intent?.removeExtra("open_safe_url")
            return
        }

        // Handle URL interception
        val url = intent?.data?.toString()
        if (intent?.action == Intent.ACTION_VIEW && url != null) {
            val now = System.currentTimeMillis()
            if (url == lastHandledUrl && now - lastHandledTime < 3000) {
                Log.d(TAG, "Ignoring duplicate URL: $url")
                return
            }
            lastHandledUrl = url
            lastHandledTime = now

            Log.d(TAG, "Intercepted URL: $url")
            lastScannedUrl = url

            // 1. Post immediate heads-up notification
            showAnalyzingNotification(url)

            // 2. Send URL to Flutter for Gemini analysis
            val event = "ANALYZE:$url"
            if (urlEventSink != null) {
                urlEventSink?.success(event)
            } else {
                pendingUrl = event
            }

            // 3. Go back to whatever app the user was in (camera)
            moveTaskToBack(true)
        }
    }

    private fun showAnalyzingNotification(url: String) {
        // Truncate URL for display
        val displayUrl = if (url.length > 50) url.take(50) + "..." else url

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🔍 Analyzing URL...")
            .setContentText(displayUrl)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(false)
            .setOngoing(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            // Make it a heads-up notification
            .setFullScreenIntent(null, true)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(VERDICT_NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission not granted: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        // MethodChannel for scan control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLastScannedUrl" -> {
                        result.success(pendingUrl ?: lastScannedUrl)
                    }
                    "setLastScannedUrl" -> {
                        val url = call.arguments as? String
                        lastScannedUrl = url
                        result.success(null)
                    }
                    "clearLastScannedUrl" -> {
                        pendingUrl = null
                        lastScannedUrl = null
                        result.success(null)
                    }
                    "openDefaultBrowserSettings" -> {
                        val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // MethodChannel for notification updates from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateNotification" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val verdict = call.argument<String>("verdict") ?: "suspicious"
                        val summary = call.argument<String>("summary") ?: ""
                        val url = call.argument<String>("url") ?: ""
                        val riskScore = call.argument<Int>("risk_score") ?: 0
                        val ongoing = call.argument<Boolean>("ongoing") ?: false
                        updateVerdictNotification(title, body, verdict, summary, url, riskScore, ongoing)
                        result.success(null)
                    }
                    "dismissNotification" -> {
                        NotificationManagerCompat.from(this).cancel(VERDICT_NOTIFICATION_ID)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel for real-time URL streaming to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, URL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    urlEventSink = events
                    isFlutterReady = true
                    // Send any URL that arrived before Flutter was ready
                    pendingUrl?.let {
                        urlEventSink?.success(it)
                        pendingUrl = null
                    }
                }
                override fun onCancel(arguments: Any?) {
                    urlEventSink = null
                    isFlutterReady = false
                }
            })
    }

    private fun updateVerdictNotification(
        title: String,
        body: String,
        verdict: String,
        summary: String,
        url: String,
        riskScore: Int,
        ongoing: Boolean
    ) {
        // Create intent to open Loco's SafeBrowserPage when tapped
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("open_safe_url", url)
            putExtra("open_safe_verdict", verdict)
            putExtra("open_safe_summary", summary)
            putExtra("open_safe_risk_score", riskScore)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingTapIntent = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val icon = when (verdict) {
            "safe" -> android.R.drawable.ic_dialog_info
            "suspicious" -> android.R.drawable.ic_dialog_alert
            "dangerous" -> android.R.drawable.ic_delete
            else -> android.R.drawable.ic_dialog_alert
        }

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(!ongoing)
            .setOngoing(ongoing)
            .setContentIntent(pendingTapIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(VERDICT_NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission not granted: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Loco Security Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "URL security analysis results"
                enableVibration(true)
                enableLights(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}