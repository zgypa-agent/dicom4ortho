"""Exercise development-shell setup without installing packages or touching a real venv."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SETUP_SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'setup-python-env.sh'
REPOSITORY = Path(__file__).resolve().parents[2]
SWIFT_SETUP_SCRIPT = REPOSITORY / 'apple' / 'Tools' / 'SetupSwiftEnvironment.sh'
SHELL_HELP = REPOSITORY / 'tools' / 'development-shell-help.sh'


class TestDevelopmentEnvironment(unittest.TestCase):
    """A moved environment must fail clearly instead of activating the old checkout."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin_directory = self.root / '.venv' / 'bin'
        self.bin_directory.mkdir(parents=True)
        self.log = self.root / 'interpreter-calls.txt'
        interpreter = self.bin_directory / 'python'
        interpreter.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$SETUP_CALL_LOG"\n'
            'exit "${SETUP_PIP_STATUS:-0}"\n', encoding='utf-8')
        interpreter.chmod(0o755)

    def _activate_from(self, directory: Path) -> None:
        (self.bin_directory / 'activate').write_text(
            f'export VIRTUAL_ENV="{directory}"\n'
            'export PATH="$VIRTUAL_ENV/bin:$PATH"\n'
            'hash -r 2>/dev/null\n', encoding='utf-8')

    def _run_setup(
        self, pip_status: int = 0, hashing_enabled: bool = True
    ) -> subprocess.CompletedProcess:
        environment = dict(os.environ)
        environment['SETUP_CALL_LOG'] = str(self.log)
        environment['SETUP_PIP_STATUS'] = str(pip_status)
        shell_flags = 'set -h; ' if hashing_enabled else 'set +h; '
        return subprocess.run(
            ['bash', '-c', shell_flags +
             'source "$1" && printf "ACTIVE=%s\\nFLAGS=%s\\n" "$VIRTUAL_ENV" "$-"',
             'setup-test', str(SETUP_SCRIPT)],
            cwd=self.root, env=environment, capture_output=True, text=True, check=False,
        )

    def test_moved_environment_is_preserved_and_rejected_before_install(self):
        self._activate_from(self.root / 'old-checkout' / '.venv')
        result = self._run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('another checkout path', result.stderr)
        self.assertIn('backup', result.stderr)
        self.assertFalse(self.log.exists())
        self.assertTrue((self.bin_directory / 'activate').is_file())

    def test_current_environment_installs_through_python_not_pip_script(self):
        self._activate_from(self.bin_directory.parent)
        (self.bin_directory / 'pip').write_text(
            '#!/missing/old-checkout/python\n', encoding='utf-8')
        result = self._run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(encoding='utf-8'),
                          '-m pip install --quiet -e ./python[dev]\n')
        self.assertIn(f'ACTIVE={self.bin_directory.parent}', result.stdout)

    def test_dependency_install_failure_stops_before_activation(self):
        self._activate_from(self.bin_directory.parent)
        result = self._run_setup(pip_status=7)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('ACTIVE=', result.stdout)

    def test_activation_succeeds_with_nix_command_hashing_disabled(self):
        self._activate_from(self.bin_directory.parent)
        result = self._run_setup(hashing_enabled=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'ACTIVE={self.bin_directory.parent}', result.stdout)
        flags = next(line for line in result.stdout.splitlines() if line.startswith('FLAGS='))
        self.assertNotIn('h', flags.removeprefix('FLAGS='))


class TestSwiftDevelopmentEnvironment(unittest.TestCase):
    """Check toolchain selection without installing Swift or creating a Python venv."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def _swift(self, version: str, status: int = 0) -> Path:
        binary = self.root / 'toolchain' / 'swift'
        binary.parent.mkdir(exist_ok=True)
        binary.write_text(f'#!/bin/sh\nprintf "%s\\n" "{version}"\nexit {status}\n',
                          encoding='utf-8')
        binary.chmod(0o755)
        return binary.parent

    def _run_setup(
        self, toolchain: Path | None = None, search_path: Path | None = None
    ) -> subprocess.CompletedProcess:
        environment = dict(os.environ, PATH=str(search_path or self.root / 'empty'))
        environment.pop('SWIFT_TOOLCHAIN_BIN', None)
        if toolchain is not None:
            environment['SWIFT_TOOLCHAIN_BIN'] = str(toolchain)
        return subprocess.run(
            ['/bin/bash', '-eu', '-c', 'source "$1"', 'swift-setup', str(SWIFT_SETUP_SCRIPT)],
            cwd=self.root, env=environment, capture_output=True, text=True, check=False)

    def test_missing_swift_explains_how_to_select_a_toolchain(self):
        result = self._run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not on PATH', result.stderr)
        self.assertIn('SWIFT_TOOLCHAIN_BIN', result.stderr)

    def test_invalid_override_fails_instead_of_silently_using_another_compiler(self):
        result = self._run_setup(self.root / 'missing')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must contain an executable swift', result.stderr)

    def test_old_unrecognized_and_failed_toolchains_are_rejected(self):
        for version, status in [('Swift version 5.8', 0), ('Apple Swift version 6.2.4', 0),
                                ('unknown version', 0), ('cannot execute', 1)]:
            with self.subTest(version=version):
                result = self._run_setup(self._swift(version, status))
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('shell ready', result.stdout)

    def test_supported_toolchains_do_not_set_up_python(self):
        for version in ['Swift version 6.4.1', 'Apple Swift version 6.4', 'Swift version 7.0']:
            with self.subTest(version=version):
                result = self._run_setup(self._swift(version))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('Swift shell ready', result.stdout)
                self.assertFalse((self.root / '.venv').exists())

    def test_existing_path_toolchain_works_without_an_override(self):
        result = self._run_setup(search_path=self._swift('Swift version 6.4.1'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Swift shell ready', result.stdout)

    def test_help_advertises_both_shells_without_reading_stdin(self):
        for selected in ('python', 'swift'):
            result = subprocess.run(
                ['/bin/bash', '-c', 'source "$1" "$2"', 'shell-help', str(SHELL_HELP), selected],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, check=True, timeout=5)
            self.assertIn(f'selected: {selected}', result.stdout)
            self.assertIn('nix develop .#python', result.stdout)
            self.assertIn('nix develop .#swift', result.stdout)
            self.assertIn('Xcode', result.stdout)
            self.assertIn('2026-10-18', result.stdout)
            self.assertIn('nixos-unstable', result.stdout)
            self.assertIn('not a claim about all third-party flakes', result.stdout)
