package com.pbh.autoclick

import android.app.Application
import com.pbh.autoclick.core.designsystem.preloadFonts
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Application entry point: Hilt, and the one thing that has to happen before anything is drawn. */
@HiltAndroidApp
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // DS-1: the first composition that needs a bundled font reads it off disk on the thread it
        // is composing on. That thread, for the floating control, is the one between the user
        // leaving the app and seeing anything at all — and on the emulator it was seconds.
        CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
            runCatching { preloadFonts(this@MainApplication) }
        }
    }
}
