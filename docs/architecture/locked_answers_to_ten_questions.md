> **Keel architecture note:** These locked decisions explain why Keel uses a compiler, a staged review lane, and plan-orchestrator as separate tools behind one artifact contract.

Here are the ten decisions I’d lock in.

## 1. `/autoplan` → `markdown_playbook_v1`: compiler required

Your read is correct. **`/autoplan` does not emit something close enough to PO `markdown_playbook_v1`. A compiler is needed.**

`/autoplan` is a review pipeline: it reads the CEO, design, engineering, and DX review skills, runs them sequentially, auto-decides intermediate questions using six principles, logs an audit trail, and surfaces taste/user-challenge decisions at a final approval gate. Its required outputs are things like “NOT in scope,” “What already exists,” registries, scorecards, diagrams, test-plan artifacts, cross-phase themes, and decision audit rows, not PO’s exact ordered execution table with `allowed_write_roots`, `requires_red_green`, `manual_gate`, `external_check`, and verification commands. ([GitHub][1])

**Decision:** build a compiler.

Name it:

```text
gstack_to_markdown_playbook_v1
```

It should consume:

```text
gstack design doc
+ /autoplan-reviewed plan
+ optional repo profile
+ optional human constraints
```

And emit:

```text
docs/playbooks/<slug>.playbook.md
```

The compiler’s job is not “summarize gstack.” Its job is to **translate product/review artifacts into PO-runnable rows**.

Minimum compiler output must include:

```text
## 1. Plan Context
## 2. Ordered Execution Plan
## 3. Phase Details
## 4. Shared Guidance
## 5. Risks And Contingencies
## 6. Immediate Next Actions
```

And the ordered execution table must include concrete values for:

```text
step_id
phase
action
why_now
owner_type
prerequisites
repo_surfaces
deliverable
exit_criteria
allowed_write_roots
requires_red_green
manual_gate
external_check
required_verification_commands
required_verification_artifacts
notes
```

## 2. SWR high-stakes task pack: generic, with project inputs

I agree with your default: **keep the SWR pack generic.**

SWR was designed as a manifest-driven, high-stakes staged workflow runner. A project-specific task pack would prematurely bake one repo’s domain into the mechanism. The better split is:

```text
Generic SWR task pack:
  gstack_design_to_po_playbook

Project-specific inputs:
  docs/briefs/<slug>.approved.md
  docs/gstack/<slug>.design.md
  docs/repo-profile.md
  docs/product/non-goals.md
  optional constraints file
```

Recommended generic SWR pack shape:

```text
automation/task_packs/gstack_design_to_po_playbook/
  shared_instructions.md
  workflows/gstack_design_to_po_playbook.workflow.json
  prompts/
    stage1_scope_and_source_authority.md
    stage2_repo_grounding_and_surfaces.md
    stage3_execution_plan_rows.md
    stage4_gates_risks_verification.md
    stage5_final_markdown_playbook_v1.md
  inputs/
    stage1.input_manifest.json
    ...
  schemas/
    stage1.schema.json
    ...
```

Suggested stages:

| Stage                              | Purpose                                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------------------- |
| 1. Scope and source authority      | Lock the approved gstack artifact, non-goals, product goal, and source precedence.           |
| 2. Repo grounding                  | Identify concrete repo surfaces, existing code, tests, docs, and likely write roots.         |
| 3. Execution row drafting          | Produce candidate PO rows with dependencies, deliverables, write roots, and red/green flags. |
| 4. Gate and verification hardening | Add manual gates, external evidence requirements, required commands, and risk notes.         |
| 5. Final playbook emission         | Emit parser-safe `markdown_playbook_v1` only. No implementation.                             |

**Counterargument to generic:** if one domain has recurring special constraints, such as health data, payments, crypto settlement, HIPAA-like privacy, or hardware integrations, you may eventually add a **project profile**. Do not fork the pack first. Add profile inputs first.

## 3. Approved playbooks location

Use:

```text
docs/playbooks/
```

Not `plans/`.

Reason: “playbook” is the actual PO contract. “Plan” is too vague and overlaps with gstack review plans, product plans, TODOs, launch plans, and SWR workflow plans.

Recommended repo layout:

