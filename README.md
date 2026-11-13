# OpenFlows workspace runtime

This repository owns the deployable agent workspace image and the static assets it carries: role instructions, skills, commands, hooks, standards, and the `openflows-harness` executable. OpenFlows Manager selects an immutable release manifest and supplies runtime credentials and a repository revision when Coder creates a workspace. The server repository remains the consumer of this release, not the source of the image.

The image contains all five roles. Set `OPENFLOWS_ROLE` to `nexus`, `forge`, `sentinel`, `vessel`, or `lore`, then run `openflows-runtime install` to copy that role's assets into the existing `/home/coder/.openflows/artifacts` layout. `openflows-runtime check` reports the packaged release and checks that its assets and harness exist. The image does not register a workspace with Manager or clone a tenant repository; those dynamic operations still belong to the workspace bootstrap integration.

## Layout

- `orchestration/`: static role assets, initially copied from OpenFlows. Changes to these files are made here for new runtime releases.
- `scripts/openflows-runtime`: role asset installer and image self-check.
- `manifests/release.schema.json`: versioned manifest contract consumed by OpenFlows.
- `manifests/release.template.json`: release metadata before CI fills the immutable image digest.
- `.github/workflows/ci.yml`: validation and image build for pull requests.
- `.github/workflows/release.yml`: tag-based image publishing, provenance, and manifest release asset.

## Release contract

Tags use `vMAJOR.MINOR.PATCH`. CI publishes `ghcr.io/the-agenticflow/workspace-runtime:<tag>` and a digest-pinned manifest as a GitHub Release asset. The manifest is the input to Manager's compatibility check. It lists the runtime version, all supported roles, Linux architectures, the image digest, bootstrap contract, credential path, and compatible template schema major versions. Manager must reject an incomplete tuple and pin existing workspaces to their selected image and template digests. A tag or release manifest is immutable; corrections require a new version.

The initial manifest declares compatibility contract version 1. It does **not** claim that the current OpenFlows Terraform templates already consume this image. That integration is a separate migration, and no workspace should be switched merely because this repository publishes an image.

## Local checks

```sh
python3 scripts/validate.py
docker build --platform linux/amd64 -t workspace-runtime:dev .
docker run --rm -e OPENFLOWS_ROLE=forge workspace-runtime:dev openflows-runtime check
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [RELEASING.md](RELEASING.md) for ownership, review, security, release, and rollback rules.
