# Keel

Keel is a local-first control plane for turning a reviewed product idea into an
auditable execution plan and then running that plan through small, independent
tools.

Keel is intentionally a meta-repo. It owns the public contract, wrappers,
installer, examples, and documentation. The actual tools are cloned into
`tools/` from their canonical repositories at install time and are not vendored
into this repository.

## Status

Keel is being prepared for a public `AysajanE/keel` release. The repository
shape is public-oriented, but one dependency is still a release blocker:

- `AysajanE/gstack-playbook-compiler` is currently private.
- `AysajanE/plan-orchestrator` is public.
- `AysajanE/staged-workflow-runner` is public.
- `garrytan/gbrain` is public and optional.

Until the compiler is public and all first-party tools are tagged, treat Keel as
an alpha local setup rather than a fully reproducible public install.

## What Keel Coordinates

```text
gstack                                  product thinking and planning skills
                                        live state stays under ~/.gstack

tools/compiler/                        gstack artifacts -> markdown_playbook_v1
tools/staged-workflow-runner/          high-stakes staged review lane
tools/plan-orchestrator/               reviewed playbook -> audited execution
tools/gbrain/                          optional third-party memory layer

bin/keel-compile                       compiler wrapper
bin/keel-run                           plan-orchestrator wrapper
bin/keel-doctor                        diagnostic shortcut
bin/keel-swr                           staged-workflow-runner wrapper
```

The shared artifact contract is `markdown_playbook_v1`. Keel keeps each tool at
arm's length and makes the contract the integration boundary.

## Install

```bash
git clone https://github.com/AysajanE/keel.git ~/keel
cd ~/keel
./install.sh
source ~/keel/keel.env
```

Optional gbrain integration:

```bash
./install.sh --with gbrain
```

The installer reads `tools.manifest.yaml`, clones selected tools into `tools/`,
writes a local `keel.env`, and records resolved commits in `tools.lock`.
`tools/`, `keel.env`, and `tools.lock` are ignored by git.

For local development against already-present tool checkouts, run:

```bash
./install.sh --skip-tools
source ~/keel/keel.env
```

## Daily Commands

```bash
keel-compile --help
keel-run --help
keel-doctor --help
keel-swr
```

Set the product repository per shell:

```bash
export PRODUCT_REPO="$HOME/path/to/product-repo"
```

Compile a reviewed gstack brief into a playbook:

```bash
keel-compile compile \
  --repo-root "$PRODUCT_REPO" \
  --design "$PRODUCT_REPO/docs/gstack/<slug>-office-hours.md" \
  --autoplan "$PRODUCT_REPO/docs/gstack/<slug>-autoplan.md" \
  --approved-brief "$PRODUCT_REPO/docs/briefs/<slug>.approved-brief.md" \
  --out "$PRODUCT_REPO/docs/playbooks/<slug>.playbook.md" \
  --plan-orchestrator-root "$KEEL_PO_ROOT" \
  --human-approved-by "$USER" \
  --dry-run
```

Validate a playbook:

```bash
keel-run list-items --playbook "$PRODUCT_REPO/docs/playbooks/<slug>.playbook.md"
keel-doctor --playbook "$PRODUCT_REPO/docs/playbooks/<slug>.playbook.md" --format json
```

Run one approved item:

```bash
cd "$PRODUCT_REPO"
export PLAN_ORCHESTRATOR_CLEAN_ENV_CONFIRMED=1
keel-run supervise run --playbook docs/playbooks/<slug>.playbook.md --next
```

Record a manual gate from a human-held terminal only:

```bash
keel-run mark-manual-gate \
  --run-id <RUN_ID> \
  --item <ITEM_ID> \
  --decision approved \
  --by "$USER" \
  --note "Reviewed the gate packet and approve continuation." \
  --evidence-path docs/reviews/<slug>-<item>-signoff.md \
  --approval-token-file /secure/local/path/manual-gate-token.txt
```

## Repository Layout

```text
keel/
├── bin/                         daily wrappers
├── docs/                        public docs and architecture notes
├── examples/hello-world/        no-key starter fixture
├── scripts/                     manifest and hygiene checks
├── tools.manifest.yaml          canonical tool sources and install metadata
├── keel.env.template            sourceable env template
├── install.sh                   local bootstrap
├── uninstall.sh                 local cleanup helper
└── tools/                       ignored install target
```

## Public-Repo Boundaries

- Do not vendor first-party or third-party tools into Keel.
- Do not commit `tools/`, `.env` files, `keel.env`, `tools.lock`, runtime
  artifacts, or private review notes.
- Keep `~/.gstack` as live runtime data. It is not part of this repository.
- Keep raw local review and setup notes under `private/`; publish only sanitized
  docs and architecture decisions.
- Do not keep compatibility entry points for the old name.

## Where To Read Next

- `docs/quickstart.md`
- `docs/concepts.md`
- `docs/tools.md`
- `docs/integrations/gbrain.md`
- `docs/architecture/software_framework_integration.md`
- `docs/diagrams/keel-explained.html`

## License

Keel is released under the MIT License. Each installed tool carries its own
license in its canonical repository.
