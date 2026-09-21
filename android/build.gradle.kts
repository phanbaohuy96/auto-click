import com.diffplug.gradle.spotless.SpotlessExtension
import io.gitlab.arturbosch.detekt.Detekt
import io.gitlab.arturbosch.detekt.extensions.DetektExtension
import kotlinx.kover.gradle.plugin.dsl.AggregationType
import kotlinx.kover.gradle.plugin.dsl.CoverageUnit
import kotlinx.kover.gradle.plugin.dsl.KoverProjectExtension

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.detekt)
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.kover)
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.spotless)
}

val kotlinVersion = libs.versions.kotlin.get()

extensions.configure<SpotlessExtension>("spotless") {
    kotlinGradle {
        target("*.gradle.kts", "gradle/*.gradle.kts")
        ktlint(libs.versions.ktlint.get())
    }
}

subprojects {
    apply(plugin = "com.diffplug.spotless")
    apply(plugin = "io.gitlab.arturbosch.detekt")
    apply(plugin = "org.jetbrains.kotlinx.kover")

    extensions.configure<DetektExtension>("detekt") {
        buildUponDefaultConfig = true
        config.setFrom(rootProject.files("detekt.yml"))
    }

    configurations.configureEach {
        if (
            name.endsWith("CompileClasspath") ||
            name.endsWith("RuntimeClasspath") ||
            name.contains("UnitTest") ||
            name.startsWith("ksp")
        ) {
            resolutionStrategy.force(
                "org.jetbrains.kotlin:kotlin-stdlib:$kotlinVersion",
                "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion",
                "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlinVersion",
            )
        }
    }

    extensions.configure<SpotlessExtension>("spotless") {
        kotlin {
            target("src/**/*.kt")
            targetExclude("**/build/**", "**/generated/**")
            ktlint(libs.versions.ktlint.get())
        }
        kotlinGradle {
            target("*.gradle.kts")
            ktlint(libs.versions.ktlint.get())
        }
    }

    tasks.withType<Detekt>().configureEach {
        exclude("**/build/**", "**/generated/**")
    }
}

dependencies {
    kover(project(":app"))
    kover(project(":core"))
    kover(project(":domain"))
}

extensions.configure<KoverProjectExtension>("kover") {
    reports {
        total {
            filters {
                includes {
                    classes(
                        "com.pbh.autoclick.core.network.NetworkErrorMapper",
                        "com.pbh.autoclick.core.ui.UiText*",
                        "com.pbh.autoclick.domain.entity.*",
                        "com.pbh.autoclick.domain.model.*",
                        "com.pbh.autoclick.domain.usecase.*UseCase",
                        "com.pbh.autoclick.feature.auth.ui.LoginEffect*",
                        "com.pbh.autoclick.feature.auth.ui.LoginUiState*",
                        "com.pbh.autoclick.feature.auth.ui.LoginViewModel*",
                        "com.pbh.autoclick.feature.home.ui.detail.ItemDetailUiState*",
                        "com.pbh.autoclick.feature.home.ui.detail.ItemDetailViewModel*",
                        "com.pbh.autoclick.feature.home.ui.list.HomeListEffect*",
                        "com.pbh.autoclick.feature.home.ui.list.HomeListUiState*",
                        "com.pbh.autoclick.feature.home.ui.list.HomeViewModel*",
                    )
                }
                excludes {
                    classes(
                        "*.BuildConfig",
                        "*.R",
                        "*.R\$*",
                        "*ComposableSingletons*",
                        "*Hilt_*",
                        "*_Factory",
                        "*_HiltModules*",
                        "com.pbh.autoclick.core.common.*",
                        "com.pbh.autoclick.core.designsystem.AppTheme",
                        "com.pbh.autoclick.core.designsystem.AppThemeKt",
                        "com.pbh.autoclick.core.designsystem.components.*",
                        "com.pbh.autoclick.core.network.ApiResponse*",
                        "com.pbh.autoclick.core.network.RetrofitFactory",
                        "*ScreenKt*",
                    )
                }
            }
            verify {
                rule("Line coverage must stay at or above 80% for app logic") {
                    minBound(80, CoverageUnit.LINE, AggregationType.COVERED_PERCENTAGE)
                }
            }
        }
    }
}
