> **Keel architecture note:** This document describes the integration boundary between gstack, staged-workflow-runner, and plan-orchestrator. Paths are expressed relative to `$KEEL_ROOT`; daily commands live in `~/keel/bin/keel-*`.

<scratchpad>
- gstack = product cockpit, SWR = reviewed planning compiler, PO = execution kernel.
- Real bridge is SWR terminal `markdown_playbook_v1` → PO `--playbook`.
- Best integration is contract-native loose coupling, not merged supervisors.
- Human gates should remain human-only; no wrapper may self-approve.
</scratchpad>

<report>

# 1. Executive Summary

* **Recommendation: choose option (d): contract-native loose coupling.** Use gstack as the idea/product cockpit, SWR as an optional high-stakes playbook compiler, and PO as the execution kernel.
* **Do not merge the supervisors.** SWR and PO both have carefully separated engine/supervisor boundaries; merging them adds failure surface without improving launch quality.
* **Default path:** gstack → validated `markdown_playbook_v1` → PO. **High-stakes path:** gstack → SWR → `markdown_playbook_v1` → PO.
* **Delete first:** do not force every idea through SWR. Use SWR only when planning quality, auditability, or multi-stage review justifies the overhead.
* **Automate last:** first stabilize the artifact contracts and human gates; only then add gstack slash-command wrappers around validation and launch commands.

# 2. First-Principles Distillation

## gstack

**Core purpose:** gstack is the human-facing product workflow layer: it turns “I have an idea” into structured founder/design/engineering/QA/release conversations and artifacts. Publicly, gstack describes itself as a set of Claude Code slash-command specialists for CEO, design, engineering management, review, QA, security, and release work, all expressed as Markdown-oriented skills. ([GitHub][1]) Its `/office-hours` skill is explicitly for early idea exploration and saves a design doc; `/autoplan` runs a review gauntlet over a plan. ([GitHub][2])

**Invariants:** gstack should preserve product judgment, explicit user decisions, design provenance, and the distinction between planning/review/QA/release skills. It should not pretend that conversational review equals verified implementation.

**Boundaries:** gstack is not a reproducibility-first execution kernel, not a worktree isolation runtime, not a durable state machine for repo mutation, and not the owner of PO manual gates.

**Integration points:** design docs, approved plans, CEO/design/eng review outputs, QA reports, release docs, and launch/deploy checklists.

**Failure modes if integrated too deeply:** gstack could become a “god orchestrator,” hide SWR/PO terminal states behind friendly UX, or accidentally allow a conversational agent to approve a human-only gate.

## staged-workflow-runner / SWR

**Core purpose:** SWR is a high-stakes staged Responses workflow runner. It is optimized for evidence chain-of-custody: one workspace root, manifest-driven inputs, staged reviewed handoffs, schema-validated outputs, response checkpoints, review bundles, and optional supervisor policy.

**Invariants:** one exact workspace root; schema-versioned workflow/input/review/session artifacts; authority order; token preflight fail-closed unless explicitly skipped; no duplicate submit while a response may still complete; supervisor is additive policy, not the engine; read-only reviewers stay read-only; failed-no-artifact reruns require archive-before-rerun; incomplete/token-blocked stages do not auto-progress.

**Boundaries:** SWR plans and emits reviewed artifacts; it should not implement repo changes inside the planning workflow. The provided Round 4 scaffold says the terminal stage must emit a direct `markdown_playbook_v1` artifact for PO and must not implement the protocol work itself.

**Integration points:** gstack design doc or approved brief as Primary Job Input; SWR terminal `response.final.md` as PO playbook; SWR review bundles as planning provenance.

**Failure modes if integrated too deeply:** dual-root confusion, review-bundle drift, duplicated model submissions, supervisor/lane conflation, hidden reruns without archive, or SWR being used to execute what it was only supposed to plan.

## plan-orchestrator / PO

**Core purpose:** PO is the execution kernel for approved repo changes. It consumes one reviewed `markdown_playbook_v1`, normalizes it, runs one item at a time in isolated git worktrees, verifies, audits with Codex and Claude, triages findings, performs bounded fix/remediation loops, and terminates explicitly as `passed`, `awaiting_human_gate`, `blocked_external`, or `escalated`.

**Invariants:** one reviewed Markdown playbook as public input; one worktree per item attempt; verification before audit; frozen audit packet; dual audit over the same packet; deterministic findings merge; `run_state.json` remains kernel authority; manual gate is human-only; external evidence is local-file only; no agent-owned git operations; no fabricated evidence.

