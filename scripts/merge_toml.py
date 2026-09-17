#!/usr/bin/env python3
"""Maintain the small Codex provider block used by the integration scripts."""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path
from typing import Iterable, Sequence


MANAGED_BEGIN = re.compile(r"^\s*#\s*BEGIN codex-desktop-glm managed")
MANAGED_END = re.compile(r"^\s*#\s*END codex-desktop-glm managed")
TABLE_HEADER = re.compile(r"^\s*\[{1,2}([^\]]+)\]{1,2}\s*$")
ROOT_KEYS = ("model", "model_provider", "model_reasoning_effort", "model_catalog_json")


def remove_managed_blocks(lines: Iterable[str]) -> list[str]:
    """Remove settings/provider blocks previously written by this project."""
    result: list[str] = []
    skipping = False
    for line in lines:
        if MANAGED_BEGIN.match(line):
            skipping = True
            continue
        if skipping and MANAGED_END.match(line):
            skipping = False
            continue
        if not skipping:
            result.append(line)
    return result


def remove_provider_section(lines: Iterable[str], name: str = "model_providers.ZAI") -> list[str]:
    """Remove the selected provider table and any nested tables."""
    result: list[str] = []
    skipping = False
    for line in lines:
        match = TABLE_HEADER.match(line)
        if match:
            current = match.group(1)
            skipping = current == name or current.startswith(name + ".")
            if not skipping:
                result.append(line)
            continue
        if not skipping:
            result.append(line)
    return result


def remove_root_keys(lines: Iterable[str], keys: Sequence[str] = ROOT_KEYS) -> list[str]:
    """Remove only matching root-level keys, preserving project tables."""
    result: list[str] = []
    in_table = False
    key_pattern = re.compile(r"^\s*(?:" + "|".join(map(re.escape, keys)) + r")\s*=")
    for line in lines:
        if TABLE_HEADER.match(line):
            in_table = True
        if not in_table and not line.lstrip().startswith("#") and key_pattern.match(line):
            continue
        result.append(line)
    return result


def managed_root(catalog_path: str) -> list[str]:
    """Return the top-level managed Codex settings."""
    return [
        "# BEGIN codex-desktop-glm managed settings",
        'model = "glm-5.3"',
        'model_provider = "ZAI"',
        'model_reasoning_effort = "max"',
        f'model_catalog_json = "{catalog_path}"',
        "# END codex-desktop-glm managed settings",
    ]


def managed_provider() -> list[str]:
    """Return the provider table for the direct Z.ai Responses route."""
    return [
        "",
        "# BEGIN codex-desktop-glm managed provider",
        "[model_providers.ZAI]",
        'name = "Z.ai GLM Coding Plan"',
        'base_url = "https://api.z.ai/api/v1"',
        'env_key = "ZAI_API_KEY"',
        'wire_api = "responses"',
        "supports_websockets = false",
        "# END codex-desktop-glm managed provider",
    ]


def add_managed_config(text: str, catalog_path: str) -> str:
    """Insert a single idempotent provider block into a TOML document."""
    lines = remove_managed_blocks(text.splitlines())
    lines = remove_provider_section(lines)
    lines = remove_root_keys(lines)
    first_table = next((index for index, line in enumerate(lines) if TABLE_HEADER.match(line)), len(lines))
    result = lines[:first_table] + managed_root(catalog_path) + [""] + lines[first_table:]
    result.extend(managed_provider())
    return "\n".join(result).rstrip() + "\n"


def remove_managed_config(text: str) -> str:
    """Remove this project's blocks without deleting unrelated root settings."""
    lines = remove_managed_blocks(text.splitlines())
    lines = remove_provider_section(lines)
    return "\n".join(lines).rstrip() + "\n"


def atomic_write(path: Path, text: str) -> None:
    """Write beside the target and atomically replace it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(text, encoding="utf-8", newline="")
    os.replace(temporary, path)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--catalog", type=str)
    parser.add_argument("--remove", action="store_true")
    return parser.parse_args()


def main() -> int:
    """Update or clean one Codex config file."""
    arguments = parse_args()
    current = arguments.config.read_text(encoding="utf-8") if arguments.config.exists() else ""
    if arguments.remove:
        output = remove_managed_config(current)
    else:
        if not arguments.catalog:
            raise SystemExit("--catalog is required unless --remove is used")
        output = add_managed_config(current, arguments.catalog)
    atomic_write(arguments.config, output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
