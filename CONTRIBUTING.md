# Contributing

Keel is a meta-repo. Contributions should keep that boundary intact.

## Ground Rules

- Do not vendor tool source into this repository.
- Keep installable tools declared in `tools.manifest.yaml`.
- Keep generated local files out of git: `tools/`, `keel.env`, `tools.lock`,
  `.env`, runtime directories, and private notes.
- Keep public docs readable for someone who has never used the local private
  setup.
- Keep the old project name out of public files.

## Local Checks

```bash
./install.sh --check
python3 scripts/manifest.py validate
python3 scripts/public_hygiene.py
bash -n bin/keel-* install.sh uninstall.sh
```

## Adding A Tool

1. Add a manifest entry with a canonical GitHub URL.
2. Prefer a release tag. Use a commit SHA only until a release tag exists.
3. Mark whether the tool is required or optional.
4. Add an install type and health check.
5. Document the tool in `docs/tools.md`.

Manifest entries are part of Keel's install-time trust boundary. Tool URLs,
refs, install types, and health checks must be reviewed as executable behavior:
`install.sh` clones the declared repository and runs the declared health check
after installation. Health checks are intentionally restricted to a small
single-line allowlist in `scripts/manifest.py`; expand that allowlist only with
the same care as shell-script changes.

Keel's manifest parser supports only the subset used by
`tools.manifest.yaml`: top-level `key: value` metadata and a `tools:` list of
flat single-line key/value fields. Do not add YAML anchors, nested mappings, or
block scalars without first replacing or extending the parser.

For `python-editable` tools, `install.sh` creates `tools/<name>/.venv` and the
matching Keel wrapper must prefer that venv Python when it exists. If a future
tool needs optional extras for its health check or normal wrapper execution,
add an explicit manifest field and installer support in the same change; do not
make undeclared extras an implicit install requirement.

## Public Docs

Raw local review notes belong in ignored `private/` storage. Public docs should
be written as maintained documentation, not as unedited local transcripts.
