#!/usr/bin/env python3
"""Parse all repository Python sources without creating bytecode files."""

from __future__ import annotations

import ast
from pathlib import Path


def validate(root: Path) -> int:
    """Parse each Python file below root and return the number of failures."""
    failures = 0
    for path in root.rglob("*.py"):
        if ".git" in path.parts:
            continue
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except (OSError, SyntaxError) as error:
            print(f"{path}: {error}")
            failures += 1
    return failures


def main() -> int:
    """Validate Python sources in the current repository."""
    failures = validate(Path.cwd())
    if failures:
        return 1
    print("Python AST OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