```text
docs/
  briefs/
    <slug>.approved-brief.md

  gstack/
    <date>-<slug>-office-hours.md
    <date>-<slug>-autoplan.md

  playbooks/
    <slug>.playbook.md
    <slug>.playbook.meta.json
    index.md

  releases/
    <date>-<slug>-release.md

.local/
  automation/
    responses_runner_v2/...
    plan_orchestrator/...
```

Rules:

```text
~/.gstack/ = native gstack working memory and history
.local/ = generated run evidence, ignored
docs/gstack/ = promoted repo-visible gstack artifacts
docs/briefs/ = human-approved build briefs
docs/playbooks/ = human-approved PO execution contracts
```

Each approved playbook should begin with a provenance header:

```md
<!--
playbook_contract: markdown_playbook_v1
source_gstack_design: docs/gstack/2026-05-15-health-data-hub-office-hours.md
source_approved_brief: docs/briefs/health-data-hub.approved-brief.md
compiled_by: gstack_to_markdown_playbook_v1
compiled_at: 2026-05-15T...
human_approved_by: Aysajan
-->
```

## 4. High-stakes threshold

Your rule should stand: **the human owner decides when SWR is used.**

Do not hard-code automatic “forces SWR” behavior. That adds process where you explicitly want judgment.

Recommended policy:

```text
Default path:
  gstack → compiler → PO

Human-selected high-stakes path:
  gstack → SWR → PO
```

Add a non-binding “SWR suggested” rubric:

Use SWR when one or more are true:

```text
- security, auth, secrets, permissions, signing, payments, or settlement
- data migration, irreversible state, destructive write, or production config
- external compliance, customer-visible trust, health/financial/legal claims
- large multi-stage feature with ambiguous ordering
- ambiguous product scope where bad planning could waste multiple days
- broad repo blast radius
- any task where you want multi-agent staged review before execution
```

But the final rule is:

```text
SWR is never automatically forced. The human owner chooses.
```

## 5. PO manual-gate token and terminal

Decision:

```text
Owner: Aysajan
Terminal: human-held local terminal only
Token: human-owned, not available to worker agents or SWR/gstack wrappers
```

Recommended operating rule:

```text
No gstack skill.
No SWR supervisor.
No PO supervisor.
No compiler.
No agent wrapper.

may call:

python automation/run_plan_orchestrator.py mark-manual-gate ...
```

except through an explicit, immediate, human-performed command.

Use two terminals:

```text
Terminal A — human control:
  mark-manual-gate
  supervise run/resume when you personally choose

Terminal B — observation:
  supervise status
  status
  doctor
  artifact inspection
```

Also set the optional PO approval-token guard for real runs:

```bash
export PLAN_ORCHESTRATOR_MANUAL_GATE_TOKEN_SHA256=<sha256>
```

And record approvals with:

```bash
python automation/run_plan_orchestrator.py mark-manual-gate \
  --run-id <RUN_ID> \
  --item <ITEM_ID> \
  --decision approved \
  --by "Aysajan" \
  --note "Reviewed the gate packet and approve continuation." \
  --evidence-path docs/reviews/<slug>-<item>-signoff.md \
  --approval-token-file /secure/local/path/manual-gate-token.txt
```

## 6. Merge PO run branches: dedicated handoff checklist + `/ship` + `/land-and-deploy`

Best solution:

```text
PO produces the execution branch.
A tiny human/deterministic release checklist promotes it to a normal ship branch.
gstack /ship creates or updates the PR.
gstack /land-and-deploy merges and deploys the PR.
```

Do **not** let `/ship` operate directly on the internal PO run branch by default.

Why:

* PO run branches are execution-kernel branches, named like `orchestrator/run/<RUN_ID>`.
* `/ship` is a release-prep/PR workflow: it merges the base branch into the feature branch, runs tests, performs review, bumps version, updates CHANGELOG, pushes, and creates or updates a PR/MR. ([GitHub][2])
* `/land-and-deploy` is the actual merge/deploy workflow: it performs pre-merge readiness checks, asks for a merge decision, uses `gh pr merge --auto --delete-branch` or `gh pr merge --squash --delete-branch`, handles merge queues, and records deploy evidence. ([GitHub][3])
* `/ship` explicitly says never skip tests, never skip pre-landing review, never force-push, and never push without fresh verification evidence. That complements PO’s execution evidence, but it is not a replacement for PO state. ([GitHub][2])

