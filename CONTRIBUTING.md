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

## Public Docs

Raw local review notes belong in ignored `private/` storage. Public docs should
be written as maintained documentation, not as unedited local transcripts.