**Boundaries:** PO is not a planner, not a web-browsing agent, not a general chat shell, not an auto-approver, and not a second SWR-style Responses workflow engine.

**Integration points:** SWR terminal playbook or manually compiled gstack playbook; gstack launch/QA/release skills after PO produces a passed run branch; human gate review packets.

**Failure modes if integrated too deeply:** manual-gate self-approval, wrong branch shipped, PO state misrepresented by a wrapper, playbook contract drift, out-of-scope writes, or external evidence fabricated by an agent.

# 3. Integration Options Analysis

Scores: **5 = best**, **1 = worst**. For Failure Surface, **5 = lowest risk / smallest surface**.

| Option                                                    | Shape                                                                         | Quality / Reliability | Simplicity | Cycle Time | Failure Surface | Verdict                                                                                        |
| --------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------: | ---------: | ---------: | --------------: | ---------------------------------------------------------------------------------------------- |
| (a) Chain SWR → PO first, then integrate pair into gstack | SWR always emits PO playbook; gstack later wraps the pair                     |                     4 |          3 |          3 |               3 | Strong bridge, but overuses SWR for routine work. Good for high-stakes, too heavy as default.  |
| (b) Integrate each independently into gstack stages       | gstack calls SWR in some stages and PO in others                              |                     3 |          2 |          3 |               2 | Tempting UX, but creates multiple adapters, unclear state ownership, and wrapper-driven drift. |
| (c) Keep all three separate                               | Manual handoffs only; no explicit integration                                 |                     4 |          5 |          2 |               4 | Safest mechanically, but slow and copy/paste-prone. Good baseline, not a end-to-end engine.     |
| (d) Contract-native loose coupling                        | gstack cockpit → optional SWR compiler → PO execution kernel → gstack QA/ship |                     5 |          4 |          4 |               4 | Best balance. Only integrate through artifacts and validators; no merged supervisors.          |

# 4. Recommendation

Select **option (d): contract-native loose coupling**.

The end-to-end engine should be:

```text
Idea
  ↓
gstack /office-hours, /autoplan, review skills
  ↓
Approved product/design/build brief
  ↓
Optional SWR high-stakes playbook-emission workflow
  ↓
PO markdown_playbook_v1
  ↓
PO supervised item execution
  ↓
Human/external gates as needed
  ↓
gstack /review, /qa, /ship, /land-and-deploy, /document-release, /retro
  ↓
Launch-ready product + learning loop
```

## Musk-principles rationale

**Question every requirement.**
There is no requirement to merge codebases. There is no requirement for gstack to become a runtime state machine. There is no requirement for SWR to run on every feature. There is only one hard bridge worth preserving: **a reviewed `markdown_playbook_v1` into PO**.

**Delete the part/process.**
Delete the idea of a unified supervisor. Delete automatic manual-gate approval. Delete broad “gstack controls everything” wrappers. Delete SWR from low-stakes tasks. Delete any adapter that creates a second PO input contract.

**Simplify after deletion.**
Keep three roles:

* gstack = product cockpit.
* SWR = optional planning compiler for high-stakes plans.
* PO = execution kernel.

The integration is not “framework A imports framework B.” The integration is: **artifact A validates against contract B**.

**Accelerate cycle time after simplification.**
Fast path for ordinary work:

```text
gstack design/review → manually or automatically compiled PO playbook → PO run
```

High-stakes path:

```text
gstack approved brief → SWR reviewed playbook workflow → PO run
```

**Automate last.**
After 3–5 successful manual runs, add a gstack wrapper skill that does only this:

1. locate approved gstack artifact,
2. run SWR or playbook compiler,
3. run PO `list-items`,
4. run PO `doctor --playbook`,
5. show the human the exact PO launch command.

It must not call `mark-manual-gate`.

# 5. Deployment Walkthrough

## Phase 0 — Idea capture

User says:

```text
I have an idea about X.
```

Run in Claude Code:

```text
/office-hours
```

Artifact:

```text
~/.gstack/projects/<repo_slug>/<host>-<project>-design-YYYYMMDD-HHMMSS.md
```

Example from your local state:

```text
~/.gstack/projects/my-product/local-my-product-feature-design-YYYYMMDD-HHMMSS.md
```

Human gate:

```text
Approve / reject / revise the design doc.
```