Recommended handoff:

```bash
# 1. Inspect PO final state
python automation/run_plan_orchestrator.py status \
  --run-id <PO_RUN_ID> \
  --format json

python automation/run_plan_orchestrator.py doctor \
  --run-id <PO_RUN_ID> \
  --format json

# 2. Create normal release branch from PO run branch
git fetch origin
git checkout -b ship/<slug> orchestrator/run/<PO_RUN_ID>

# 3. Let gstack prepare PR
/ship

# 4. Let gstack merge/deploy after PR exists
/land-and-deploy
```

So the merge answer is:

```text
Manual git: only to create the ship branch from the PO run branch.
Dedicated checklist: yes, but only as a thin handoff checklist.
gstack /ship: create/update PR, tests, review, version, CHANGELOG, docs.
gstack /land-and-deploy: merge, deploy, verify, report.
Manual merge: no, unless gstack is blocked.
```

## 7. `allowed_write_roots` conventions

Principle:

```text
Use the narrowest repo-relative roots that let the item complete and verify.
Never use "." as a default.
Never include runtime/control/secrets roots.
```

Use 1–3 roots per item when possible.

Suggested conventions:

| Item type           | Typical allowed_write_roots                                                                                                                                     |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Docs-only           | `docs`; or exact containing dir like `docs/runbooks`                                                                                                            |
| README / changelog  | repo root only if necessary, but prefer `README.md` support only if PO allows file roots; otherwise use a docs/release item outside PO or a manual release step |
| Frontend component  | `src/components/<domain>`; `tests/<domain>`; maybe `src/app/<route>`                                                                                            |
| Frontend route/page | `src/app/<route>`; `src/components/<domain>`; `tests/e2e`                                                                                                       |
| Backend service     | `src/<service>`; `tests/<service>`                                                                                                                              |
| API endpoint        | endpoint directory; service directory; API tests directory                                                                                                      |
| CLI command         | `src/cli` or command package; `tests/cli`                                                                                                                       |
| Database migration  | `db/migrations`; `tests/migrations`; manual gate required                                                                                                       |
| Infra/config        | exact config directory such as `.github/workflows`, `deploy`, `infra`; manual gate required                                                                     |
| Security/auth       | exact auth/security module and tests; manual gate strongly recommended                                                                                          |
| Generated examples  | `examples/<feature>`; `tests/examples`                                                                                                                          |
| Release docs        | `docs/releases`; maybe `CHANGELOG.md` via `/ship`, not PO                                                                                                       |

Forbidden by convention:

```text
.local
.git
.codex
.claude
.mcp.json
ops/config
secrets
.env
.env.*
```

Compiler rule:

```text
If the compiler cannot identify a narrow root, it must emit a manual gate or block the playbook.
```

Bad:

```text
allowed_write_roots = src; tests; docs
```

Better:

```text
allowed_write_roots = src/features/mood-log; tests/features/mood-log
```

Best:

```text
allowed_write_roots = src/features/mood-log/api; tests/features/mood-log/test_mood_api.py
```

Use file-level roots only if PO’s scope checker handles them safely in your current implementation. If unsure, use the containing directory.

## 8. Minimum verification commands by item type

Universal rule:

```text
Every behavioral item needs at least one command that would fail without the change.
Every docs/artifact item needs at least artifact existence plus any configured lint/check.
Every security/data/infra item needs a negative test or dry-run check.
```

Recommended minimums:

