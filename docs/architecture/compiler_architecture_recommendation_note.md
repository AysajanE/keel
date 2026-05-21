> **Keel architecture note:** This document specifies the compiler design. The compiler lives at `~/keel/tools/compiler/` when installed locally and is invoked through `keel-compile`.

## Recommendation: choose **Architecture 1 — Deterministic parser + LLM row-author**

Use the first architecture, with one small hardening: add an explicit intermediate IR called something like `gstack_plan_ir_v1`.

```text
Stage 1: Python parse → gstack_plan_ir_v1 JSON
Stage 2: bounded JSON row-author call → candidate PO rows JSON
Stage 3: Python schema + semantic validation + narrow-root checks
Stage 4: Python deterministic markdown_playbook_v1 emitter
Post-check: PO list-items + doctor
```

This is the right default because the compiler should be **fast, reproducible, debuggable, and contract-preserving**. The LLM should make semantic judgments, but Python should own parsing, validation, root safety, and final Markdown emission.

gstack artifacts are useful but not runtime contracts. `/autoplan` is a plan-review orchestration skill that discovers recent `~/.gstack` design docs and loads CEO/design/engineering/devex review skills from disk; it is not designed around PO’s `markdown_playbook_v1` table contract. ([GitHub][1]) The closest gstack gets is that `/plan-eng-review` synthesizes “Implementation Tasks” with files and verification hints, but those are still task-review artifacts, not PO rows with explicit `allowed_write_roots`, `manual_gate`, `external_check`, exact table headers, and parser-safe support sections. ([GitHub][2])

# Why Architecture 1 wins

| Architecture                                         | Verdict           | Why                                                                                                     |
| ---------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------- |
| **1. Deterministic parser + LLM-row-author**         | **Use this**      | Best reliability/complexity tradeoff. Python owns contracts; LLM only handles semantic mapping.         |
| 2. Pure LLM end-to-end with strict schema validation | Reject            | Minimal code, but opaque. Schema validates shape, not whether rows are grounded, narrow, or executable. |
| 3. Multi-pass LLM with explicit phase prompts        | Reject as default | Quality can be high, but it becomes SWR-lite. Too slow and too costly for the fast lane.                |
| 4. Defer compiler; build SWR pack first              | Reject as default | Kills the fast path. SWR should remain optional for human-selected high-stakes runs.                    |

# The exact architecture I would implement

## Stage 1 — Deterministic gstack parser

Input:

```text
docs/gstack/<slug>-office-hours.md
docs/gstack/<slug>-autoplan.md
optional: docs/briefs/<slug>.approved-brief.md
optional: repo metadata / stack detector output
```

Output:

```json
{
  "schema_version": "gstack_plan_ir_v1",
  "source_artifacts": [],
  "product_goal": "",
  "non_goals": [],
  "constraints": [],
  "recommended_approach": "",
  "implementation_tasks": [],
  "candidate_repo_paths": [],
  "verification_hints": [],
  "manual_gate_hints": [],
  "external_dependency_hints": [],
  "risk_hints": []
}
```

Parser responsibilities:

```text
- Extract sections from gstack Markdown deterministically.
- Extract Implementation Tasks from /autoplan and /plan-eng-review output.
- Extract Files / Verify hints when present.
- Preserve source artifact paths and hashes.
- Detect missing required inputs.
- Never invent repo paths.
```

This stage should be boring Python. It should be easy to unit-test with fixtures.

## Stage 2 — LLM row-author, constrained to JSON only

The LLM should receive:

```text
- gstack_plan_ir_v1
- PO markdown_playbook_v1 contract summary
- repo stack summary
- allowed_write_roots rules
- verification-command conventions
```

The LLM emits only:

```json
{
  "schema_version": "po_candidate_rows_v1",
  "rows": [
    {
      "step_id": "01",
      "phase": "scope lock",
      "action": "...",
      "why_now": "...",
      "owner_type": "operator",
      "prerequisites": "none",
      "repo_surfaces": ["docs/gstack/...", "src/..."],
      "deliverable": ["docs/playbooks/..."],
      "exit_criteria": "...",
      "allowed_write_roots": ["docs/playbooks"],
      "requires_red_green": false,
      "manual_gate": "none",
      "manual_gate_reason": "",
      "manual_gate_evidence": [],
      "external_check": "none",
      "external_dependencies": [],
      "consult_paths": [],
      "required_verification_commands": [],
      "required_verification_artifacts": [],
      "notes": []
    }
  ],
  "support_sections": {
    "plan_context": "",
    "phase_details": [],
    "shared_guidance": [],
    "risks_and_contingencies": [],
    "immediate_next_actions": ""
  },
  "compiler_warnings": []
}
```

Current `0.2.x` implementation uses one bounded whole-plan row-author call with
deterministic Python-built context, strict JSON output, Python validation, and
one repair attempt. **LLM per phase** remains a future optimization for large
plans with clear phase boundaries, where local failures and smaller retries
matter more than a single fast call:

```text
Phase: ingestion
Phase: core implementation
Phase: UX/API
Phase: verification
Phase: launch/docs
```

If adopted later, it should remain one authoring pass per phase rather than a
general multi-pass LLM workflow.

## Stage 3 — Deterministic validation

This is the most important stage.

Validation should fail closed on:

```text
- missing required PO columns
- reserved columns present
- absolute paths
- .local / .git / .codex / .claude / .mcp.json / secrets / ops/config paths
- empty repo_surfaces
- empty deliverable
- empty allowed_write_roots
- requires_red_green=true without required_verification_commands
- invalid manual_gate enum
- invalid external_check enum
- prerequisites that reference nonexistent step_id values
- duplicate step_id values
- deliverable outside allowed_write_roots
- write roots broader than necessary
- suspicious root like "." or "src" when a narrower root is inferable
```

