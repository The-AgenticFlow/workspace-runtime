#!/usr/bin/env python3
"""Check source assets and create/validate a digest-pinned release manifest."""

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ROLES = {"nexus", "forge", "sentinel", "vessel", "lore"}


def validate(data, *, released=False):
    assert data["schema_version"] == 2
    assert re.fullmatch(r"\d+\.\d+\.\d+", data["runtime_version"])
    assert (ROOT / ".version").read_text().strip() == data["runtime_version"]
    assert set(data["roles"]) == ROLES and len(data["roles"]) == len(ROLES)
    assert set(data["images"]) == ROLES
    for role, image in data["images"].items():
        assert set(image["architectures"]) == {"linux/amd64", "linux/arm64"}
        assert image["repository"] == f"ghcr.io/the-agenticflow/workspace-runtime-{role}"
        if released:
            assert re.fullmatch(r"sha256:[0-9a-f]{64}", image["digest"])
        else:
            assert image["digest"] == "__IMAGE_DIGEST__"
    assert data["bootstrap"]["contract_version"] == 2
    assert data["bootstrap"]["credential_file"] == "/run/openflows/runtime.json"
    assert data["bootstrap"]["asset_install_command"] == "openflows-runtime install"
    assert data["bootstrap"]["asset_directory"] == ".openflows/artifacts"
    assert re.fullmatch(r"openflows-\d+\.\d+\.\d+", data["harness"]["openflows_release"])
    versions = data["compatibility"]["openflows_template_parameter_schema_versions"]
    assert all(isinstance(v, int) and v > 0 for v in versions)
    if data["status"] == "compatible":
        assert versions and data["compatibility"]["minimum_manager_version"]
    else:
        assert data["status"] == "candidate" and not versions
    for role in ROLES:
        role_source = ROOT / "roles" / role
        assert (role_source / "agent.md").is_file()
        assert (role_source / "hooks").is_dir()
        assert any((role_source / "skills").glob(f"{role}-*/SKILL.md"))
        assert (role_source / "hooks/session_start.sh").is_file()
    assert (ROOT / "shared/skills/shared-harness-protocol/SKILL.md").is_file()
    assert (ROOT / "shared/config/mcp.json.template").is_file()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--digests-dir", type=Path, help="Directory containing one <role>.txt OCI digest per role")
    args = parser.parse_args()
    template = json.loads((ROOT / "manifests/release.template.json").read_text())
    validate(template)
    if args.digests_dir:
        for role in ROLES:
            template["images"][role]["digest"] = (args.digests_dir / f"{role}.txt").read_text().strip()
        validate(template, released=True)
        (ROOT / "release-manifest.json").write_text(json.dumps(template, indent=2) + "\n")
        print("Wrote release-manifest.json")
    else:
        print("Runtime assets and manifest template valid")


if __name__ == "__main__":
    main()
