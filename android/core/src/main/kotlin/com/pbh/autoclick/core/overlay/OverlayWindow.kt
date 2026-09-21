package com.pbh.autoclick.core.overlay

import android.content.Context
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

/**
 * One Compose window attached to [WindowManager], with the three owners Compose refuses to run
 * without ([ADR-0015]).
 *
 * This is the class ADR-0015 says must be written once and never re-implemented per feature,
 * because getting it wrong leaks a `ViewModelStore` every time the floating control opens — which
 * is many times an hour. [dismiss] clears it, and `OV-19` is the test that says so.
 *
 * Reusable: [show] after [dismiss] builds fresh owners, because a `LifecycleRegistry` that has
 * reached `DESTROYED` cannot be driven back to `RESUMED`.
 */
class OverlayWindow(
    private val context: Context,
    private val windowManager: WindowManager,
) : LifecycleOwner,
    ViewModelStoreOwner,
    SavedStateRegistryOwner {
    private var lifecycleRegistry = LifecycleRegistry(this)
    private var savedStateController = SavedStateRegistryController.create(this)
    private var composeView: ComposeView? = null

    override val viewModelStore: ViewModelStore = ViewModelStore()

    override val lifecycle: Lifecycle get() = lifecycleRegistry

    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry

    val isShowing: Boolean get() = composeView != null

    /** Attaches the window. Calling this while already showing only updates [params]. */
    fun show(
        params: WindowManager.LayoutParams,
        content: @Composable () -> Unit,
    ) {
        composeView?.let {
            windowManager.updateViewLayout(it, params)
            return
        }

        lifecycleRegistry = LifecycleRegistry(this)
        savedStateController = SavedStateRegistryController.create(this)
        savedStateController.performRestore(null)

        val view =
            ComposeView(context).apply {
                setViewTreeLifecycleOwner(this@OverlayWindow)
                setViewTreeViewModelStoreOwner(this@OverlayWindow)
                setViewTreeSavedStateRegistryOwner(this@OverlayWindow)
                setContent(content)
            }

        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        windowManager.addView(view, params)
        composeView = view
    }

    /** Moves an already-attached window without rebuilding it (`OV-14`). */
    fun move(params: WindowManager.LayoutParams) {
        composeView?.let { windowManager.updateViewLayout(it, params) }
    }

    /**
     * Detaches the window and releases everything it owns (`OV-4`, `OV-18`).
     *
     * Safe to call when nothing is showing, and safe to call twice — both happen on the paths that
     * are already going wrong, which are the paths that most need this to work.
     */
    fun dismiss() {
        val view = composeView ?: return
        composeView = null

        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        view.disposeComposition()
        runCatching { windowManager.removeView(view) }
        viewModelStore.clear()
    }
}
