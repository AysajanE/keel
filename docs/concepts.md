# Concepts

## Keel Is A Meta-Repo

Keel is not the compiler, the executor, or the memory system. It is the
coordination layer around those tools:

- stable command wrappers
- a shared manifest
- a sourceable env file
- examples
- public documentation
- CI checks that keep the public surface clean

The tools remain in their own repositories.

## The Contract Boundary

The main handoff artifact is `markdown_playbook_v1`.

The compiler and staged review lane produce it. plan-orchestrator consumes it.
That contract is more important than any one implementation because it lets the
tools remain replaceable.

## Required And Reserved Columns

The execution table's author-required columns are:

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

Reserved columns are derived by plan-orchestrator and should not be authored:

```text
change_profile
execution_mode
host_commands
```

## Local-First Runtime Boundaries

Keel treats local state and source code as separate things:

- `tools/` is an ignored install target for source checkouts.
- `~/.gstack` is live runtime memory and is not mirrored into Keel.
- `private/` is ignored storage for local review notes and setup artifacts.
- product repositories hold their own gstack artifacts, briefs, and playbooks.

## Human Gates

Keel wrappers do not remove human approval boundaries. Manual gates must be
recorded by a human from a human-held terminal, with explicit evidence.
