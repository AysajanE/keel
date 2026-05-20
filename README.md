# Keel

> **A local-first toolchain that ships AI-written code you can actually trust.**
> Idea → reviewed plan → audited execution → shipped PR — with humans
> holding every safety boundary.

Keel coordinates AI coding agents through a strict pipeline. You write the
product idea in plain English. A series of small tools turn it into a precise
execution recipe, run it one step at a time inside isolated git worktrees,
get the change reviewed by two independent AIs (Codex and Claude) looking at
the same evidence, and stop at every gate that requires your signoff.

Nothing ships without a written audit trail. No agent can approve its own
work. No agent can fabricate evidence. No code change can write to a file
the plan didn't declare.

```text
idea ──▶ gstack ──▶ compiler ──▶ markdown_playbook_v1 ──▶ plan-orchestrator ──▶ gstack ──▶ shipped
        (cockpit)   (translate)   (one shared contract)      (executor)         (cockpit)
                                                            worktree + dual-AI audit
```

For the full picture with eight interactive diagrams, open
**[`docs/diagrams/keel-explained.html`](docs/diagrams/keel-explained.html)**.

## Why Keel exists

If you've used coding agents for anything serious, you've hit the same four
problems:

- **Conversation drifts.** The agent has good ideas, asks good questions, then
  forgets what you decided three turns ago.
- **Execution is opaque.** Code lands but you don't know whether tests pass,
  what files got touched, or what was skipped.
- **Tools entangle.** Every "AI dev platform" wants to own the whole pipeline,
  so when one piece breaks, everything breaks.
- **Safety is implicit.** You're trusting an agent not to push secrets, not to
  rewrite files outside its scope, not to silently approve its own changes.

Keel addresses each one with a structural fix, not a prompt:
written contracts between tools, isolated worktrees per change, dual independent
audits, and human-only gates that no wrapper can bypass.

## Who Keel is for

**Use Keel when:**
- You're building a real product with AI agents and want every change reviewable.
- You care more about "predictable + auditable" than "fast + magical."
- You're comfortable running local Python and Claude Code.
- You want each shipped PR to come with a written audit trail.

**Keel is not the right fit when:**
- You want a hosted SaaS — Keel is local-first by design.
- You're doing one-off scripts or single-file changes — the overhead isn't worth it.
- You don't want a human in the loop — Keel keeps you in the loop on purpose.

## Status

Alpha, but the end-to-end pipeline works today and every tool is public and
installable:

