FROM debian:stable AS builder

COPY "./scripts" "./scripts"
RUN apt-get update \
    && sh "./scripts/shared/setup/01_apt-installs.sh" \
    && sh "./scripts/shared/setup/02_install-repo.sh" \
    && sh "./scripts/shared/setup/03_config-git.sh" \
    && sh "./scripts/shared/setup/04_config-profile-for-docker.sh" \
    && rm -rf "/var/lib/apt/lists/*"

CMD bash