## Phase 1 — Product and build review

Run either the explicit review gauntlet:

```text
/plan-ceo-review <design-doc.md>
/plan-design-review <design-doc.md>
/plan-eng-review <design-doc.md>
/plan-devex-review <design-doc.md>
```

Or the consolidated path:

```text
/autoplan <design-doc.md>
```

Artifact:

```text
docs/briefs/x_approved_build_brief.md
```

Minimum content required before PO/SWR handoff:

```text
- product goal
- non-goals
- repo surfaces
- MVP scope
- phase order
- explicit verification expectations
- human gates
- external evidence requirements
- launch definition
```

Human gate:

```text
The user approves the build brief.
```

## Phase 2A — Fast path: compile to PO playbook scaffold

Use this path for low/medium-risk work. In the current alpha, deterministic stub output is scaffold-only; non-dry-run stub output requires an explicit `--allow-stub-output` override and human review before PO execution.

Create:

```text
docs/playbooks/x_v1.playbook.md
```

Validate with PO. When the compiler is given `--plan-orchestrator-root`, this check runs automatically; otherwise run it before execution:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py list-items \
  --playbook docs/playbooks/x_v1.playbook.md

python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py doctor \
  --playbook docs/playbooks/x_v1.playbook.md \
  --format json
```

Artifact flowing forward:

```text
docs/playbooks/x_v1.playbook.md
```

Required contract:

```text
markdown_playbook_v1
```

## Phase 2B — High-stakes path: SWR emits PO playbook

Use this path when the plan is large, security-sensitive, expensive, ambiguous, or needs multi-agent staged review.

Initialize SWR supervisor session:

```bash
python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_supervisor_v2.py init-session \
  --root /path/to/product-repo \
  --clarified-task-brief docs/briefs/x_approved_build_brief.md \
  --summary "Emit a reviewed markdown_playbook_v1 for X v1."
```

Stage and examine the playbook-emission scaffold:

```bash
python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_supervisor_v2.py stage-scaffold \
  --root /path/to/product-repo \
  --session <SWR_SESSION_ID> \
  --scaffold-path automation/task_packs/gstack_design_to_po_playbook

python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_supervisor_v2.py examine-scaffold \
  --root /path/to/product-repo \
  --session <SWR_SESSION_ID> \
  --workflow-file automation/task_packs/gstack_design_to_po_playbook/workflows/gstack_design_to_po_playbook.workflow.json

python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_supervisor_v2.py dry-run-scaffold \
  --root /path/to/product-repo \
  --session <SWR_SESSION_ID> \
  --workflow-file automation/task_packs/gstack_design_to_po_playbook/workflows/gstack_design_to_po_playbook.workflow.json \
  --primary-job-input docs/briefs/x_approved_build_brief.md
```

Run the staged workflow:

```bash
python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_v2.py run \
  --root /path/to/product-repo \
  --workflow-file automation/task_packs/gstack_design_to_po_playbook/workflows/gstack_design_to_po_playbook.workflow.json \
  --primary-job-input docs/briefs/x_approved_build_brief.md \
  --skip-token-count \
  --wait
```

For review-required stages, classify and review:

```bash
python $KEEL_ROOT/tools/staged-workflow-runner/automation/run_responses_supervisor_v2.py classify \
  --root /path/to/product-repo \
  --session <SWR_SESSION_ID> \
  --run-dir <SWR_RUN_DIR> \
  --stage <stage_id>
```

Terminal artifact:

```text
<SWR_RUN_DIR>/stages/05_final_markdown_playbook/response.final.md
```

Promote it:

```bash
cp <SWR_RUN_DIR>/stages/05_final_markdown_playbook/response.final.md \
  docs/playbooks/x_v1.playbook.md
```

Validate with PO:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py list-items \
  --playbook docs/playbooks/x_v1.playbook.md

python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py doctor \
  --playbook docs/playbooks/x_v1.playbook.md \
  --format json
```

Human gate:

```text
The human confirms the promoted playbook is the approved execution source.
```

## Phase 3 — PO execution

Start supervised execution:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py supervise run \
  --playbook docs/playbooks/x_v1.playbook.md \
  --next
```

For controlled multi-item execution:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py supervise run \
  --playbook docs/playbooks/x_v1.playbook.md \
  --next \
  --auto-advance \
  --max-items 3
```

Inspect live state:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py supervise status \
  --run-id <PO_RUN_ID> \
  --format json \
  --exit-code