| Item type                       |                    `requires_red_green` | Minimum required verification                                                                 |
| ------------------------------- | --------------------------------------: | --------------------------------------------------------------------------------------------- |
| Docs-only                       |                                 `false` | `test -f <doc_path>` plus existing doc lint if configured                                     |
| README/CHANGELOG/release note   |                                 `false` | `test -f README.md` / `test -f CHANGELOG.md`; maybe grep for required section                 |
| Python unit/backend             |                                  `true` | targeted `python -m pytest <test_file>`; plus `python -m pytest` when feasible                |
| Python typing/lint-sensitive    |                                  `true` | `python -m pytest <test_file>`; `ruff check .` if configured; `mypy` if configured            |
| Node/TS frontend                |                                  `true` | targeted test; `npm run typecheck`; `npm run test`; `npm run build`                           |
| React/Next route                |                                  `true` | `npm run typecheck`; `npm run test`; `npm run build`; E2E if route is user-visible            |
| API endpoint                    |                                  `true` | endpoint/unit test; integration/contract test; negative auth/validation test                  |
| CLI command                     |                                  `true` | command help exits 0; happy-path test; bad-input exit-code test                               |
| Database migration              |                                  `true` | migration dry run or test DB migration; rollback/down migration if supported; schema test     |
| Security/auth/permissions       |                                  `true` | positive access test; negative unauthorized test; regression test for forbidden path          |
| Secrets/config                  |                          usually `true` | config validation; secret scan if configured; no-secret grep for changed files                |
| Infra/deploy                    |                          usually `true` | provider-specific validate/plan/dry-run; never apply automatically unless explicitly in scope |
| Browser/UI behavior             |                                  `true` | unit/build checks plus `/qa` or Playwright/Cypress if available                               |
| SWR/PO/gstack workflow artifact | `false` or `true` depending on behavior | schema validation; dry-run; parser command; no live execution unless approved                 |
| Release/deploy                  |        `false` in PO, handled by gstack | `/ship`, `/land-and-deploy`, deploy report, canary if web                                     |

Concrete command examples the compiler can emit after detecting stack:

```bash
# Universal lightweight checks
git diff --check
test -f docs/playbooks/<slug>.playbook.md

# Python
python -m pytest tests/path/to/test_file.py
python -m pytest

# Node / TypeScript
npm run typecheck
npm run test
npm run build

# Frontend E2E, if configured
npm run test:e2e
npx playwright test

# CLI
python -m <package> --help
python -m pytest tests/cli/test_<command>.py

# PO playbook validation
python automation/run_plan_orchestrator.py list-items --playbook docs/playbooks/<slug>.playbook.md
python automation/run_plan_orchestrator.py doctor --playbook docs/playbooks/<slug>.playbook.md --format json

# SWR scaffold validation
python automation/run_responses_v2.py run \
  --root . \
  --workflow-file automation/task_packs/<pack>/workflows/workflow.json \
  --dry-run
```

For gstack-adjacent launch verification, use `/qa` for browser QA and `/canary` after deploy when there is a live URL. `/canary` is explicitly a post-deploy monitoring skill that watches the live app, captures screenshots, checks console errors, compares against baselines, and defaults to 10 minutes. ([GitHub][4])

## 9. gstack artifacts: both, with promotion rules

Use both:

```text
Keep native gstack artifacts in ~/.gstack.
Promote approved artifacts into the repo.
```

Reason:

* gstack itself expects project artifacts under `~/.gstack/projects/<repo_slug>/`; `/office-hours` says it saves a design doc and its context queries include recent design docs from `~/.gstack/projects/{repo_slug}/*-design-*.md`. ([GitHub][5])
* PO and SWR need tracked, repo-relative, durable artifacts. `~/.gstack` is not enough for reproducible execution.

Recommended promotion policy:

| Artifact                       | Native location                                    |              Repo copy? | Repo location                               |
| ------------------------------ | -------------------------------------------------- | ----------------------: | ------------------------------------------- |
| Raw `/office-hours` design doc | `~/.gstack/projects/...`                           |     Yes, after approval | `docs/gstack/<date>-<slug>-office-hours.md` |
| `/autoplan` reviewed plan      | plan file + `~/.gstack` task outputs               |     Yes, after approval | `docs/gstack/<date>-<slug>-autoplan.md`     |
| Approved build brief           | repo                                               |                     Yes | `docs/briefs/<slug>.approved-brief.md`      |
| SWR run outputs                | `.local/automation/responses_runner_v2/...`        |             No raw copy | promote terminal playbook only              |
| PO playbook                    | repo                                               |                     Yes | `docs/playbooks/<slug>.playbook.md`         |
| PO run evidence                | `.local/automation/plan_orchestrator/...`          |             No raw copy | optional summary in `docs/releases/`        |
| Deploy/canary reports          | `.gstack/deploy-reports`, `.gstack/canary-reports` | Yes for release records | `docs/releases/<date>-<slug>-launch.md`     |

