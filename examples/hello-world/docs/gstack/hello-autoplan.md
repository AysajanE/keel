# hello autoplan

## Implementation Tasks

1. Add the hello-world playbook scaffold.
   Files: `docs/playbooks/hello.playbook.md`
   Verify: `python -m compileall .`

2. Validate the generated playbook contract.
   Files: `docs/playbooks/hello.playbook.md`
   Verify: `keel-run list-items --playbook docs/playbooks/hello.playbook.md --format json`

## Out Of Scope

- Network deploys
- Secret handling
- Manual gates
