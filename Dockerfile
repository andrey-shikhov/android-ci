FROM eclipse-temurin:17-jdk-jammy

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    ANDROID_HOME=/opt/android/sdk \
    ANDROID_SDK_ROOT=/opt/android/sdk \
    GRADLE_USER_HOME=/opt/gradle-cache \
    PATH=/opt/android/sdk/cmdline-tools/latest/bin:/opt/android/sdk/platform-tools:${PATH}

RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
      git curl wget unzip zip jq openssh-client locales ca-certificates && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_API=36
ARG ANDROID_BUILD_TOOLS=36.0.0
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
      "platforms;android-${ANDROID_API}" > /dev/null

# --- Pre-warm the Gradle wrapper cache (avoids the ~2min distribution download seen in every job) ---
# Bump this image whenever gradle/wrapper/gradle-wrapper.properties changes distributionUrl.
WORKDIR /tmp/warm
COPY gradlew ./
COPY gradle/wrapper/gradle-wrapper.jar gradle/wrapper/gradle-wrapper.properties gradle/wrapper/
RUN chmod +x gradlew && ./gradlew --version && cd / && rm -rf /tmp/warm

WORKDIR /builds
