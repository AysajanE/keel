# gbrain Integration

gbrain is an optional third-party memory layer. Keel does not vendor it and does
not require it for basic wrapper, manifest, or playbook workflows.

Install it through Keel only if you want a local memory system available beside
the planning and execution tools:

```bash
cd ~/keel
./install.sh --with gbrain
```

The manifest pins a specific gbrain commit. The installer clones the upstream
repository into `tools/gbrain` and runs the declared install step.

## Recommended Starting Topology

Use gbrain locally first:

- local database
- local stdio MCP server
- no public HTTP exposure on day one
- explicit API-key handling only if you enable embedding providers that require
  one

OpenAI embeddings can improve semantic retrieval, but a local-first Keel setup
should not make gbrain a hard dependency.

## Boundary

gbrain remains owned by its upstream repository. Keel's responsibility is only
to declare an optional install path and document how it fits into a local
workflow.
