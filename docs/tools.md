# Tools

Keel installs tools from `tools.manifest.yaml`. The manifest is the source of
truth for URL, ref, install type, required/optional status, and health check.

## Keel wrappers

- `keel-smoke` checks the first-time install surface and a no-key
  hello-world compile/list flow.
- `keel-compile` invokes the gstack-to-playbook compiler.
- `keel-run` invokes plan-orchestrator.
- `keel-doctor` is a shortcut for plan-orchestrator diagnostics.
- `keel-swr` invokes staged-workflow-runner modes.

## compiler

- Repository: `https://github.com/AysajanE/gstack-playbook-compiler`
- Status: required, public, installable
- Manifest ref: `v0.2.0` (release tag)
- Purpose: converts reviewed gstack artifacts into `markdown_playbook_v1`
- Wrapper: `keel-compile`

The compiler is the fast lane. It runs a four-stage pipeline (parse, author,
validate, emit) and a plan-orchestrator contract post-check. Stage 2 supports a
scaffold-only `stub` lane plus JSON-only model-backed authors through
`external-json`, `claude`, and `codex` command aliases. Model-backed row authors
run outside the product repo cwd by default, produce candidate JSON only, and
get one bounded repair attempt before Python validation fails closed. The
compiler also removes obvious repo/path/secret environment variables from
model-backed row-author commands unless the debug-only inherit-env escape hatch
is used.

plan-orchestrator intentionally accepts some broad roots for hand-authored
playbooks. The compiler is stricter for model-authored rows: it rejects bare
`src`, `tests`, and `test` write roots and requires narrow roots derived from
declared deliverables.

## plan-orchestrator

- Repository: `https://github.com/AysajanE/plan-orchestrator`
- Status: required, public
- Purpose: normalizes, inspects, and executes reviewed playbooks
- Wrapper: `keel-run`
- Shortcut: `keel-doctor`

plan-orchestrator is the execution kernel. Keel invokes it through wrappers and
does not vendor it.

## staged-workflow-runner

- Repository: `https://github.com/AysajanE/staged-workflow-runner`
- Status: required, public
- Purpose: runs high-stakes staged review workflows
- Wrapper: `keel-swr`

The public manifest currently pins the public `origin/main` commit, not the
local ahead commit in this machine's checkout.

## gbrain

- Repository: `https://github.com/garrytan/gbrain`
- Status: optional, public, third-party
- Manifest ref: `3933eb6a7915cb5495b8057b75567e2b1588b5ac`
- Purpose: local-first memory and retrieval layer for agents
- Install: `./install.sh --with gbrain`

Keel documents gbrain as an optional integration, not a required core
dependency.
