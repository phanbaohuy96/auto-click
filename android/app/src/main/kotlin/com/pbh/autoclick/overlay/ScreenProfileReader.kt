package com.pbh.autoclick.overlay

import android.content.Context
import android.view.Surface
import android.view.WindowManager
import com.pbh.autoclick.domain.scenario.ScreenProfile
import com.pbh.autoclick.domain.scenario.ScreenRotation

/**
 * The Screen profile in force right now (SM-13).
 *
 * Uses the **full** window metrics rather than the bounds left over after insets: a Gesture reaches
 * the whole display, including whatever a navigation bar is sitting on, so a coordinate has to mean
 * something there too.
 */
fun Context.currentScreenProfile(): ScreenProfile {
    val windowManager = getSystemService(WindowManager::class.java)
    val bounds = windowManager.maximumWindowMetrics.bounds
    val display = display
    return ScreenProfile(
        widthPixels = bounds.width(),
        heightPixels = bounds.height(),
        densityDpi = resources.configuration.densityDpi,
        rotation =
            when (display?.rotation) {
                Surface.ROTATION_90 -> ScreenRotation.LANDSCAPE_LEFT
                Surface.ROTATION_180 -> ScreenRotation.PORTRAIT_UPSIDE_DOWN
                Surface.ROTATION_270 -> ScreenRotation.LANDSCAPE_RIGHT
                else -> ScreenRotation.PORTRAIT
            },
    )
}
