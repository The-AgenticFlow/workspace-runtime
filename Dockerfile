FROM python:3.12-alpine@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89 AS role-assets
ARG ROLE
COPY .version /tmp/source/.version
COPY roles /tmp/source/roles
COPY shared /tmp/source/shared
COPY scripts/package_role.py /tmp/source/package_role.py
RUN python3 /tmp/source/package_role.py --role "$ROLE" --source /tmp/source --output /tmp/role-assets

# Coder runs its agent through the template's init script; the workspace image
# only needs the tools used by that script and by OpenFlows.
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS runtime
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git jq python3 sudo \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --gid 1000 coder \
    && useradd --uid 1000 --gid coder --create-home --shell /bin/bash coder \
    && printf '%s\n' 'coder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && mkdir -p /home/coder/workspace /home/coder/.openflows \
    && chown -R coder:coder /home/coder

ARG TARGETARCH
ARG OPENFLOWS_VERSION=1.8.2
ARG HARNESS_ARCHIVE_SHA256_AMD64=3064cff515b9aa64d942872c87c847919a65057e01f9d7d56a122376b1e5a29e
ARG HARNESS_ARCHIVE_SHA256_ARM64=a435f816b048400cba854f26d723d47786802f93f168e61224d8575a94bacb4c

# These values are the SHA-256 hashes of the OpenFlows release archives,
# not image digests. Verify the archive before installing its harness binary.
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) target=x86_64-unknown-linux-gnu; checksum="$HARNESS_ARCHIVE_SHA256_AMD64" ;; \
      arm64) target=aarch64-unknown-linux-gnu; checksum="$HARNESS_ARCHIVE_SHA256_ARM64" ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    archive="openflows-${OPENFLOWS_VERSION}-${target}.tar.gz"; \
    curl -fsSL --retry 3 "https://github.com/The-AgenticFlow/openflows/releases/download/openflows-${OPENFLOWS_VERSION}/${archive}" -o "/tmp/${archive}"; \
    echo "${checksum}  /tmp/${archive}" | sha256sum -c -; \
    mkdir -p /tmp/openflows-release; \
    tar -xzf "/tmp/${archive}" -C /tmp/openflows-release; \
    harness="$(find /tmp/openflows-release -type f -name openflows-harness -print -quit)"; \
    test -n "$harness"; \
    install -m 0755 "$harness" /usr/local/bin/openflows-harness; \
    rm -rf /tmp/openflows-release "/tmp/${archive}"

ARG ROLE
COPY --from=role-assets /tmp/role-assets/ /opt/openflows/orchestration/
COPY scripts/openflows-runtime /usr/local/bin/openflows-runtime
RUN chmod 0755 /usr/local/bin/openflows-runtime \
    && find /opt/openflows/orchestration/plugin/hooks -type f -name '*.sh' -exec chmod 0755 {} +

ENV HOME=/home/coder \
    OPENFLOWS_IMAGE_ROLE=$ROLE \
    OPENFLOWS_ROLE=$ROLE \
    OPENFLOWS_ASSET_ROOT=/opt/openflows/orchestration

USER coder
WORKDIR /home/coder/workspace
