# The task names here are the ones CI runs (.github/workflows/android.yml). There are no product
# flavours in this build — an earlier version of this file called `assembleDevDebug` and
# `koverVerifyDevDebug`, which have never existed, so every target below was broken.
.PHONY: setup build test lint coverage format check

setup:
	./gradlew --version

build:
	./gradlew :app:assembleDebug

test:
	./gradlew test

lint:
	./gradlew detekt spotlessCheck

# Per module, against that module's own execution data — the root aggregate disagreed with CI
# while every per-module number matched. :app is excluded; see build.gradle.kts.
coverage:
	./gradlew :core:koverVerify :data:koverVerify :domain:koverVerify

format:
	./gradlew spotlessApply

# Tier 1 in one invocation, exactly as CI runs it. Run this before pushing.
check:
	./gradlew :app:assembleDebug test detekt spotlessCheck :core:koverVerify :data:koverVerify :domain:koverVerify
