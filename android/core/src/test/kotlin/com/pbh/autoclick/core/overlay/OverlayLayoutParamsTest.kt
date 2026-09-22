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
                OverlayLayoutParams.markerHandle(x = 10, y = 10),
                OverlayLayoutParams.markerLines(1_344, 2_992),
                OverlayLayoutParams.panel(typing = false),
            )

        windows.forEach {
            assertTrue(
                it.has(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
                "an overlay that takes focus sends every setText Step into Auto Click",
            )
        }
    }

    @Test
    fun `the panel is the one exception, and only while a field holds the caret`() {
        // OV-20. The exception is narrow on purpose and is written down twice — here, and in the
        // coordinator, which closes the panel before a run can start.
        assertTrue(
            !OverlayLayoutParams.panel(typing = true).has(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE),
            "a window that cannot take focus cannot open a keyboard, and setText needs one",
        )
    }

    @Test
    fun `the panel spans the bottom edge`() {
        val params = OverlayLayoutParams.panel(typing = true)

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

    /**
     * OV-27. A Marker handle is a window of its own so that it can answer touches without the
     * whole screen having to, and the full-screen layer left over draws only.
     */
    @Test
    fun `a marker handle answers touches and the layer behind it never does`() {
        val handle = OverlayLayoutParams.markerHandle(x = 0, y = 0)
        val lines = OverlayLayoutParams.markerLines(1_344, 2_992)

        assertTrue(!handle.has(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE))
        assertTrue(handle.has(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL))
        assertTrue(lines.has(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE))
    }

    @Test
    fun `a marker handle is only as big as itself, and the line layer covers the display`() {
        assertEquals(WindowManager.LayoutParams.WRAP_CONTENT, OverlayLayoutParams.markerHandle(0, 0).width)
        assertEquals(1_344, OverlayLayoutParams.markerLines(1_344, 2_992).width)
        assertEquals(2_992, OverlayLayoutParams.markerLines(1_344, 2_992).height)
        assertEquals(WindowManager.LayoutParams.WRAP_CONTENT, OverlayLayoutParams.floating().width)
    }

    /**
     * OV-31, and the reason it is asserted rather than trusted: without these flags a window's
     * origin is below the status bar, so a Marker at y = 1496 is drawn at 1655 while the Gesture
     * it describes still lands at 1496. The Marker is what the user aims with.
     */
    @Test
    fun `marker windows are measured against the display, and the control is not`() {
        val handle = OverlayLayoutParams.markerHandle(x = 0, y = 0)
        val lines = OverlayLayoutParams.markerLines(1_344, 2_992)

        listOf(handle, lines).forEach {
            assertTrue(it.has(WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN))
            assertTrue(it.has(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS))
        }
        // The control and the panel are reached for rather than aimed with, and are better off
        // inside the system bars where nothing covers them.
        assertTrue(!OverlayLayoutParams.floating().has(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS))
        assertTrue(!OverlayLayoutParams.panel(typing = false).has(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS))
    }

    @Test
    fun `a marker handle sits where its marker is`() {
        val params = OverlayLayoutParams.markerHandle(x = 540, y = 1_820)

        assertEquals(540, params.x)
        assertEquals(1_820, params.y)
        assertEquals(Gravity.TOP or Gravity.START, params.gravity)
    }

    @Test
    fun `the control remembers where it was left`() {
        val params = OverlayLayoutParams.floating(x = 120, y = 640)

        assertEquals(120, params.x)
        assertEquals(640, params.y)
    }
}
