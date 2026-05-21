# Quickstart

This path validates a fresh Keel checkout without requiring API keys. It clones
the required public tools, checks the wrappers, and compiles the bundled
hello-world fixture in dry-run mode.

## 1. Clone And Bootstrap

```bash
git clone https://github.com/AysajanE/keel.git ~/keel
cd ~/keel
./install.sh
source ~/keel/keel.env
```

`./install.sh` clones the required public tools into `tools/`, installs Python
tool dependencies in local virtual environments, writes `keel.env`, and records
the resolved commits in `tools.lock`.

If you only want to validate the Keel repo shell without cloning tools, run:

```bash
./install.sh --skip-tools
source ~/keel/keel.env
keel-smoke --shell-only
```

If you move or rename the Keel checkout after bootstrapping, rerun
`./install.sh` from the new root. Python virtual environments and editable
installs record absolute paths, so the generated environment and tool venvs
must be refreshed after a move. Use `--update-tools` only when you also want
clean tool checkouts moved back to the manifest refs.

## 2. Run The First-Time Smoke Check

```bash
keel-smoke
```

The smoke check verifies the manifest, public hygiene, wrapper syntax, required
tool checkouts, wrapper help surfaces, and a temporary hello-world compile/list
flow. It does not run a plan-orchestrator mutation or submit an OpenAI Responses
workflow.

If `keel-smoke` warns that Codex CLI or Claude Code is missing, install and
authenticate those before real plan-orchestrator execution. The no-key compile
and list checks can still pass without OpenAI API keys.

## 3. Inspect The Example Fixture

```bash
cd ~/keel/examples/hello-world
find docs -maxdepth 3 -type f | sort
```

The fixture contains:

- a small gstack design artifact
- a small autoplan artifact
- an approved brief
- an empty playbook output directory

## 4. First Real Compile

After the first-party tool repositories are installed, the no-key path remains
dry-run scaffold output:

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

For model-backed row authoring, promote the gstack artifacts into the product
repo and run a JSON-only author command:

```bash
keel-compile compile \
  --repo-root "$PRODUCT_REPO" \
  --design "$PRODUCT_REPO/docs/gstack/hello-office-hours.md" \
  --autoplan "$PRODUCT_REPO/docs/gstack/hello-autoplan.md" \
  --approved-brief "$PRODUCT_REPO/docs/briefs/hello.approved-brief.md" \
  --out "$PRODUCT_REPO/docs/playbooks/hello.playbook.md" \
  --row-author external-json \
  --row-author-command "claude -p" \
  --plan-orchestrator-root "$KEEL_PO_ROOT" \
  --human-approved-by "$USER"
```

Model-backed row authors are planning calls only: the compiler sends a prompt
on stdin, expects raw `po_candidate_rows_v1` JSON on stdout, runs the command
from an isolated temporary cwd by default, validates and repairs at most once,
and emits Markdown itself.

Read next: `docs/concepts.md`, then
`docs/architecture/software_framework_integration.md`.
