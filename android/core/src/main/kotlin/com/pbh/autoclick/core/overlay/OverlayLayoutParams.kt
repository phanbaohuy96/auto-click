package com.pbh.autoclick.core.overlay

import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager

/**
 * The window attributes every Overlay window shares, and the ways they differ (OV-1 to OV-3).
 *
 * Built here rather than at each call site because one of these flags is load-bearing in a way
 * that is not obvious from its name — see [NEVER_FOCUSABLE].
 */
object OverlayLayoutParams {
    /**
     * OV-3. **Never remove this flag.**
     *
     * `setText` finds its field with `findFocus(FOCUS_INPUT)` (`GX-17`). An Overlay that can take
     * input focus therefore makes every `setText` Step write into Auto Click instead of the
     * application being automated — and the failure looks like the other application's fault.
     */
    const val NEVER_FOCUSABLE = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

    /** OV-2: a touch outside this window's bounds reaches whatever is underneath. */
    private const val PASS_THROUGH_OUTSIDE = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL

    /** Every touch passes through, including ones inside the bounds. For a window that only draws. */
    private const val PASS_THROUGH_ENTIRELY = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE

    /**
     * OV-31: measured against the display, not against what is left of it.
     *
     * By default a window is laid out inside the system bars, so its origin is below the status
     * bar and a y of 1496 lands at 1655 on a phone with a 159-pixel one. A **Gesture** is
     * dispatched in display coordinates, so a Marker placed that way is drawn six millimetres
     * below the point it claims to name (`SM-11`) — and the user aims by the Marker.
     *
     * This applies to the Marker windows alone. The control and the panel are things the user
     * reaches for rather than aims with, and they are better off inside the bars where nothing
     * covers them.
     */
    private const val IN_DISPLAY_COORDINATES =
        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    /**
     * A small window the user interacts with: the floating control.
     *
     * [x] and [y] are where the user last left it (`OV-14`), as a `Gravity.TOP or Gravity.START`
     * offset so the value means the same thing on every screen size.
     */
    fun floating(
        x: Int = 0,
        y: Int = 0,
    ): WindowManager.LayoutParams = positioned(x, y)

    /**
     * OV-27: one Marker's handle, as a window of its own.
     *
     * The reason this is not a region of one full-screen window is that Android has no public way
     * to say "this window is touchable **here** and nowhere else". A full-screen window either
     * takes every touch — which makes the phone unusable while Auto Click is open — or takes none,
     * which is why placing Markers used to be a mode the user had to remember to leave. A window
     * per Marker is the only shape that gives both: each handle answers touches inside its own few
     * dozen pixels, and `FLAG_NOT_TOUCH_MODAL` sends everything else to the application
     * underneath.
     *
     * The cost is real and bounded: one window per drawn Marker, which is one per tap, two per
     * swipe, and up to two per contact of a multi-touch.
     */
    fun markerHandle(
        x: Int,
        y: Int,
    ): WindowManager.LayoutParams =
        positioned(x, y).apply {
            flags = flags or IN_DISPLAY_COORDINATES
        }

    /**
     * The display-sized layer the lines between paired Markers are drawn on (OV-8, OV-9, OV-31).
     *
     * Draws and nothing else. It is the handles that answer touches, so this one is
     * [PASS_THROUGH_ENTIRELY] at all times and can safely cover the whole screen.
     */
    fun markerLines(
        displayWidth: Int,
        displayHeight: Int,
    ): WindowManager.LayoutParams =
        base().apply {
            // Sized explicitly rather than MATCH_PARENT. The parent of an overlay window is the
            // space inside the system bars even when the window itself is laid out in display
            // coordinates, so MATCH_PARENT would start this layer below the status bar and draw
            // every line at the wrong end of every Marker.
            width = displayWidth
            height = displayHeight
            x = 0
            y = 0
            gravity = Gravity.TOP or Gravity.START
            flags = NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE or PASS_THROUGH_ENTIRELY or IN_DISPLAY_COORDINATES
        }

    /**
     * The panel (`OV-1`), anchored to the bottom edge where the thumb already is.
     *
     * [typing] is the **one** place in this application where [NEVER_FOCUSABLE] is dropped,
     * and `OV-20` is the requirement that says why it may be. A `setText` Step's string has to be
     * typed somewhere, and a window that cannot take input focus cannot open a keyboard — so the
     * flag goes while a text field in the panel holds the caret, and comes straight back when it
     * does not.
     *
     * What makes that safe is not this function but when it is called: the panel is closed before
     * a run can start, so the window `findFocus(FOCUS_INPUT)` would find during a `setText` Step
     * is never this one. `OverlayCoordinator` is where that is enforced.
     */
    fun panel(typing: Boolean): WindowManager.LayoutParams =
        base().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.BOTTOM or Gravity.START
            flags = if (typing) PASS_THROUGH_OUTSIDE else NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE
        }

    private fun positioned(
        x: Int,
        y: Int,
    ): WindowManager.LayoutParams =
        base().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.TOP or Gravity.START
            flags = NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE
            this.x = x
            this.y = y
        }

    private fun base(): WindowManager.LayoutParams =
        WindowManager.LayoutParams().apply {
            type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            format = PixelFormat.TRANSLUCENT
        }
}
