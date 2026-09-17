"""Tests that should drive the agent to find and fix add()."""

import unittest

from calculator import add, subtract


class CalculatorTests(unittest.TestCase):
    """The first test intentionally fails until the agent fixes add()."""

    def test_add(self) -> None:
        self.assertEqual(add(2, 3), 5)

    def test_subtract(self) -> None:
        self.assertEqual(subtract(5, 3), 2)


if __name__ == "__main__":
    unittest.main()
