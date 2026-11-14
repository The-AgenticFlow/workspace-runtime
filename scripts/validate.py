#!/usr/bin/env python3
"""Check source assets and create/validate a digest-pinned release manifest."""

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ROLES = {"nexus", "forge", "sentinel", "vessel", "lore"}


def validate(data, *, released=False):
    assert data["schema_version"] == 1
    assert re.fullmatch(r"\d+\.\d+\.\d+", data["runtime_version"])
    assert (ROOT / "orchestration/.version").read_text().strip() == data["runtime_version"]
    assert set(data["roles"]) == ROLES and len(data["roles"]) == len(ROLES)
    assert set(data["image"]["architectures"]) == {"linux/amd64", "linux/arm64"}
    assert data["image"]["repository"] == "ghcr.io/the-agenticflow/workspace-runtime"
    assert data["bootstrap"]["contract_version"] == 1
    assert data["bootstrap"]["credential_file"] == "/run/openflows/runtime.json"
    assert data["bootstrap"]["asset_install_command"] == "openflows-runtime install"
    assert re.fullmatch(r"openflows-\d+\.\d+\.\d+", data["harness"]["openflows_release"])
    versions = data["compatibility"]["openflows_template_parameter_schema_versions"]
    assert all(isinstance(v, int) and v > 0 for v in versions)
    if data["status"] == "compatible":
        assert versions and data["compatibility"]["minimum_manager_version"]
    else:
        assert data["status"] == "candidate" and not versions
    if released:
        assert re.fullmatch(r"sha256:[0-9a-f]{64}", data["image"]["digest"])
    else:
        assert data["image"]["digest"] == "__IMAGE_DIGEST__"
    for role in ROLES:
        assert (ROOT / "orchestration/agent/agents" / f"{role}.agent.md").is_file()
        assert (ROOT / "orchestration/plugin/hooks" / role).is_dir()
        assert any((ROOT / "orchestration/plugin/skills").glob(f"{role}-*/SKILL.md"))
    assert (ROOT / "orchestration/plugin/skills/shared-harness-protocol/SKILL.md").is_file()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--digest", help="OCI image digest to write into release-manifest.json")
    args = parser.parse_args()
    template = json.loads((ROOT / "manifests/release.template.json").read_text())
    validate(template)
    if args.digest:
        template["image"]["digest"] = args.digest
        validate(template, released=True)
        (ROOT / "release-manifest.json").write_text(json.dumps(template, indent=2) + "\n")
        print("Wrote release-manifest.json")
    else:
        print("Runtime assets and manifest template valid")


if __name__ == "__main__":
    main()
