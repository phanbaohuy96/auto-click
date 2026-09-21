package com.pbh.autoclick.data.di

import android.content.Context
import com.pbh.autoclick.core.common.DispatcherProvider
import com.pbh.autoclick.data.scenario.FileScenarioStore
import com.pbh.autoclick.domain.repository.ScenarioRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.io.File
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object StorageModule {
    /** FS-1: internal storage, so nothing else on the phone can read a Scenario. */
    @Provides
    @Singleton
    fun provideScenarioStore(
        @ApplicationContext context: Context,
        dispatchers: DispatcherProvider,
    ): FileScenarioStore = FileScenarioStore(File(context.filesDir, SCENARIOS_DIRECTORY), dispatchers)

    @Provides
    @Singleton
    fun provideScenarioRepository(store: FileScenarioStore): ScenarioRepository = store

    private const val SCENARIOS_DIRECTORY = "scenarios"
}
