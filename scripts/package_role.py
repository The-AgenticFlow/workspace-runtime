#!/usr/bin/env python3
"""Assemble one role's assets into the existing workspace artifact layout."""

import argparse
from pathlib import Path
import shutil


def copy(source: Path, destination: Path) -> None:
    if not source.exists():
        raise FileNotFoundError(source)
    if destination.exists():
        raise ValueError(f"Duplicate role asset: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, destination)
    else:
        shutil.copy2(source, destination)


def copy_directory(source: Path, destination: Path, *, required: bool = True) -> None:
    if not source.is_dir():
        if required:
            raise FileNotFoundError(source)
        return
    for entry in sorted(source.iterdir()):
        copy(entry, destination / entry.name)


def package(role: str, source: Path, output: Path) -> None:
    if Path(role).name != role or role in (".", ".."):
        raise ValueError(f"Invalid role name: {role}")
    role_source = source / "roles" / role
    if not role_source.is_dir() or not (role_source / "agent.md").is_file():
        raise ValueError(f"Unknown or incomplete role: {role}")
    if output.exists():
        shutil.rmtree(output)

    copy(source / ".version", output / ".version")
    copy(role_source / "agent.md", output / "agent/agents" / f"{role}.agent.md")
    if (role_source / "registry.json").is_file():
        copy(role_source / "registry.json", output / "agent/registry.json")

    copy_directory(source / "shared/standards", output / "agent/standards")
    copy_directory(role_source / "standards", output / "agent/standards", required=False)
    copy_directory(source / "shared/skills", output / "plugin/skills")
    copy_directory(role_source / "skills", output / "plugin/skills")
    copy_directory(source / "shared/commands", output / "plugin/commands")
    copy_directory(role_source / "commands", output / "plugin/commands")
    copy(role_source / "hooks", output / "plugin/hooks" / role)
    copy(source / "shared/config/mcp.json.template", output / "plugin/mcp/mcp.json.template")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    package(args.role, args.source, args.output)


if __name__ == "__main__":
    main()
