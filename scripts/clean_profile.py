#!/usr/bin/env python3
"""Remove the integration's managed source block from a Unix shell profile."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


BEGIN = "# BEGIN codex-desktop-glm environment"
END = "# END codex-desktop-glm environment"


def clean(text: str) -> str:
    """Remove the first managed environment block and preserve other lines."""
    result: list[str] = []
    skipping = False
    for line in text.splitlines():
        if line.strip() == BEGIN:
            skipping = True
            continue
        if skipping and line.strip() == END:
            skipping = False
            continue
        if not skipping:
            result.append(line)
    return "\n".join(result).rstrip() + ("\n" if result else "")


def main() -> int:
    """Clean one profile path if it exists."""
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=Path)
    arguments = parser.parse_args()
    if not arguments.profile.exists():
        return 0
    content = arguments.profile.read_text(encoding="utf-8")
    temporary = arguments.profile.with_name(f".{arguments.profile.name}.{os.getpid()}.tmp")
    temporary.write_text(clean(content), encoding="utf-8", newline="")
    os.replace(temporary, arguments.profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
