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

- Renamed the public project identity to Keel.
- Removed old wrapper names and old environment variables.
- Moved raw local review artifacts under ignored `private/` storage.
- Made `tools/` an ignored install target rather than a tracked source tree.

### Known Blockers

- `AysajanE/gstack-playbook-compiler` must be public before a fresh public
  install can succeed without maintainer access.
- First-party tools should be tagged and the manifest should move from commit
  pins to release tags before the first stable release.
- The manifest pins should describe one tested integration set; `tools.lock`
  records local resolved commits, but release refs are not yet tag-based.