Promotion rule:

```text
Only promoted artifacts become authoritative.
```

So `~/.gstack` is useful memory. `docs/briefs` and `docs/playbooks` are execution authority.

## 10. Launch-ready definition

Recommended definition:

```text
Launch-ready = there is evidence that the intended product scope works,
the repo change is reviewed and verified,
deployment is safe or unnecessary,
rollback/recovery is known,
and customer/user-facing communication is truthful.
```

Use five gates.

### Gate 1 — Product scope proof

Required:

```text
- approved brief exists
- non-goals are explicit
- MVP definition is explicit
- no unresolved user challenge from /autoplan
```

Evidence:

```text
docs/briefs/<slug>.approved-brief.md
docs/gstack/<date>-<slug>-autoplan.md
```

### Gate 2 — PO execution proof

Required:

```text
- all required PO items passed
- no unresolved escalated item
- no pending blocked_external item
- all manual gates approved by human
- PO doctor clean
```

Evidence:

```text
PO status JSON
PO doctor JSON
manual_gate records, if any
passed summaries
```

### Gate 3 — Test and review proof

Required:

```text
- required verification commands passed
- project-wide tests passed where feasible
- /review clean or findings explicitly handled
- browser QA proof for user-visible web changes
```

gstack `/review` is relevant here because it includes diff review, documentation staleness checks, adversarial review by Claude and Codex when available, and persistence of review results for `/ship` to recognize later. ([GitHub][6])

Evidence:

```text
test logs
PO verification reports
gstack review log
/qa report, if UI/web
```

### Gate 4 — Release and deploy proof

Required:

```text
- /ship created or updated PR from the final ship branch
- PR body reflects current diff
- VERSION/CHANGELOG/docs handled when applicable
- /land-and-deploy merged only after readiness check
- CI passed or deploy was explicitly not needed
- deploy report saved
```

`/ship` owns version/CHANGELOG/PR creation and documentation sync before PR creation; `/document-release` explicitly treats `/ship`’s CHANGELOG entry as source of truth and forbids clobbering existing entries. ([GitHub][2])

Evidence:

```text
PR URL
CI status
CHANGELOG entry
.gstack/deploy-reports/<date>-pr<nr>-deploy.md
docs/releases/<date>-<slug>-launch.md
```

### Gate 5 — Operational safety proof

Required:

```text
- rollback path known
- canary or health check run for web/deployed products
- user-facing release note is truthful
- residual risks listed
```

`/land-and-deploy` treats revert as an available failure path, performs single-pass verification, suggests `/canary` for extended monitoring, and records a deploy report with CI/deploy/staging/verification verdicts. ([GitHub][3])

Evidence:

```text
canary report, if web
rollback/revert note
release note
residual risk list
```

## Final locked answers

|  # | Decision                                                                                                                       |
| -: | ------------------------------------------------------------------------------------------------------------------------------ |
|  1 | `/autoplan` is not close enough. Build `gstack_to_markdown_playbook_v1`.                                                       |
|  2 | SWR pack should be generic: `gstack_design_to_po_playbook`, specialized by inputs.                                             |
|  3 | Approved playbooks live in `docs/playbooks/`; briefs in `docs/briefs/`; promoted gstack artifacts in `docs/gstack/`.           |
|  4 | Human owner decides SWR path. Add “SWR suggested” rubric, but no automatic forcing.                                            |
|  5 | Aysajan owns PO manual-gate token and human-held terminal. No agent gate writes.                                               |
|  6 | Use a release handoff checklist, branch from `orchestrator/run/<RUN_ID>`, then `/ship`, then `/land-and-deploy`.               |
|  7 | `allowed_write_roots` must be narrow, item-specific, repo-relative, and never runtime/secrets roots.                           |
|  8 | Behavioral items need red/green commands; docs need artifact/lint checks; security/data/infra need negative or dry-run checks. |
|  9 | Keep gstack artifacts in `~/.gstack`; promote approved artifacts into tracked repo docs.                                       |
| 10 | Launch-ready requires scope proof, PO execution proof, test/review proof, deploy proof, and operational safety proof.          |
