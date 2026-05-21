# Keel Changelog

All notable changes to Keel are documented here.

This changelog starts fresh for the public `AysajanE/keel` release line. Older
local renames and private setup history are intentionally excluded from the
public changelog.

## Unreleased

### Added

- Prepared Keel as a public meta-repo instead of a live tool-vendoring
  directory.
- Added `tools.manifest.yaml` as the source of truth for installable tools.
- Added `install.sh` and `uninstall.sh` for local bootstrap and cleanup.
- Added sourceable `keel.env.template`; generated `keel.env` remains local.
- Added first-class wrappers: `keel-compile`, `keel-run`, `keel-doctor`, and
  `keel-swr`.
- Added public docs: quickstart, concepts, tools, and gbrain integration notes.
- Added a no-key `examples/hello-world` fixture.
- Added CI, issue templates, pull request template, security policy, and
  contribution guidance.

### Changed

- Published `AysajanE/gstack-playbook-compiler` as a public repository tagged
  `v0.1.0`. The compiler manifest entry is now `visibility: public`,
  `public_status: installable`, and pinned to a release tag instead of a commit
  SHA. A fresh `./install.sh` now clones all four tools from public
  repositories with no maintainer access required.
- Bumped the compiler manifest pin to `v0.2.0`, which ships the model-backed
  Step 2 row author (the `v0.1.0` compiler was scaffold-only). A fresh
  `./install.sh` now installs a compiler that produces real execution rows.
- Renamed the public project identity to Keel.
- Removed old wrapper names and old environment variables.
- Moved raw local review artifacts under ignored `private/` storage.
- Made `tools/` an ignored install target rather than a tracked source tree.
- Propagated the install-time Python selection through generated `keel.env`
  for non-venv tool wrappers and health checks.
- Documented that tool virtual environments must be refreshed after moving the
  Keel checkout.

### Remaining Before A Stable Release

- `plan-orchestrator` and `staged-workflow-runner` are still commit-pinned;
  they should be tagged so the manifest can move them from commit SHAs to
  release tags. The compiler already pins to a release tag (`v0.2.0`).
- Once every first-party tool is tag-pinned, `./install.sh --release-gate`
  should pass cleanly and become a CI gate.
- The manifest pins should describe one tested integration set; `tools.lock`
  records local resolved commits for reproducibility.
