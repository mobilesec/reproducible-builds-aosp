FROM debian:stable AS builder

COPY "./scripts" "./scripts"
RUN apt-get update \
    && sh "./scripts/shared/setup/01_apt-installs.sh" \
    && sh "./scripts/shared/setup/02_pip-installs.sh" \
    && sh "./scripts/shared/setup/03_install-repo.sh" \
    && sh "./scripts/shared/setup/04_install-simg2img-from-source.sh" \
    && sh "./scripts/shared/setup/05_config-git.sh" \
    && sh "./scripts/shared/setup/06_config-profile.sh" \
    && rm -rf "/var/lib/apt/lists/*"

CMD bash
