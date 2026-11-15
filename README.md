# OpenFlows workspace runtime

This repository owns five deployable agent workspace images and their static assets: role instructions, skills, commands, hooks, standards, and the `openflows-harness` executable. OpenFlows Manager selects an immutable release manifest and supplies runtime credentials and a repository revision when Coder creates a workspace. The server repository remains the consumer of this release, not the source of the images.

Each image contains one role: `nexus`, `forge`, `sentinel`, `vessel`, or `lore`. The image sets `OPENFLOWS_ROLE`; `openflows-runtime install` copies its assets into `$HOME/.openflows/artifacts` for the runtime user. `openflows-runtime check` reports the packaged release and checks that its assets and harness exist. The installer rejects a different role supplied at runtime. The images do not register a workspace with Manager or clone a tenant repository; those dynamic operations still belong to the workspace bootstrap integration.

The final image uses a digest-pinned Debian slim base, a non-root `coder` user, and only the tools needed by the current OpenFlows startup scripts. The separate Python build stage assembles role assets and is not shipped in the final image. No Claude Code, Codex, Aider, Goose, Node.js, or npm executable is installed. Coder supplies its workspace agent through the template's init script; OpenFlows supplies the coordination harness. Repository-specific build toolchains must be provided separately when a task needs them.

The `HARNESS_ARCHIVE_SHA256_*` build arguments are the published SHA-256 checksums of the OpenFlows release archives for AMD64 and ARM64. The build checks them before extracting `openflows-harness`; running workspaces do not download that archive.

The current OpenFlows Docker templates still call `sudo`, so the image keeps it for compatibility. The Kubernetes template migration must replace those startup calls with correct non-root ownership before using the restricted pod policy. Publishing this image alone does not activate the Kubernetes templates.

## Layout

- `roles/<role>/`: each role's agent instructions, skills, commands, hooks, and role-specific standards.
- `shared/`: assets included in every role image: common skills, commands, the security standard, and the MCP template.
- `scripts/openflows-runtime`: role asset installer and image self-check.
- `scripts/package_role.py`: assembles one role directory and the shared directory for its image. The installed paths retain the image's existing `orchestration/agent` and `plugin` layout; OpenFlows consumer integration remains a separate migration.
- `manifests/release.schema.json`: versioned manifest contract consumed by OpenFlows.
- `manifests/release.template.json`: release metadata before CI fills the immutable image digest.
- `.github/workflows/ci.yml`: validation and image build for pull requests.
- `.github/workflows/release-please.yml`: prepares one release PR and publishes after that PR is merged.
- `.github/workflows/release.yml`: five image builds, provenance, and manifest release asset.

Each role owns its hook scripts under `roles/<role>/hooks/`, including a `session_start.sh`. The image contains those scripts without a separate hook mapping or Codex plugin manifest. OpenFlows supplies the client hook settings when it provisions a workspace.

## Release contract

Merging feature PRs into `main` updates the single Release Please PR. A maintainer merges that release PR when ready. Release Please then creates the `vMAJOR.MINOR.PATCH` tag and GitHub Release, and the workflow publishes five images named `ghcr.io/the-agenticflow/workspace-runtime-<role>:<tag>` plus a release manifest containing each role's image digest. The manifest is the input to Manager's compatibility check. It lists the runtime version, all supported roles, Linux architectures, bootstrap contract, credential path, and compatible template schema major versions. Manager must reject an incomplete set and pin existing workspaces to their selected role image and template digests. A tag or release manifest is immutable; corrections require a new version.

The manifest uses schema version 2 for five role images and bootstrap contract version 2. Its `asset_directory` is relative to the runtime user's home directory. It does **not** claim that the current OpenFlows Terraform templates already consume these images. That integration is a separate migration, and no workspace should be switched merely because this repository publishes images.

## Local checks

```sh
python3 scripts/validate.py
docker build --platform linux/amd64 --build-arg ROLE=forge -t workspace-runtime-forge:dev .
docker run --rm workspace-runtime-forge:dev openflows-runtime check
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [RELEASING.md](RELEASING.md) for ownership, review, security, release, and rollback rules.
