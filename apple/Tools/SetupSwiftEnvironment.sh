#!/usr/bin/env bash
# Sourced by the Swift Nix shell. Nix provides support tools, not an outdated Swift.
# Keep this independent of Python setup and do not download/modify host toolchains.
if [ -n "${SWIFT_TOOLCHAIN_BIN:-}" ]; then
    if [ ! -x "$SWIFT_TOOLCHAIN_BIN/swift" ]; then
        echo "SWIFT_TOOLCHAIN_BIN must contain an executable swift binary." >&2
        return 1
    fi
    export PATH="$SWIFT_TOOLCHAIN_BIN:$PATH"
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift 6.4+ is required but swift is not on PATH." >&2
    echo "Install a compatible toolchain; see https://www.swift.org/install/." >&2
    echo "Then set SWIFT_TOOLCHAIN_BIN or update PATH and re-enter nix develop .#swift." >&2
    return 1
fi

if ! _dicom4ortho_swift_version=$(swift --version 2>&1); then
    printf 'Cannot execute the Swift toolchain: %s\n' "$_dicom4ortho_swift_version" >&2
    return 1
fi
if [[ ! "$_dicom4ortho_swift_version" =~ Swift\ version\ ([0-9]+)\.([0-9]+) ]] ||
   (( BASH_REMATCH[1] < 6 || (BASH_REMATCH[1] == 6 && BASH_REMATCH[2] < 4) )); then
    printf 'Swift 6.4+ is required; found: %s\n' "$_dicom4ortho_swift_version" >&2
    echo "Select a compatible toolchain with SWIFT_TOOLCHAIN_BIN or PATH." >&2
    return 1
fi

printf 'dicom4ortho Swift shell ready\n%s\nRun swift test from the repository root.\n' \
    "$_dicom4ortho_swift_version"
unset _dicom4ortho_swift_version
