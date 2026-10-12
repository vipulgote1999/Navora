package com.navora.navora.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.navora.navora.car.CarNavState

/**
 * Ongoing navigation notification. Keeps location + car templates alive
 * when the phone screen is off. Dart drives it via MainActivity intents.
 */
class NavoraNavigationService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val mgr = getSystemService(NotificationManager::class.java)
      mgr?.createNotificationChannel(
        NotificationChannel(
          CHANNEL_ID, "Navigation", NotificationManager.IMPORTANCE_LOW,
        ),
      )
    }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_STOP -> {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        return START_NOT_STICKY
      }
      else -> {
        val dest = CarNavState.destinationName.ifBlank { "Navora navigation" }
        val text = if (CarNavState.navigating) {
          val km = CarNavState.distanceM / 1000.0
          val min = CarNavState.durationSec / 60
          "To " + dest + " · " + String.format("%.1f km", km) + " · " + min + " min"
        } else {
          "Ready"
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          Notification.Builder(this, CHANNEL_ID)
        } else {
          @Suppress("DEPRECATION") Notification.Builder(this)
        }
        val notification = builder
          .setContentTitle("Navora navigating")
          .setContentText(text)
          .setSmallIcon(android.R.drawable.ic_menu_mylocation)
          .setOngoing(true)
          .build()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
      }
    }
  }

  companion object {
    const val CHANNEL_ID = "navora_navigation"
    const val NOTIFICATION_ID = 1701
    const val ACTION_START = "com.navora.navora.action.NAV_START"
    const val ACTION_STOP = "com.navora.navora.action.NAV_STOP"
  }
}
