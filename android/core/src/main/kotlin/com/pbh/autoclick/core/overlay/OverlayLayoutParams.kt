package com.pbh.autoclick.core.overlay

import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager

/**
 * The window attributes every Overlay window shares, and the two ways they differ (OV-1 to OV-3).
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
     * A small window the user interacts with: the floating control.
     *
     * [x] and [y] are where the user last left it (`OV-14`), as a `Gravity.TOP or Gravity.START`
     * offset so the value means the same thing on every screen size.
     */
    fun floating(
        x: Int = 0,
        y: Int = 0,
    ): WindowManager.LayoutParams =
        base().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.TOP or Gravity.START
            flags = NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE
            this.x = x
            this.y = y
        }

    /**
     * The full-screen Marker layer.
     *
     * [interactive] is the whole difference between the two things the user needs from it. While
     * placing Markers it must receive touches, and the application underneath is not being used.
     * The rest of the time the Markers are only a picture, and a full-screen window that consumed
     * touches would make the phone unusable with Auto Click open — so it takes none at all
     * (`OV-2`).
     */
    fun markerLayer(interactive: Boolean): WindowManager.LayoutParams =
        base().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.MATCH_PARENT
            gravity = Gravity.TOP or Gravity.START
            flags =
                if (interactive) {
                    NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE
                } else {
                    NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE or PASS_THROUGH_ENTIRELY
                }
        }

    /**
     * The Step panel (`OV-1`), anchored to the bottom edge where the thumb already is.
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
    fun stepPanel(typing: Boolean): WindowManager.LayoutParams =
        base().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.BOTTOM or Gravity.START
            flags = if (typing) PASS_THROUGH_OUTSIDE else NEVER_FOCUSABLE or PASS_THROUGH_OUTSIDE
        }

    private fun base(): WindowManager.LayoutParams =
        WindowManager.LayoutParams().apply {
            type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            format = PixelFormat.TRANSLUCENT
        }
}
