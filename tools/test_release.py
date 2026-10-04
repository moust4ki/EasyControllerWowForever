"""Regression tests for release notes. Run: python -m unittest discover -s tools -p 'test_*.py'."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import release


class ReleaseNotesTests(unittest.TestCase):
    def notes(self, changelog, version):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "CHANGELOG.md").write_text(changelog, encoding="utf-8")
            with patch.object(release, "ROOT", root):
                return release.notes(version)

    def test_release_does_not_use_prerelease_notes(self):
        text = "## 1.8.2-beta1\nBeta notes.\n\n## 1.8.2\nRelease notes.\n"
        self.assertEqual(self.notes(text, "1.8.2"), "Release notes.\n")

    def test_missing_release_is_not_satisfied_by_prerelease(self):
        with self.assertRaises(SystemExit):
            self.notes("## 1.8.2-beta1\nBeta notes.\n", "1.8.2")

    def test_heading_title_and_following_section(self):
        text = "## 1.8.2 - Fixes\nThe fix.\n\n## 1.8.1\nOlder notes.\n"
        self.assertEqual(self.notes(text, "1.8.2"), "The fix.\n")

    def test_explicit_prerelease(self):
        text = "## 1.8.2-beta1\nBeta notes.\n\n## 1.8.1\nOlder notes.\n"
        self.assertEqual(self.notes(text, "1.8.2-beta1"), "Beta notes.\n")


if __name__ == "__main__":
    unittest.main()
