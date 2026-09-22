package com.pbh.autoclick.overlay.ui

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.overlay.currentScreenProfile
import com.pbh.autoclick.overlay.overlayBounds
import kotlinx.coroutines.launch

/** How much of the display the sheet takes before it is dragged. */
private const val PEEK_FRACTION = 0.46f

/** The most it will ever take, leaving the control a row of its own above it. */
private const val FULL_FRACTION = 0.92f

/**
 * OV-34: the panel as a bottom sheet that is dragged open, then scrolled.
 *
 * Two phases, in this order, because that is what a sheet on this platform does and a user who has
 * used one other Android application already knows it:
 *
 *  1. **Drag to expand.** A swipe up grows the sheet towards [FULL_FRACTION]. The body does not
 *     move while there is still sheet to gain.
 *  2. **Scroll.** Once the sheet is as tall as it goes, the same continuing swipe scrolls the body.
 *     Swiping back down scrolls the body to its top first, and only then shrinks the sheet.
 *
 * The handoff is a [NestedScrollConnection] rather than two separate gestures, so one unbroken
 * finger movement crosses between them with nothing to re-grab.
 *
 * **The sheet is sized by the window, not by an offset inside it.** The obvious implementation —
 * a window covering the display with the sheet placed inside it — would take every touch on the
 * screen, and `OV-21` needs the opposite: Markers stay draggable while the panel is open, which is
 * the only way to place a swipe's destination while looking at the swipe's settings. So the window
 * stays `WRAP_CONTENT` and it is the *content* that changes height. Everything above the sheet
 * belongs to whatever is underneath.
 *
 * Dragging down does not dismiss. The sheet stops at its peek height and the header's own close
 * button is the way out — a Step being edited holds unsaved changes (`OV-24`), and a gesture that
 * threw them away by being slightly too long would be a gesture nobody could use confidently.
 */
@Composable
fun OverlayBottomSheet(
    header: @Composable () -> Unit,
    footer: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    body: @Composable ColumnScope.() -> Unit,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val displayHeight = remember(context) { context.currentScreenProfile().heightPixels.toFloat() }
    val bottomInset = remember(context) { context.overlayBounds().bottomInset }
    val state =
        remember(displayHeight) {
            OverlaySheetState(
                peekHeight = displayHeight * PEEK_FRACTION,
                fullHeight = displayHeight * FULL_FRACTION,
            )
        }
    val scope = rememberCoroutineScope()
    val scroll = rememberScrollState()
    val connection = remember(state) { state.nestedScroll() }

    OverlaySurface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        tone = MaterialTheme.colorScheme.surfaceContainer,
        // The panel is never glass. It holds text fields and a list of Steps, and the one thing
        // that must never be hard to read is the thing the user is editing.
        glass = false,
    ) {
        Column(
            modifier =
                Modifier
                    // The window sits on the bottom edge, which is where the keyboard opens. On
                    // API 30+ an overlay window receives IME insets while it holds focus, which it
                    // does exactly when a field here is being typed into (`OV-20`).
                    .imePadding()
                    .heightIn(max = with(density) { state.height.toDp() }),
        ) {
            Grabber(
                modifier =
                    Modifier.draggable(
                        state = rememberDraggableState { delta -> state.consume(delta) },
                        orientation = Orientation.Vertical,
                        onDragStopped = { scope.launch { state.settle() } },
                    ),
            )
            header()
            Column(
                modifier =
                    Modifier
                        .weight(weight = 1f, fill = false)
                        .nestedScroll(connection)
                        .verticalScroll(scroll)
                        .padding(horizontal = 16.dp),
                content = body,
            )
            // OV-32: the sheet owns the bottom of the **display**, so its own content is what
            // keeps Save and Cancel off the gesture bar. Before this the window stopped short and
            // a strip of the application underneath showed through below the sheet.
            Box(modifier = Modifier.padding(bottom = with(density) { bottomInset.toDp() })) { footer() }
        }
    }
}

/**
 * How tall the sheet is allowed to be, and where it settles when let go (`OV-34`).
 *
 * A maximum rather than a height. The content is measured against it and the window wraps whatever
 * that comes to, so a Step with two fields is a short sheet and dragging it does nothing visible —
 * which is right. There is no empty space to expand into, and a sheet that grew into some anyway
 * would be a large dark rectangle over the screen the user is trying to look at.
 */
@Stable
class OverlaySheetState(
    private val peekHeight: Float,
    private val fullHeight: Float,
) {
    var height by mutableFloatStateOf(peekHeight)
        private set

    /**
     * Applies a scroll delta and reports back how much of it was used.
     *
     * Signs follow Compose's scroll convention: a negative [deltaY] is the finger moving up, which
     * grows the sheet. Returning the amount used in the same convention is what lets this be the
     * return value of `onPreScroll` directly.
     */
    fun consume(deltaY: Float): Float {
        val settled = (height - deltaY).coerceIn(peekHeight, fullHeight)
        val used = height - settled
        height = settled
        return used
    }

    /** Snaps to whichever of the two heights is nearer, once the finger is off. */
    suspend fun settle() {
        val target = if (height > (peekHeight + fullHeight) / 2f) fullHeight else peekHeight
        animate(initialValue = height, targetValue = target, animationSpec = spring()) { value, _ -> height = value }
    }

    internal fun nestedScroll(): NestedScrollConnection =
        object : NestedScrollConnection {
            /** Phase 1: every upward pixel grows the sheet until there is no sheet left to gain. */
            override fun onPreScroll(
                available: Offset,
                source: NestedScrollSource,
            ): Offset = if (available.y < 0) Offset(0f, consume(available.y)) else Offset.Zero

            /** Phase 2, in reverse: the body scrolls to its top first, then the sheet shrinks. */
            override fun onPostScroll(
                consumed: Offset,
                available: Offset,
                source: NestedScrollSource,
            ): Offset = if (available.y > 0) Offset(0f, consume(available.y)) else Offset.Zero

            override suspend fun onPostFling(
                consumed: Velocity,
                available: Velocity,
            ): Velocity {
                settle()
                return Velocity.Zero
            }
        }
}

/** The grabber. It is the affordance that says the sheet moves at all. */
@Composable
private fun Grabber(modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier.fillMaxWidth().padding(vertical = 10.dp),
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(width = 36.dp, height = 4.dp),
            content = {},
        )
    }
}