python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py status \
  --run-id <PO_RUN_ID> \
  --format json

python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py doctor \
  --run-id <PO_RUN_ID> \
  --format json
```

Artifacts:

```text
.local/automation/plan_orchestrator/runs/<PO_RUN_ID>/run_state.json
.local/automation/plan_orchestrator/runs/<PO_RUN_ID>/normalized_plan.json
.local/automation/plan_orchestrator/worktrees/<PO_RUN_ID>/item-<ITEM_ID>-attempt-<N>/
.local/ai/plan_orchestrator/runs/<PO_RUN_ID>/
```

## Phase 4 — Manual gate handling

If PO reaches `awaiting_human_gate`, the worker stops.

Human reviews:

```text
manual_gate.json
candidate patch
verification report
Codex audit report
Claude audit report
triage report
artifact manifest
```

Human records the decision from a human-held terminal:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py mark-manual-gate \
  --run-id <PO_RUN_ID> \
  --item <ITEM_ID> \
  --decision approved \
  --by "$USER" \
  --note "Reviewed the gate packet and approve continuation." \
  --evidence-path docs/reviews/x_<ITEM_ID>_signoff.md \
  --approval-token-file /secure/local/path/manual-gate-token.txt
```

Resume:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py supervise resume \
  --run-id <PO_RUN_ID>
```

## Phase 5 — External evidence handling

If PO reaches `blocked_external`, provide local evidence only:

```bash
python $KEEL_ROOT/tools/plan-orchestrator/automation/run_plan_orchestrator.py supervise resume \
  --run-id <PO_RUN_ID> \
  --external-evidence-dir /absolute/path/to/evidence
```

Artifact:

```text
.local/automation/plan_orchestrator/runs/<PO_RUN_ID>/items/<ITEM_ID>/attempt-<N>/external_evidence/
```

## Phase 6 — Launch readiness through gstack

After PO items pass, inspect the run branch:

```bash
git checkout orchestrator/run/<PO_RUN_ID>
```

Run gstack review and launch skills:

```text
/review
/qa http://localhost:3000
/ship
/land-and-deploy
/document-release
/retro
/learn
```

Artifacts:

```text
QA report
release notes
deployment record
retro / learnings
```

Final launch gate:

```text
Human decides whether the product is launch-ready.
```

# 6. Boundary Preservation Map

## gstack boundaries that must not be violated

* gstack must not become the authoritative execution state machine.
* gstack must not approve PO manual gates.
* gstack must not hide `awaiting_human_gate`, `blocked_external`, or `escalated` behind friendlier language.
* gstack design docs must be promoted into explicit approved briefs before SWR/PO execution.
* gstack launch skills must run against the correct PO run branch.

## SWR boundaries that must not be violated

* One exact workspace root per SWR run/session.
* Supervisor lane remains policy; engine lane remains mechanism.
* Review bundles must remain hash-validated.
* Read-only reviewers must not mutate source files.
* `failed_no_artifact` requires archive-before-rerun.
* Incomplete/token-blocked outputs must not auto-progress.
* Terminal playbook-emission workflows must emit `markdown_playbook_v1`; they must not implement the product work.
* SWR must not fabricate external evidence.

## PO boundaries that must not be violated

* One reviewed `markdown_playbook_v1` is the public input contract.
* `run_state.json` remains the sole authoritative kernel state.
* One worktree per item attempt.
* Verification must happen before Codex/Claude audit.
* Dual audit must review the same frozen packet.
* Manual gates are human-only.
* External evidence is local-file only.
* Allowed write roots must be enforced.
* No agent-owned git operations.
* No wrapper may call `mark-manual-gate` unless the human explicitly performs the decision in that moment.

## Bridge contract that must not drift

SWR output or any gstack-derived compiler output must validate as PO `markdown_playbook_v1`:

```text
## 1. Plan Context
## 2. Ordered Execution Plan
## 3. Phase Details
## 4. Shared Guidance
## 5. Risks And Contingencies
## 6. Immediate Next Actions
```

The ordered execution table must include the required columns:

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
```

It must not author reserved columns:

```text
change_profile
execution_mode
host_commands
```

# 7. Risk Register

