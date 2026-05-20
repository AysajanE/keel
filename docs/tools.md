# Tools

Keel installs tools from `tools.manifest.yaml`. The manifest is the source of
truth for URL, ref, install type, required/optional status, and health check.

## compiler

- Repository: `https://github.com/AysajanE/gstack-playbook-compiler`
- Status: required, public, installable
- Manifest ref: `v0.1.0` (release tag)
- Purpose: converts reviewed gstack artifacts into `markdown_playbook_v1`
- Wrapper: `keel-compile`

The compiler is the fast lane. It runs a four-stage pipeline (parse, author,
validate, emit) and a plan-orchestrator contract post-check. Its row author is
a scaffold-only stub in `v0.1.0`; real LLM authors are reserved for future
releases.

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