Also run repo-aware checks:

```text
- consult paths exist or are explicitly marked as new deliverables
- allowed_write_roots are repo-relative
- verification commands match detected stack when possible
- docs-only rows do not pretend to have red/green tests
- behavioral rows have at least one command likely to fail before implementation
```

This stage should produce a validation report:

```text
docs/playbooks/<slug>.validation.json
```

If validation fails, the compiler should either stop or run **one bounded repair pass** where the LLM receives only the validation errors and candidate rows. Do not allow open-ended repair loops.

## Stage 4 — Deterministic Markdown emitter

The final Markdown should be emitted by Python, not the LLM.

That preserves exact table headers, escaping, section order, and parser compatibility.

Output:

```text
docs/playbooks/<slug>.playbook.md
docs/playbooks/<slug>.playbook.meta.json
docs/playbooks/<slug>.validation.json
```

Final smoke checks:

```bash
python automation/run_plan_orchestrator.py list-items \
  --playbook docs/playbooks/<slug>.playbook.md

python automation/run_plan_orchestrator.py doctor \
  --playbook docs/playbooks/<slug>.playbook.md \
  --format json
```

The compiler should not launch PO automatically. It should print the PO command and wait for the human.

# Why not Architecture 2?

Architecture 2 is:

```text
Stage 1: One LLM call
Stage 2: Python schema validate
Stage 3: Python emit markdown
```

This is tempting because it is minimal code. But it is the wrong failure profile.

It can pass schema validation while still producing bad execution rows:

```text
- plausible but nonexistent repo paths
- broad allowed_write_roots
- wrong red/green classification
- missing negative tests
- skipped external evidence gates
- rows that are too large for PO item execution
- hidden implementation assumptions
```

Strict schema validation catches malformed JSON. It does not catch “this row is operationally unsafe.”

Use this only as a throwaway prototype, not as the production compiler.

# Why not Architecture 3?

Architecture 3 is:

```text
Pass 1: scope + non-goals
Pass 2: repo surfaces
Pass 3: row drafting
Pass 4: gates + verification
```

This will probably produce high-quality playbooks, but it recreates the thing SWR is already meant to do: staged, reviewed, high-stakes artifact generation.

That blurs your intended architecture:

```text
Fast lane = compiler
High-stakes lane = SWR
Execution lane = PO
```

If the compiler becomes a multi-pass LLM pipeline, you get a slow lane hiding inside the fast lane.

Use Architecture 3 only as the design pattern for the **generic SWR task pack**, not for the normal compiler.

# Why not Architecture 4?

Architecture 4 says:

```text
No compiler.
Everything goes through SWR.
```

That is too much process as the default. It violates the “delete/simplify first” principle. You would lose the fast lane for simple gstack → PO execution.

SWR should remain available when you choose high-stakes planning, but it should not be mandatory.

# Implementation shape

Recommended package layout:

```text
automation/
  gstack_to_markdown_playbook_v1/
    __init__.py
    cli.py
    parse_gstack.py
    stack_detect.py
    ir_models.py
    row_models.py
    row_author.py
    validators.py
    emit_markdown.py
    provenance.py
    schemas/
      gstack_plan_ir_v1.schema.json
      po_candidate_rows_v1.schema.json
      compiler_validation_report_v1.schema.json
    prompts/
      row_author.md
      row_repair.md
    tests/
      fixtures/
      test_parse_gstack.py
      test_emit_markdown.py
      test_validate_rows.py
      test_end_to_end_fixture.py
```

CLI:

```bash
python automation/gstack_to_markdown_playbook_v1/cli.py compile \
  --repo-root . \
  --design docs/gstack/<slug>-office-hours.md \
  --autoplan docs/gstack/<slug>-autoplan.md \
  --approved-brief docs/briefs/<slug>.approved-brief.md \
  --out docs/playbooks/<slug>.playbook.md
```

Dry run:

```bash
python automation/gstack_to_markdown_playbook_v1/cli.py compile \
  --repo-root . \
  --design docs/gstack/<slug>-office-hours.md \
  --approved-brief docs/briefs/<slug>.approved-brief.md \
  --out docs/playbooks/<slug>.playbook.md \
  --dry-run
```

Expected compiler output:

```text
Wrote:
- docs/playbooks/<slug>.playbook.md
- docs/playbooks/<slug>.playbook.meta.json
- docs/playbooks/<slug>.validation.json

Next:
python automation/run_plan_orchestrator.py list-items --playbook docs/playbooks/<slug>.playbook.md
python automation/run_plan_orchestrator.py doctor --playbook docs/playbooks/<slug>.playbook.md --format json
```

# The key design rule

The LLM may author **candidate rows**.

It may not author:

```text
- final Markdown table formatting
- validation verdicts
- allowed root safety decisions without Python checks
- PO launch commands
- human gate approvals
```

Python owns those.

# Final decision

Use:

```text
Architecture 1: Deterministic parser + LLM-row-author
```

with this concrete flow:

```text
1. Python parse gstack artifacts → gstack_plan_ir_v1
2. bounded JSON row-author call → candidate PO rows JSON
3. Python validate schema, paths, roots, gates, verification, prerequisites
4. Python emit markdown_playbook_v1
5. Python run PO list-items + doctor
6. Human approves and launches PO
```

This gives you the fast lane you want without weakening PO’s execution contract or duplicating SWR.

[1]: https://github.com/garrytan/gstack/blob/main/autoplan/SKILL.md "gstack/autoplan/SKILL.md at main · garrytan/gstack · GitHub"
[2]: https://github.com/garrytan/gstack/blob/main/plan-eng-review/SKILL.md "gstack/plan-eng-review/SKILL.md at main · garrytan/gstack · GitHub"