| Risk                            | Where introduced                                                   | Severity | Mitigation                                                                                      |
| ------------------------------- | ------------------------------------------------------------------ | -------: | ----------------------------------------------------------------------------------------------- |
| Conflated supervisors           | gstack wrapper tries to control SWR and PO state                   |     High | Wrappers may launch/validate/status only; never reinterpret terminal states.                    |
| Manual-gate self-approval       | Agent calls PO `mark-manual-gate`                                  | Critical | Human-held terminal, approval token, explicit agent instruction: stop at gates.                 |
| Contract drift                  | SWR emits outdated `markdown_playbook_v1`                          |     High | Always run PO `list-items` and `doctor --playbook` before execution.                            |
| SWR overuse                     | Every small task goes through staged planning                      |   Medium | Fast path skips SWR unless high-stakes criteria apply.                                          |
| PO playbook too vague           | gstack design doc lacks repo paths or tests                        |     High | Require concrete repo surfaces, deliverables, write roots, and verification commands before PO. |
| Duplicate Responses submission  | SWR wrapper reruns while response may complete                     |     High | Use SWR resume/refresh semantics; do not duplicate-submit nonterminal stages.                   |
| Dual-root confusion             | SWR checkout and target repo split incorrectly                     |     High | Keep SWR first-release one-root contract; task pack lives under target root.                    |
| External evidence fabrication   | Agent invents evidence to unblock PO                               | Critical | External evidence must be a local directory supplied by human/operator.                         |
| Wrong branch shipped            | gstack `/ship` runs on main instead of PO run branch               |     High | Explicit `git checkout orchestrator/run/<PO_RUN_ID>` before launch skills.                      |
| Review laundering               | Consolidation or gstack review accepts unsupported recommendations |   Medium | Operator acceptance must include applied-change and validation evidence.                        |
| Hidden provenance loss          | Copying SWR terminal artifact without recording source             |   Medium | Record SWR run dir, stage id, response hash, and promotion note in playbook header.             |
| Scope creep                     | `/office-hours` vision turns into oversized PO plan                |   Medium | Require MVP/non-goal section and item-level `allowed_write_roots`.                              |
| Automation before understanding | Custom end-to-end script added too early                            |     High | Run manually first; automate only stable validation and launch commands.                        |

# 8. Open Questions

1. Does `/autoplan` already emit something close enough to `markdown_playbook_v1`, or is a compiler needed?
2. Should the high-stakes SWR task pack be generic, e.g. `gstack_design_to_po_playbook`, or project-specific?
3. Where should approved playbooks live: `docs/playbooks/`, `plans/`, or another tracked directory?
4. What qualifies as “high-stakes” and therefore requires SWR instead of direct gstack → PO?
5. Who owns the PO manual-gate approval token and human-held terminal?
6. Should PO run branches be merged by `/ship`, by a human git workflow, or by a dedicated release checklist?
7. What are the standard `allowed_write_roots` conventions for product repos?
8. What minimum verification commands are required for docs-only, UI, backend, deployment, and security-sensitive items?
9. Should gstack artifacts stay in `~/.gstack`, be copied into the repo, or both?
10. What is the launch-ready definition: passing tests only, QA proof, deployment proof, rollback proof, or customer-facing release proof?

# 9. Do Not Integrate Counter-Case

Leaving all three fully separate is acceptable if the goal is maximum mechanical safety and occasional use. It gives up:

* a smoother idea-to-launch flow,
* fewer copy/paste mistakes,
* repeatable playbook generation,
* a clear high-stakes planning lane,
* and a consistent launch checklist.

That tradeoff is acceptable for experiments. It is not ideal for a repeatable end-to-end engine.

The recommended middle ground is therefore: **do not merge, but do connect through explicit contracts and validators.**

# Final Decision

Build the end-to-end engine as:

```text
gstack cockpit
  → approved brief
  → optional SWR reviewed playbook compiler
  → PO supervised execution
  → gstack QA / ship / deploy / retro
```

The only hard technical integration should be:

```text
SWR terminal artifact or gstack compiler output
  must validate as
PO markdown_playbook_v1
```

Everything else should remain a human-visible handoff until the process has proven itself repeatedly.

</report>
::contentReference[oaicite:2]{index=2}

[1]: https://github.com/garrytan/gstack "GitHub - garrytan/gstack: Use Garry Tan's exact Claude Code setup: 23 opinionated tools that serve as CEO, Designer, Eng Manager, Release Manager, Doc Engineer, and QA · GitHub"
[2]: https://raw.githubusercontent.com/garrytan/gstack/main/office-hours/SKILL.md "raw.githubusercontent.com"
