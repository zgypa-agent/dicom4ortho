"""Guard the repository paths that preserve the existing contributor workflow."""

import configparser
import csv
import re
import subprocess
import unittest
from pathlib import Path
from urllib.parse import unquote, urlsplit


PYTHON_ROOT = Path(__file__).resolve().parent.parent
REPOSITORY_ROOT = PYTHON_ROOT.parent


class TestRepositoryLayout(unittest.TestCase):
    """Packaging and root entry points must continue to address the Python project."""

    def test_generator_writes_the_relocated_committed_lock(self):
        from tools.generate_codes import OUTPUT

        self.assertEqual(OUTPUT, PYTHON_ROOT / 'dicom4ortho' / '_generated_codes.py')
        self.assertTrue(OUTPUT.is_file())

    def test_existing_make_targets_remain_available(self):
        targets = (
            'help', 'default', 'lint', 'test', 'clean', 'build', 'fetch_resources',
            'update_codes', 'check_codes', 'deploy', 'all', 'install-dev',
        )
        for target in targets:
            with self.subTest(target=target):
                result = subprocess.run(
                    ['make', '--dry-run', target],
                    cwd=REPOSITORY_ROOT,
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_make_lint_uses_the_selected_python_interpreter(self):
        result = subprocess.run(
            ['make', '--dry-run', 'lint', 'PYTHON=/selected/venv/bin/python'],
            cwd=REPOSITORY_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn('/selected/venv/bin/python -m pylint --rcfile=python/.pylintrc --errors-only',
                      result.stdout)
        self.assertNotIn('which pylint', result.stdout)

    def test_make_test_prioritizes_the_local_test_package(self):
        result = subprocess.run(
            ['make', '--dry-run', 'test'], cwd=REPOSITORY_ROOT,
            check=True, capture_output=True, text=True,
        )
        self.assertIn(f'PYTHONPATH="{PYTHON_ROOT}', result.stdout)
        self.assertIn('python3 -m unittest discover', result.stdout)

    def test_make_recipes_keep_root_artifacts_and_relocated_test_paths(self):
        expected_commands = {
            'lint': '--errors-only python/dicom4ortho',
            'test': 'python3 -m unittest discover -s python/test -t python',
            'build': 'python3 -m build python --outdir',
            'fetch_resources': 'python/dicom4ortho/resources/views.csv',
            'update_codes': 'python3 tools/generate_codes.py',
            'check_codes': 'python3 tools/generate_codes.py --check',
            'deploy': 'python3 -m twine upload --repository pypi dist/*',
        }
        for target, command in expected_commands.items():
            with self.subTest(target=target):
                result = subprocess.run(
                    ['make', '--dry-run', target],
                    cwd=REPOSITORY_ROOT,
                    check=True,
                    capture_output=True,
                    text=True,
                )
                self.assertIn(command, result.stdout)
                if target == 'test':
                    self.assertIn('python/test/docker-compose.yml', result.stdout)

    def test_version_bump_configuration_tracks_existing_files(self):
        configuration = configparser.ConfigParser(interpolation=None)
        configuration.read(PYTHON_ROOT / '.bumpversion.cfg')
        files = [
            section.removeprefix('bumpversion:file:')
            for section in configuration.sections()
            if section.startswith('bumpversion:file:')
        ]
        self.assertEqual(
            files, ['python/dicom4ortho/config.py', 'python/pyproject.toml', 'python/README.md'])
        for filename in files:
            self.assertTrue((REPOSITORY_ROOT / filename).is_file(), filename)

    def test_example_images_remain_relative_to_the_csv(self):
        example_directory = PYTHON_ROOT / 'examples'
        with (example_directory / 'input_from.csv').open(encoding='utf-8') as source:
            rows = list(csv.DictReader(source))
        self.assertEqual(len(rows), 3)
        for row in rows:
            with self.subTest(image_type=row['image_type']):
                self.assertTrue(
                    (example_directory / row['input_image_filename']).is_file())

    def test_python_packaging_lives_in_the_language_directory(self):
        self.assertFalse((REPOSITORY_ROOT / 'pyproject.toml').exists())
        for filename in ('pyproject.toml', 'MANIFEST.in', '.pylintrc', '.bumpversion.cfg'):
            self.assertTrue((PYTHON_ROOT / filename).is_file(), filename)
            self.assertFalse((REPOSITORY_ROOT / filename).exists(), filename)
        self.assertTrue((REPOSITORY_ROOT / 'LICENSE').is_file())
        self.assertTrue((REPOSITORY_ROOT / 'tools' / 'generate_codes.py').is_file())

    def test_python_license_matches_the_project_license(self):
        self.assertEqual((PYTHON_ROOT / 'LICENSE').read_bytes(),
                         (REPOSITORY_ROOT / 'LICENSE').read_bytes())

    def test_swift_manifest_stays_at_root_for_git_url_dependencies(self):
        manifest = REPOSITORY_ROOT / 'Package.swift'
        self.assertTrue(manifest.is_file())
        self.assertFalse((REPOSITORY_ROOT / 'apple' / 'Package.swift').exists())
        self.assertIn('subdirectory selector', manifest.read_text(encoding='utf-8'))

    def test_python_package_description_uses_the_python_readme(self):
        # Keep this compatible with Python 3.10, which has no stdlib tomllib.
        project = (PYTHON_ROOT / 'pyproject.toml').read_text(encoding='utf-8')
        self.assertIn('readme = "README.md"', project)

    def test_documentation_relative_links_resolve(self):
        documents = [REPOSITORY_ROOT / 'README.md', PYTHON_ROOT / 'README.md']
        documents += list((PYTHON_ROOT / 'docs').glob('*.md'))
        # The Python sdist carries Python docs, not the Swift documentation tree.
        if (REPOSITORY_ROOT / 'Package.swift').exists():
            documents += list((REPOSITORY_ROOT / 'apple').rglob('*.md'))
        for document in documents:
            text = document.read_text(encoding='utf-8')
            for link in re.findall(r'\[[^\]]*\]\(([^\s)]+)\)', text):
                url = urlsplit(link)
                if url.scheme or url.netloc or not url.path:
                    continue
                target = (document.parent / unquote(url.path)).resolve()
                # Cross-port links are usable in the checkout, not the Python sdist.
                if not (REPOSITORY_ROOT / 'Package.swift').exists() and \
                        target.is_relative_to(REPOSITORY_ROOT / 'apple'):
                    continue
                with self.subTest(document=document, link=link):
                    self.assertTrue(target.exists(), f'Missing documentation target: {target}')

    def test_fixed_dicom_fixture_is_preserved(self):
        self.assertTrue((PYTHON_ROOT / 'test' / 'resources' / 'test.dcm').is_file())


if __name__ == '__main__':
    unittest.main()
