FROM debian:stable AS builder

COPY ./scripts ./scripts
RUN apt-get update \
    && sh "./scripts/docker/setup/01_apt-installs.sh" \
    && sh "./scripts/docker/setup/02_pip-installs.sh" \
    && sh "./scripts/shared/setup/03_install-repo.sh" \
    && sh "./scripts/shared/setup/04_config-git.sh" \
    && rm -rf "/var/lib/apt/lists/*"

CMD "bash"