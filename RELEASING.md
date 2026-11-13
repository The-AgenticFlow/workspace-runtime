# Release and rollback policy

1. Merge a reviewed change into protected `main` after CI passes. Use semantic versioning: major for incompatible bootstrap/manifest changes, minor for compatible features or role assets, patch for compatible fixes.
2. Create an annotated `vMAJOR.MINOR.PATCH` tag on the reviewed commit. Tags are never moved or reused.
3. The release workflow builds amd64 and arm64 images, publishes them to GHCR, attaches build provenance, validates the digest-pinned manifest, and creates a GitHub Release with that manifest. Verify the image and manifest digests before making the release available to OpenFlows. Make the GHCR package public, or configure a pull credential for every Coder provisioner and workspace backend; public GitHub source does not automatically make the package public.
4. OpenFlows selects the manifest by exact release and stores both the runtime image digest and compatible template digest for each workspace. Existing workspaces do not change when a new tag appears.

Rollback means selecting the previous known-good manifest and its compatible OpenFlows template release for **new** workspaces. Existing workspaces keep their pinned tuple. If a workspace must be moved back, provision a new workspace from that tuple and restore only supported persistent data from a valid snapshot; do not mutate an existing workspace image in place. Revoke a vulnerable release in Manager's allowlist and publish a fixed tag; do not overwrite the old image or manifest. Keep previous images and release assets available for rollback.

Dependabot opens weekly Docker and GitHub Actions dependency updates. CI checks every change. Maintainers review vulnerability advisories and scan published images; a critical finding blocks promotion until fixed or documented with an expiry. The release workflow emits provenance tied to the image digest. Registry retention must preserve every manifest still referenced by a workspace or rollback window.
