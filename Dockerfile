# CI image for this project's GitLab pipelines (ci/*.yml).
# Built and pushed manually (no CI job for this - see below), currently to
# ghcr.io/andrey-shikhov/android-ci:main, which is what ci/*.yml `image:` lines pull.
#
# Pushing to this project's own GitLab Container Registry (registry.snmtech.net) does
# not currently work for either CI job tokens (registry rejects manifest pushes) or
# personal access tokens (registry auth silently downgrades any personal_access_token-
# issued JWT to pull-only, regardless of granted permissions) - see admin request notes.
#
# Scope is deliberately narrow to what this repo's build actually needs (see CLAUDE.md):
# JDK 17 only, Android SDK platform/build-tools matching COMPILE_SDK (gradle.properties),
# and the exact Gradle wrapper distribution (gradle/wrapper/gradle-wrapper.properties)
# pre-extracted so `./gradlew` never has to download it in a job.
FROM eclipse-temurin:17-jdk-jammy

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    ANDROID_HOME=/opt/android/sdk \
    ANDROID_SDK_ROOT=/opt/android/sdk \
    GRADLE_USER_HOME=/opt/gradle-cache \
    PATH=/opt/android/sdk/cmdline-tools/latest/bin:/opt/android/sdk/platform-tools:${PATH}

# git: buildSrc/src/main/kotlin/versions.gradle.kts shells out to `git log` for versioning.
# curl/jq/zip/unzip: used across ci/*.yml scripts. openssh-client: used by deploy*.yml.
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
      git curl wget unzip zip jq openssh-client locales ca-certificates && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Android SDK: only the pieces this project builds against ---
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
# ANDROID_PLATFORM mirrors COMPILE_SDK+COMPILE_SDK_MINOR (gradle.properties) as Google's exact
# platform package suffix. Google's newer quarterly platform revisions are dotted
# ("platforms;android-37.0"), while some older ones are still bare ("platforms;android-36") -
# don't assume a "<major>.<minor>" pattern always applies; check the actual package id in
# `sdkmanager --list` (or the IDE SDK Manager) before bumping this.
ARG ANDROID_PLATFORM=37.0
ARG ANDROID_BUILD_TOOLS=37.0.0
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" && \
    curl -fsSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" && \
    unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools" && \
    mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" && \
    rm /tmp/cmdline-tools.zip && \
    mkdir -p ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg && \
    yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses > /dev/null && \
    sdkmanager --sdk_root="${ANDROID_HOME}" --install \
      "platform-tools" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "platforms;android-${ANDROID_PLATFORM}" > /dev/null

# --- Pre-warm the Gradle wrapper cache (avoids the ~2min distribution download seen in every job) ---
# Bump this image whenever gradle/wrapper/gradle-wrapper.properties changes distributionUrl.
WORKDIR /tmp/warm
COPY gradlew ./
COPY gradle/wrapper/gradle-wrapper.jar gradle/wrapper/gradle-wrapper.properties gradle/wrapper/
RUN chmod +x gradlew && ./gradlew --version && cd / && rm -rf /tmp/warm

WORKDIR /builds
