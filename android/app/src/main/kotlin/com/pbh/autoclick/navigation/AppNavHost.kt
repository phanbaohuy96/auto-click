package com.pbh.autoclick.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.pbh.autoclick.feature.scenario.navigation.ScenarioListRoute
import com.pbh.autoclick.feature.scenario.ui.ScenarioListScreen

/**
 * Root navigation host for the Activity surface.
 *
 * The Activity is the **smaller** of the app's two surfaces: it manages Scenarios, reorders Steps
 * and carries onboarding. Authoring and running happen in the Overlay, which is not an Activity and
 * so is not reachable from here — see [ADR-0015].
 */
@Composable
fun AppNavHost() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = ScenarioListRoute,
    ) {
        composable<ScenarioListRoute> { ScenarioListScreen() }
    }
}
