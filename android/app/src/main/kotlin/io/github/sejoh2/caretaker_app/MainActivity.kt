package io.github.sejoh2.caretaker_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertsChannel()
    }

    /*
      Kodi's notifications arrive on this channel. "High" importance is what
      makes Android show the banner at the top of the screen, with sound,
      instead of only adding it to the list pulled down from the top.
      The backend sends to this channel by name (kodi_alerts).
    */
    private fun createAlertsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            "kodi_alerts",
            "Maintenance and readings",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New issues, requests assigned to you, urgent changes and readings to fix."
            enableVibration(true)
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build(),
            )
        }

        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
