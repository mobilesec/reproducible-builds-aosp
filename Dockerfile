FROM debian:stable AS builder

COPY "./scripts" "./scripts"
RUN apt-get update \
    && sh "./scripts/docker/setup/01_apt-installs.sh" \
    && sh "./scripts/docker/setup/02_pip-installs.sh" \
    && sh "./scripts/shared/setup/03_install-repo.sh" \
    && sh "./scripts/shared/setup/04_config-git.sh" \
    && rm -rf "/var/lib/apt/lists/*"

CMD /bin/bash -c ". \"./scripts/docker/setup-runtime/01_set-runtime-path.sh\"; bash \"./scripts/shared/build-device/10_clone-src-device.sh\" \"android-10.0.0_r11\"; bash \"./scripts/shared/build-device/11_fetch-extract-vendor.sh\" \"QP1A.191105.004\" \"crosshatch\"; bash \"./scripts/shared/build-device/12_build-device.sh\" \"android-10.0.0_r11\" \"aosp_crosshatch-user\" \"crosshatch\"; bash \"./scripts/shared/build-device/13_fetch-extract-factory-images.sh\" \"android-10.0.0_r11\" \"QP1A.191105.004\" \"crosshatch\"; bash \"./scripts/docker/analysis/21_diffoscope-files.sh\" \"/root/aosp/build/android-10.0.0_r11/crosshatch-user/Google\" \"/root/aosp/build/android-10.0.0_r11/aosp_crosshatch-user/Debian10\" \"/root/aosp/diff/android-10.0.0_r11_crosshatch-user_Google__android-10.0.0_r11_aosp_crosshatch-user_Debian10\"; bash"
