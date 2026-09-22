package com.pbh.autoclick.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.pbh.autoclick.R

/** Low importance: this notification is a handle to reach for, not news to be told. */
private const val CHANNEL_ID = "auto-click-run"

fun Context.createRunNotificationChannel() {
    val channel =
        NotificationChannel(
            CHANNEL_ID,
            getString(R.string.run_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
    getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
}

/**
 * The notification a run lives behind (`GX-7`).
 *
 * Ongoing and unswipeable on purpose: something driving the phone by itself should never be
 * invisible, and this is the one surface that survives the Overlay being unreachable.
 */
fun Context.buildRunNotification(): Notification =
    Notification
        .Builder(this, CHANNEL_ID)
        .setContentTitle(getString(R.string.run_notification_title))
        .setSmallIcon(android.R.drawable.ic_menu_manage)
        .setOngoing(true)
        // OV-15, GX-12: both actions are here as well as on the control, because a latched touch
        // is exactly the situation in which the control cannot be tapped.
        .addAction(serviceAction(OverlayService.ACTION_STOP, R.string.overlay_stop))
        .addAction(serviceAction(OverlayService.ACTION_FREE_TOUCH, R.string.overlay_free_the_touch))
        .build()

private fun Context.serviceAction(
    action: String,
    label: Int,
): Notification.Action =
    Notification.Action
        .Builder(
            null,
            getString(label),
            PendingIntent.getService(
                this,
                action.hashCode(),
                Intent(this, OverlayService::class.java).setAction(action),
                PendingIntent.FLAG_IMMUTABLE,
            ),
        ).build()
