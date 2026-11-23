FROM python:3.15-alpine@sha256:0f9552bb28711333da16915ec146f5e6bb44a7fdac9ced15dc17c2e0206346dd AS role-assets
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
    ca-certificates curl git jq procps python3 sudo \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --gid 1000 coder \
    && useradd --uid 1000 --gid coder --create-home --shell /bin/bash coder \
    && printf '%s\n' 'coder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && mkdir -p /home/coder/workspace /home/coder/.openflows \
    && chown -R coder:coder /home/coder

ARG TARGETARCH
ARG OPENFLOWS_VERSION=1.9.0
ARG HARNESS_ARCHIVE_SHA256_AMD64=ec54fe6439c524c2af390ca021ab86a18e90889aa95db9de31baa3c8ebea6967
ARG HARNESS_ARCHIVE_SHA256_ARM64=90ae71254b0d69ed92870522abd6c5bcefa299fbf2c8c1be7b69de8b2ca22be0

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
    controller="$(find /tmp/openflows-release -type f -name openflows -print -quit)"; \
    test -n "$harness"; \
    test -n "$controller"; \
    install -m 0755 "$harness" /usr/local/bin/openflows-harness; \
    install -m 0755 "$controller" /usr/local/bin/openflows; \
    rm -rf /tmp/openflows-release "/tmp/${archive}"

ARG ROLE
COPY --from=role-assets /tmp/role-assets/ /opt/openflows/orchestration/
COPY scripts/openflows-runtime /usr/local/bin/openflows-runtime
COPY runtime/lib/bootstrap.sh /opt/openflows/runtime/lib/bootstrap.sh
COPY runtime/bin/openflows-credential-refresh /opt/openflows/runtime/bin/openflows-credential-refresh
COPY runtime/VERSION /opt/openflows/runtime/VERSION
RUN chmod 0755 /usr/local/bin/openflows-runtime /opt/openflows/runtime/bin/openflows-credential-refresh \
    && chmod 0644 /opt/openflows/runtime/lib/bootstrap.sh /opt/openflows/runtime/VERSION \
    && find /opt/openflows/orchestration/plugin/hooks -type f -name '*.sh' -exec chmod 0755 {} +

ENV HOME=/home/coder \
    OPENFLOWS_IMAGE_ROLE=$ROLE \
    OPENFLOWS_ROLE=$ROLE \
    OPENFLOWS_ASSET_ROOT=/opt/openflows/orchestration

USER coder
WORKDIR /home/coder/workspace
