"""Package the real manifest logic against small disposable workspace fixtures."""
import io
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

import package


class PackageTexturesTests(unittest.TestCase):
    MEMBERS = {
        'ck_btn_normal', 'ck_btn_hover', 'ck_btn_active', 'ck_btn_pressed',
        'ck_reforged_role_normal', 'ck_reforged_role_hover', 'ck_reforged_role_active', 'ck_reforged_role_pressed',
        'ck_reforged_gryphon_left', 'ck_reforged_gryphon_right',
    }

    def fixture(self, root, missing=None):
        (root / 'EasyController.toc').write_text('## Version: 0-test\nUI.lua\n', encoding='utf-8')
        (root / 'UI.lua').write_text(
            'local button = "ck_btn"; local role = "ck_reforged_role"; '
            'local corner = "ck_reforged_gryphon_"; local static = "ck_static"\n', encoding='utf-8')
        for name in package.EXTRA:
            (root / name).write_text('fixture', encoding='utf-8')
        (root / 'textures').mkdir()
        for name in self.MEMBERS | {'ck_static'}:
            if name != missing:
                (root / 'textures' / (name + '.tga')).write_bytes(b'fixture texture')

    def run_package(self, root):
        with patch.object(package, 'ROOT', root), redirect_stdout(io.StringIO()):
            package.main()

    def test_dynamic_families_package_their_real_files(self):
        with tempfile.TemporaryDirectory(dir=package.ROOT.parent) as directory:
            root = Path(directory)
            self.fixture(root)
            self.run_package(root)
            with zipfile.ZipFile(root / 'dist' / 'EasyController-0-test.zip') as archive:
                textures = {Path(name).stem for name in archive.namelist() if name.endswith('.tga')}
                self.assertEqual(textures, self.MEMBERS | {'ck_static'})
                self.assertIn('EasyController/UI.lua', archive.namelist())
                self.assertNotIn('EasyController/textures/ck_btn.tga', archive.namelist())

    def test_every_missing_family_member_still_fails_before_packaging(self):
        for missing in sorted(self.MEMBERS):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory(dir=package.ROOT.parent) as directory:
                root = Path(directory)
                self.fixture(root, missing)
                with self.assertRaisesRegex(SystemExit, 'Textures used but not packaged: ' + missing):
                    self.run_package(root)
                self.assertFalse((root / 'dist').exists())

    def test_missing_direct_reference_still_fails(self):
        with tempfile.TemporaryDirectory(dir=package.ROOT.parent) as directory:
            root = Path(directory)
            self.fixture(root, 'ck_static')
            with self.assertRaisesRegex(SystemExit, 'Textures used but not packaged: ck_static'):
                self.run_package(root)


if __name__ == '__main__':
    unittest.main()
