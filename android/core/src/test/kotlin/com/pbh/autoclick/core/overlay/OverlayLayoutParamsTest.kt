package com.pbh.autoclick.core.overlay

import android.view.Gravity
import android.view.WindowManager
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * OV-3 is the reason this file exists. The flag it checks has an innocent name and a consequence
 * three documents away, so it is asserted rather than trusted.
 */
class OverlayLayoutParamsTest {
    private fun WindowManager.LayoutParams.has(flag: Int) = flags and flag == flag

    @Test
    fun `no overlay window takes input focus`() {
        val windows =
            listOf(
                OverlayLayoutParams.floating(),
                OverlayLayoutParams.markerLayer(interactive = true),
                OverlayLayoutParams.markerLayer(interactive = false),
                OverlayLayoutParams.stepPanel(typing = false),
            )

        windows.forEach {
            assertTrue(
                it.has(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
                "an overlay that takes focus sends every setText Step into Auto Click",
            )
        }
    }

    @Test
    fun `the step panel is the one exception, and only while a field holds the caret`() {
        // OV-20. The exception is narrow on purpose and is written down twice — here, and in the
        // coordinator, which closes the panel before a run can start.
        assertTrue(
            !OverlayLayoutParams.stepPanel(typing = true).has(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
            "a window that cannot take focus cannot open a keyboard, and setText needs one",
        )
    }

    @Test
    fun `the step panel spans the bottom edge`() {
        val params = OverlayLayoutParams.stepPanel(typing = true)

        assertEquals(WindowManager.LayoutParams.MATCH_PARENT, params.width)
        assertEquals(WindowManager.LayoutParams.WRAP_CONTENT, params.height)
        assertEquals(Gravity.BOTTOM or Gravity.START, params.gravity)
    }

    @Test
    fun `every overlay window is an application overlay`() {
        assertEquals(
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            OverlayLayoutParams.floating().type,
        )
    }

    @Test
    fun `a touch outside the floating control reaches what is underneath`() {
        assertTrue(
            OverlayLayoutParams.floating().has(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL),
        )
    }

    @Test
    fun `the marker layer takes no touches at all unless it is being used`() {
        val watching = OverlayLayoutParams.markerLayer(interactive = false)
        val placing = OverlayLayoutParams.markerLayer(interactive = true)

        // Full screen and touchable would make the phone unusable with Auto Click open.
        assertTrue(watching.has(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE))
        assertTrue(!placing.has(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE))
    }

    @Test
    fun `the marker layer covers the screen and the control does not`() {
        assertEquals(
            WindowManager.LayoutParams.MATCH_PARENT,
            OverlayLayoutParams.markerLayer(interactive = true).width,
        )
        assertEquals(WindowManager.LayoutParams.WRAP_CONTENT, OverlayLayoutParams.floating().width)
    }

    @Test
    fun `the control remembers where it was left`() {
        val params = OverlayLayoutParams.floating(x = 120, y = 640)

        assertEquals(120, params.x)
        assertEquals(640, params.y)
    }
}
