FROM ubuntu:18.04

LABEL maintainer="Andres Rios"

ARG ANDROID_SDK_TOOLS_VERSION=4333796
ARG ANDROID_BUILD_TOOL=29.0.3
ARG ANDROID_VERSION=10.0
ARG API_LEVEL=29
ARG SYS_IMG=x86
ARG IMG_TYPE=google_apis
ARG GRADLE_VERSION=5.6.4

ENV ANDROID_HOME="/opt/android-sdk" \
    FLUTTER_HOME="/opt/flutter" \
    JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/" \
    GRADLE_HOME="/opt/gradle"

# Get the latest version from https://developer.android.com/studio/index.html or default version 4333796
ENV ANDROID_SDK_TOOLS_VERSION=$ANDROID_SDK_TOOLS_VERSION \
    ANDROID_VERSION=$ANDROID_VERSION \
    API_LEVEL=$API_LEVEL \
    SYS_IMG=$SYS_IMG \
    IMG_TYPE=$IMG_TYPE

# nodejs version
ENV NODE_VERSION="12.x"

# root
ENV ROOT="/root"

# Device
ENV DEVICE='Samsung Galaxy s20 Ultra' \
    SKIN_NAME="samsung_galaxy_s20_ultra" \
    AVD_PATH="${ROOT}/android_emulator" \
    SKIN_PATH="${ROOT}/devices/skins/${SKIN_NAME}" \
    PROFILE_PATH="${ROOT}/devices/profiles"

RUN apt-get clean \
 && apt-get update -qq \
 && apt-get install -qq -y apt-utils
ENV DEBIAN_FRONTEND="noninteractive" \
    TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME" \
    ANDROID_SDK_ROOT="$ANDROID_HOME"

ENV PATH="$PATH:${ANDROID_SDK_HOME}/emulator:${ANDROID_SDK_HOME}/tools/bin:${ANDROID_SDK_HOME}/tools:${ANDROID_SDK_HOME}/platform-tools:${GRADLE_HOME}/bin"

WORKDIR /tmp

# Installing packages
RUN apt-get update -qq > /dev/null \
 && apt-get install -qq locales > /dev/null \
 && locale-gen "$LANG" > /dev/null \
 && apt-get install -qq --no-install-recommends \
        autoconf \
        build-essential \
        curl \
        file \
        git \
        gpg-agent \
        openjdk-8-jdk \
        openssh-client \
        pkg-config \
        ruby-full \
        software-properties-common \
        tzdata \
        unzip \
        vim-tiny \
        wget \
        zip \
        zlib1g-dev > /dev/null \
 && ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime \
 && echo "Installing nodejs, npm, appium, appium doctor" \
 && curl -sL -k https://deb.nodesource.com/setup_${NODE_VERSION} \
        | bash - > /dev/null \
 && apt-get install -qq nodejs > /dev/null \
 && apt-get clean > /dev/null \
 && curl -sS -k https://dl.yarnpkg.com/debian/pubkey.gpg \
        | apt-key add - > /dev/null \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" \
        | tee /etc/apt/sources.list.d/yarn.list > /dev/null \
 && apt-get update -qq > /dev/null \
 && apt-get install -qq yarn > /dev/null \
 && rm -rf /var/lib/apt/lists/ \
 && npm install --quiet -g npm > /dev/null \
 && npm install --quiet -g \
        appium --unsafe-perm=true --allow-root \
        appium-doctor --unsafe-perm=true --allow-root > /dev/null \
 && npm cache clean --force > /dev/null \
 && rm -rf /tmp/* /var/tmp/*

# Install Android SDK
RUN echo "Installing sdk tools ${ANDROID_SDK_TOOLS_VERSION}" \
 && wget --quiet --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip" \
 && mkdir --parents "${ANDROID_HOME}" \
 && unzip -q sdk-tools.zip -d "${ANDROID_HOME}" \
 && rm --force sdk-tools.zip

# Install SDKs
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "${ANDROID_HOME}/.android/" \
 && echo '### User Sources for Android SDK Manager' > \
        "${ANDROID_HOME}/.android/repositories.cfg" \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager --licenses > /dev/null

RUN echo "Installing platform platforms;android-${API_LEVEL}" \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager \
          "platforms;android-${API_LEVEL}" > /dev/null

RUN echo "Installing platform tools" \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager \
        "platform-tools" > /dev/null

RUN echo "Installing build tool " \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager \
          "build-tools;${ANDROID_BUILD_TOOL}" > /dev/null

RUN echo "Installing emulator" \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager "emulator" > /dev/null

RUN echo "Download system image to create an emulator" \
 && yes | "${ANDROID_HOME}"/tools/bin/sdkmanager "system-images;android-${API_LEVEL};${IMG_TYPE};${SYS_IMG}"

# Add Emulator Devices
COPY devices "${ROOT}/devices"

RUN echo "Create an AVD emulator with custom hardware profile" \
 && ln -sf "${PROFILE_PATH}/${SKIN_NAME}.xml" "${ANDROID_HOME}/.android/devices.xml" \
 && avdmanager create avd \
        -n Test_Emulator \
        -b "${IMG_TYPE}/${SYS_IMG}" \
        -k "system-images;android-${API_LEVEL};${IMG_TYPE};${SYS_IMG}" \
        -c 100M \
        --force \
        -d "${DEVICE}" \
        -p "${AVD_PATH}"

RUN echo "Editing config file" \
 && sed -i "s#image.sysdir.1.*#image.sysdir.1 = ${ANDROID_HOME}/system-images/android-${API_LEVEL}/${IMG_TYPE}/${SYS_IMG}/#" "${AVD_PATH}/config.ini" \
 && echo "hw.ramSize = 1024M" >> "${AVD_PATH}/config.ini" \
 && echo "skin.path = ${SKIN_PATH}" >> "${AVD_PATH}/config.ini"

# RUN echo "Install Flutter sdk" \
#  && cd /opt \
#  && wget --quiet https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_1.17.1-stable.tar.xz -O flutter.tar.xz \
#  && tar xf flutter.tar.xz \
#  && flutter config --no-analytics \
#  && flutter upgrade \
#  && rm -f flutter.tar.xz

RUN echo "Installing gradle" \
 && wget --quiet --output-document=gradle.zip \
        "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip" \
 && unzip -q gradle.zip -d "/opt/" \
 && rm --force gradle.zip \
 && mv "/opt/gradle-${GRADLE_VERSION}" ${GRADLE_HOME}

# RUN echo "Installing kotlin" \
#  && wget --quiet -O sdk.install.sh "https://get.sdkman.io" \
#  && bash -c "bash ./sdk.install.sh > /dev/null && source ~/.sdkman/bin/sdkman-init.sh && sdk install kotlin" \
#  && rm -f sdk.install.sh

# Create some jenkins required directory to allow this image run with Jenkins
# RUN mkdir -p /var/lib/jenkins/workspace \
#  && mkdir -p /home/jenkins \
#  && chmod 777 /home/jenkins \
#  && chmod 777 /var/lib/jenkins/workspace \
#  && chmod 777 ${ANDROID_HOME}/.android

# Install fastlane
RUN echo "Installing fastlane" \
 && gem install fastlane --quiet --no-document > /dev/null

ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8

# Expose Ports
# 4723 Appium port
# 5554 Emulator port
# 5555 ADB connection port
#===============
EXPOSE 4723 5554 5555