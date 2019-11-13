FROM debian:stable AS builder

COPY "./scripts" "./scripts"
RUN apt-get update \
    && sh "./scripts/docker/setup/01_apt-installs.sh" \
    && sh "./scripts/docker/setup/02_pip-installs.sh" \
    && sh "./scripts/shared/setup/03_install-repo.sh" \
    && sh "./scripts/shared/setup/04_config-git.sh" \
    && rm -rf "/var/lib/apt/lists/*"

COPY "${HOME}/aosp/src" "${HOME}/aosp/src"

CMD sh "./scripts/shared/build-device/10_clone-src-device.sh" "android-10.0.0_r11" \
    && sh "./scripts/shared/build-device/11_fetch-extract-vendor.sh" "QP1A.191105.004" "crosshatch" \
    && sh "./scripts/shared/build-device/12_build-device.sh" "android-10.0.0_r11" "aosp_crosshatch-user" "crosshatch" \
    && sh "./scripts/shared/build-device/13_fetch-extract-factory-images.sh" "android-10.0.0_r11" "QP1A.191105.004" "crosshatch" \
    && bash
