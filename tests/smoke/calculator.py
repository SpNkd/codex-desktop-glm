"""Deliberately buggy calculator fixture for the Codex Desktop agent-loop test."""


def add(a: int, b: int) -> int:
    """Return the sum of two integers (initially wrong on purpose)."""
    return a - b


def subtract(a: int, b: int) -> int:
    """Return the difference of two integers."""
    return a - b
