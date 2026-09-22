package com.pbh.autoclick.overlay

import android.content.Context
import android.view.WindowInsets
import android.view.WindowManager

/**
 * How much room an ordinary Overlay window has, as opposed to how large the display is (`OV-31`).
 *
 * The two are not the same and the difference is not cosmetic. A window laid out the default way
 * has its origin **below the status bar** and its bottom **above the navigation bar**, so on the
 * emulator this is 1344×2761 where [currentScreenProfile] reports 1344×2992. Placing the floating
 * control by the display's numbers puts it 159 pixels lower than intended and lets it be dragged
 * under the navigation bar.
 *
 * Marker windows do not use this: they are measured against the display on purpose, because the
 * point a Marker names is the point a Gesture will touch.
 */
data class OverlayBounds(
    val width: Int,
    val height: Int,
)

fun Context.overlayBounds(): OverlayBounds {
    val metrics = getSystemService(WindowManager::class.java).maximumWindowMetrics
    val bars = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
    return OverlayBounds(
        width = (metrics.bounds.width() - bars.left - bars.right).coerceAtLeast(1),
        height = (metrics.bounds.height() - bars.top - bars.bottom).coerceAtLeast(1),
    )
}
