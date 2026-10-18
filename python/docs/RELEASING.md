# Python release checklist

Run these commands from the repository root. This checklist publishes the Python
package; it does not qualify the incomplete Swift port.

Repository version tags are also visible to SwiftPM. Before creating a tag, follow
the [shared release policy](../../README.md#releases-and-distribution) and coordinate
with the [Swift checklist](../../apple/Documentation/Releasing.md). Record the status of both
implementations in release notes. The current Swift port is not release-qualified;
Python-only validation must not be presented as qualification of both libraries.

The PyPI workflow builds `python/` and uploads its artifacts from root `dist/` on
matching pushes to `master`; it does not test or upload Swift. The Git tag is Swift's
distribution mechanism, with no mandatory registry upload.

1. Check version number and decide what version to release into.
2. Create `release`: e.g. `git flow release start v0.X.0`
3. Run `bumpversion --config-file python/.bumpversion.cfg major` (or `minor`/`patch`)
   and then `bumpversion --config-file python/.bumpversion.cfg release` as required.
   It commits version changes but does not create a tag; `git flow release finish`
   creates the tag in step 11.
4. `make clean`
5. `git merge master`: merge master into here, and fix merge errors.
6. Update release notes in `gh-pages` with major changes of this release. You might want to compare this release branch against master to see logs.
7. Check that README.md and python/README.md are still current. Packaging,
   version bumping, Make targets, and the commands below run from the repository
   root; Python packaging and sources are under `python/`. `python/.bumpversion.cfg` updates
   `python/dicom4ortho/config.py`, `python/pyproject.toml`, and `python/README.md`.
8. Rebuild the Python environment from scratch to verify no dependency errors:
   - **Nix users:** `nix develop` — the shell hook creates/updates `.venv` and installs `dicom4ortho[dev]` automatically. `dciodvfy` is also provided by the flake; skip step 9.
   - **Non-nix users:** delete and recreate the venv:
     ```
     rm -rf .venv
     python3 -m venv .venv
     source .venv/bin/activate
      pip install -e "./python[dev]"
     ```
9. **Non-nix users only:** `make install-dev` — installs `dicom3tools` (`dciodvfy`) required for DICOM validation. On Linux this uses `sudo apt-get install dicom3tools`; on macOS it downloads binaries. Nix users skip this — `dciodvfy` is provided by the flake.
10. Run `make check_codes`, then `make build`: make sure the committed terminology
    lock is current and all tests pass. Build will run lint and tests first.
    - **Nix users:** run inside the dev shell: `nix develop --command make build`
    - **Non-nix users:** `make build` (with `.venv` activated)
11. If all goes well, then merge branch into master: `git flow release finish`. The github actions will take care of deploying to PyPi.
12. On `develop`, run `bumpversion --config-file python/.bumpversion.cfg patch`
    to bump to the next `-dev` version.
13. `git push` on master and develop and tags.
14. Update documentation in `gh-pages` branch.

If there is a mistake in the uploaded version, and you need to re-upload, you will have to bump the patch version. PyPi will not allow to re-use the same version number, even if the package has been deleted via the Web GUI.
