FROM codercom/enterprise-base:ubuntu AS runtime-base

USER root
ARG TARGETARCH
ARG OPENFLOWS_VERSION=1.8.2
ARG CLAUDE_CODE_VERSION=2.1.325
ARG HARNESS_SHA256_AMD64=3064cff515b9aa64d942872c87c847919a65057e01f9d7d56a122376b1e5a29e
ARG HARNESS_SHA256_ARM64=a435f816b048400cba854f26d723d47786802f93f168e61224d8575a94bacb4c

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git nodejs npm python3 \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

# The harness is a separately released OpenFlows binary. Pin the archive bytes
# for each platform so a rebuilt runtime cannot silently acquire another binary.
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) target=x86_64-unknown-linux-gnu; checksum="$HARNESS_SHA256_AMD64" ;; \
      arm64) target=aarch64-unknown-linux-gnu; checksum="$HARNESS_SHA256_ARM64" ;; \
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

FROM codercom/enterprise-base:ubuntu AS role-assets
USER root
ARG ROLE
COPY .version /tmp/source/.version
COPY roles /tmp/source/roles
COPY shared /tmp/source/shared
COPY scripts/package_role.py /tmp/source/package_role.py
RUN python3 /tmp/source/package_role.py --role "$ROLE" --source /tmp/source --output /tmp/role-assets

FROM runtime-base AS runtime
ARG ROLE
COPY --from=role-assets /tmp/role-assets/ /opt/openflows/orchestration/
COPY scripts/openflows-runtime /usr/local/bin/openflows-runtime
RUN chmod 0755 /usr/local/bin/openflows-runtime && \
    find /opt/openflows/orchestration/plugin/hooks -type f -name '*.sh' -exec chmod 0755 {} +

ENV OPENFLOWS_IMAGE_ROLE=$ROLE \
    OPENFLOWS_ROLE=$ROLE \
    OPENFLOWS_ASSET_ROOT=/opt/openflows/orchestration

USER coder