| Tool | Status |
|------|--------|
| [`gstack-playbook-compiler`](https://github.com/AysajanE/gstack-playbook-compiler) | Public, installable, tagged `v0.1.0` |
| [`plan-orchestrator`](https://github.com/AysajanE/plan-orchestrator) | Public, installable, functional |
| [`staged-workflow-runner`](https://github.com/AysajanE/staged-workflow-runner) | Public, installable, functional |
| [`gbrain`](https://github.com/garrytan/gbrain) | Optional, public, third-party |

A fresh `./install.sh` clones the three required tools from their public repos;
`./install.sh --with gbrain` adds the optional memory layer. "Alpha" refers to
the compiler's row author being a scaffold-only stub today, not to install
reproducibility. See [`CHANGELOG.md`](CHANGELOG.md) for what's landed.

## Requirements

- Git and a POSIX shell.
- Python 3.10 or newer.
- Codex CLI and Claude Code, installed and authenticated, before real
  plan-orchestrator execution.
- Optional: Bun, only if you install the `gbrain` integration.
- Optional: `OPENAI_API_KEY`, only for live staged-workflow-runner Responses
  runs. The install and hello-world smoke path do not need API keys.

## Your first five minutes

The bundled `hello-world` fixture lets you exercise the wrappers without any
API keys.

```bash
# 1. Clone and bootstrap (clones required tools into tools/)
git clone https://github.com/AysajanE/keel.git ~/keel
cd ~/keel
./install.sh
source ~/keel/keel.env

# 2. Sanity-check the wrappers
keel-smoke

# 3. Inspect the fixture
cd ~/keel/examples/hello-world
find docs -maxdepth 3 -type f | sort
```

To validate only the Keel shell without cloning any tools, run
`./install.sh --skip-tools`, source `keel.env`, then run
`keel-smoke --shell-only`. Then open
[`docs/diagrams/keel-explained.html`](docs/diagrams/keel-explained.html) to walk
through what each command does and why.

## The four core tools

Keel itself is a **meta-repo** — it ships wrappers, an installer, a manifest,
and docs, but never vendors the tools themselves. The tools live in their own
canonical repos and are cloned in at install time.

| Tool | Job | Wrapper |
|------|------|---------|
| **gstack** (third-party, by Garry Tan) | Product cockpit. Turns ideas into reviewed design briefs, then ships the result | Used inside Claude Code as `/office-hours`, `/autoplan`, `/ship`, etc. |
| **compiler** | Translates a reviewed brief into `markdown_playbook_v1` — a strict execution recipe | `keel-compile` |
| **plan-orchestrator** | Executes the playbook one item at a time in isolated worktrees with dual-AI audit | `keel-run` / `keel-doctor` |
| **staged-workflow-runner (SWR)** | Optional high-stakes lane: 5 reviewed Responses calls produce a playbook for risky work | `keel-swr` |

Plus one optional integration: [`gbrain`](https://github.com/garrytan/gbrain),
a local-first memory layer (`./install.sh --with gbrain`).

## Two contracts hold it together

| Layer | Contract | Purpose |
|-------|----------|---------|
| Install-time | [`tools.manifest.yaml`](tools.manifest.yaml) | Declares which tool versions this machine trusts (URLs, pinned commits, install_type, health checks) |
| Runtime | `markdown_playbook_v1` | The only artifact compiler/SWR may emit, the only artifact plan-orchestrator consumes |

Splitting the two means a new tool version doesn't force a re-validation of
every playbook, and a new playbook doesn't force a re-install. Each kind of
change touches one contract.

## Install

```bash
git clone https://github.com/AysajanE/keel.git ~/keel
cd ~/keel
./install.sh
source ~/keel/keel.env
```

The installer reads `tools.manifest.yaml`, clones the declared tools into
`tools/`, writes a local `keel.env`, and records resolved commits in
`tools.lock`. `tools/`, `keel.env`, and `tools.lock` are gitignored.

Optional gbrain integration:

```bash
./install.sh --with gbrain
```

For local development against an existing checkout of the tools, run
`./install.sh --skip-tools`. To install only the public tools (skipping any
tool a future manifest marks private), run `./install.sh --public-only`.

## Daily commands

Set the product repository per shell:

```bash
export PRODUCT_REPO="$HOME/path/to/product-repo"
```

**Compile a reviewed brief into a playbook (in dry-run, today's alpha mode):**

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

The three input files are gstack outputs from `/office-hours` and `/autoplan`.
See the [explainer](docs/diagrams/keel-explained.html) for the full lifecycle.

**Validate a playbook before running it:**

```bash
keel-run  list-items --playbook "$PRODUCT_REPO/docs/playbooks/<slug>.playbook.md"
keel-doctor          --playbook "$PRODUCT_REPO/docs/playbooks/<slug>.playbook.md" --format json
```

**Execute the next approved item:**

```bash
cd "$PRODUCT_REPO"
export PLAN_ORCHESTRATOR_CLEAN_ENV_CONFIRMED=1
keel-run supervise run --playbook docs/playbooks/<slug>.playbook.md --next
```

**Record a manual gate (only from a human-held terminal — no agent may do this):**

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

## Repository layout

```text
keel/
├── bin/                         daily wrappers (keel-smoke, keel-compile, keel-run, keel-doctor, keel-swr)
├── docs/                        public docs, architecture notes, and the HTML explainer
├── examples/hello-world/        no-key starter fixture
├── scripts/                     manifest validator and public hygiene checks
├── tools.manifest.yaml          canonical tool sources and install metadata
├── keel.env.template            sourceable env template
├── install.sh                   local bootstrap
├── uninstall.sh                 local cleanup helper
└── tools/                       ignored install target (populated by install.sh)
```

## Public-repo boundaries

- Tools are never vendored — they live in their canonical repos.
- `tools/`, `keel.env`, `tools.lock`, `.env*`, runtime artifacts, and private
  review notes are gitignored.
- `~/.gstack/` is gstack's live runtime memory and stays outside this repo.
- Raw local notes go under `private/`; only sanitized, maintained docs ship publicly.

## Read next

- **[`docs/diagrams/keel-explained.html`](docs/diagrams/keel-explained.html)** — the full guided walkthrough with eight interactive diagrams. Start here if you want the full picture.
- [`docs/quickstart.md`](docs/quickstart.md) — first local checks, no API keys.
- [`docs/concepts.md`](docs/concepts.md) — the contract boundaries.
- [`docs/tools.md`](docs/tools.md) — what each tool does and where it lives.
- [`docs/integrations/gbrain.md`](docs/integrations/gbrain.md) — optional memory layer.
- [`docs/architecture/`](docs/architecture/) — the locked design decisions behind the architecture.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to add a tool or contribute changes.

## License

Keel is MIT-licensed. Each installed tool carries its own license in its
canonical repository.
