#!/usr/bin/env bash
# Sourced by every development shell. Never read stdin: --command and CI must work.
printf '\ndicom4ortho development environments (selected: %s)\n' "${1:-python}"
cat <<'HELP'
  nix develop           Python default: library, CLI, tests, terminology maintenance
  nix develop .#python  Explicit Python environment (same as the default)
  nix develop .#swift   Swift support tools; requires an installed Swift 6.4+ toolchain

  Run these commands from the repository root. Choose Python for the shared
  terminology generator; choose Swift for library development without Python setup.
  Swift: set SWIFT_TOOLCHAIN_BIN to the directory containing your Swift 6.4+ binary,
  or put it on PATH. Linux dependency compatibility is not yet verified.
  iOS SDKs and simulator testing require a compatible Xcode on macOS.
HELP
