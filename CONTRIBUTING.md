# Contributing

The OpenFlows maintainers own this repository. Every runtime asset, image dependency, manifest change, and release workflow change requires a pull request and maintainer review. Protect `main` with required CI, review, and no force pushes. Changes to the bootstrap or manifest contract require an OpenFlows consumer compatibility review before release.

Keep role assets under `orchestration/`. Do not put tenant data, credentials, repository source, or generated runtime state in the image. Add a changelog entry for user-visible changes and update `manifests/release.template.json` when the compatibility contract changes. Pull requests should state the OpenFlows template/schema versions tested and whether existing workspaces need migration.

The supported roles are Nexus, Forge, Sentinel, Vessel, and Lore. Lore is packaged even where OpenFlows does not enable it by default. All roles use the same immutable image, selected at startup by `OPENFLOWS_ROLE`.

Report security issues privately to the maintainers through GitHub's private vulnerability reporting. Do not disclose secrets or tenant data in issues, logs, or test fixtures.
