# Quickstart

This path validates the Keel shell without requiring API keys.

## 1. Clone And Bootstrap

```bash
git clone https://github.com/AysajanE/keel.git ~/keel
cd ~/keel
./install.sh --skip-tools
source ~/keel/keel.env
```

`--skip-tools` is useful while the compiler repository is still private or when
you already have local tool checkouts under `tools/`.

If you move or rename the Keel checkout after bootstrapping, rerun
`./install.sh` from the new root. Python virtual environments and editable
installs record absolute paths, so the generated environment and tool venvs
must be refreshed after a move. Use `--update-tools` only when you also want
clean tool checkouts moved back to the manifest refs.

## 2. Inspect The Example Fixture

```bash
cd ~/keel/examples/hello-world
find docs -maxdepth 3 -type f | sort
```

The fixture contains:

- a small gstack design artifact
- a small autoplan artifact
- an approved brief
- an empty playbook output directory

## 3. Verify The Wrappers

From the Keel root:

```bash
keel-compile --help
keel-run --help
keel-doctor --help
keel-swr
```

If the tool checkouts are absent, commands that invoke those tools will fail
with missing-file errors. That is expected until `./install.sh` has populated
`tools/`.

## 4. First Real Compile

After the first-party tool repositories are installed:

```bash
export PRODUCT_REPO="$HOME/keel/examples/hello-world"

keel-compile compile \
  --repo-root "$PRODUCT_REPO" \
  --design "$PRODUCT_REPO/docs/gstack/hello-office-hours.md" \
  --autoplan "$PRODUCT_REPO/docs/gstack/hello-autoplan.md" \
  --approved-brief "$PRODUCT_REPO/docs/briefs/hello.approved-brief.md" \
  --out "$PRODUCT_REPO/docs/playbooks/hello.playbook.md" \
  --plan-orchestrator-root "$KEEL_PO_ROOT" \
  --human-approved-by "$USER" \
  --dry-run
```

The compiler currently has a scaffold/stub lane. Use dry-run mode until a real
row author is available and explicitly enabled.

Read next: `docs/concepts.md`, then
`docs/architecture/software_framework_integration.md`.
