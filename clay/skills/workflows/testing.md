# Testing Workflows

## Clay CLI

You have access to the `clay` CLI for running and inspecting workflow test runs.
Invoke it as `clay …` (no path prefix, no `python3`). In Claude Code it is on your
PATH automatically; in Codex/Cursor, run the `setup` skill once to install it.

Requires a signed-in session (`clay login`; run the `setup` skill if `clay whoami`
fails on auth). The workspace is resolved from the stored session, so there is no
workspace id to pass.

Every command prints JSON to stdout on success and a typed error envelope to
stderr on failure, with categorical exit codes (0 ok, 2 validation, 3 auth,
5 network, 6 not-found). Pipe stdout to `jq`.

## Commands

```bash
# Start a test run (input JSON on stdin via --input -; defaults to {})
echo '{"key":"value"}' | clay workflows runs test <workflowId> --input -
clay workflows runs test <workflowId>                  # no inputs

# Status / progress for a run
clay workflows runs get <workflowId> <runId>           # header + progress + map/reduce nodes
clay workflows runs get <workflowId> <runId> --nodes   # include every node
clay workflows runs get <workflowId> <runId> --verbose # + full inputs/outputs, mappings, entry steps
clay workflows runs get <workflowId> <runId> --node-id <nodeId>  # isolate one node, full map/reduce results

# List/filter the individual execution steps
clay workflows runs steps <workflowId> <runId>
clay workflows runs steps <workflowId> <runId> --status failed
clay workflows runs steps <workflowId> <runId> --node-id <nodeId>

# Pause / resume a run
clay workflows runs pause <workflowId> <runId>
clay workflows runs resume <workflowId> <runId>

# List all workflows
clay workflows list

# Get a workflow (returns { id, name, url })
clay workflows get <workflowId>

# Create a new workflow
clay workflows create --name "My Workflow"
```

When you create a new workflow, share its link (the `url` field from `clay
workflows create`/`clay workflows get`) as soon as it exists, so the user can
open the editor and follow along in the UI as you build. This is most useful in
a headless environment where the user has no Clay tab already open; the
in-product assistant's user is already viewing the workflow.

## Watching a run to completion

There is no `watch` command — poll `runs get` until the run leaves a non-terminal
state. `status` is one of `pending` / `running` / `paused` / `waiting` /
`completed` / `failed`; `progress.percentage` tracks progress.

Poll by re-running this command every few seconds and reading `.status`, until it's
`completed` or `failed`:

```bash
clay workflows runs get <workflowId> <runId> | jq -r '.status'
```

## Inspecting what a run did (instead of "logs")

There is no `logs` command. The structured output of `runs get` and `runs steps`
is strictly better than grepping formatted text — filter it with `jq`:

```bash
# Full, untruncated inputs/outputs per node
clay workflows runs get <workflowId> <runId> --verbose | jq '.nodes'

# Just the failed nodes and their errors
clay workflows runs get <workflowId> <runId> --nodes | jq '.nodes[] | select(.status=="failed") | {nodeId, errors}'

# Errors across the failed steps (including each map entry)
clay workflows runs steps <workflowId> <runId> --status failed | jq '.data[].errors'

# One node's config + full map/reduce results
clay workflows runs get <workflowId> <runId> --node-id <nodeId> | jq '.nodes[0]'
```

## Tell the user what the run actually did

Don't dump raw run JSON at the user. After a run, **narrate the trace node-by-node**: for each node, what it received, what it produced, and (if it failed) why. `--verbose` gives you the untruncated inputs/outputs to do this from:

```bash
clay workflows runs get <workflowId> <runId> --verbose | jq '.nodes'
```

Structure the recap as a short per-node walkthrough (or a small table: node → inputs → output/result → status), then call out any failures and what you'll change. Reserve raw JSON for when the user explicitly asks for it.

**Locate results in the graph, don't just list them.** Pair the walkthrough with a `clay workflows diagram <workflowId>` render and overlay the run status onto it, so the user sees _where_ each result (or failure) came from — either annotate each node's label with a status marker or put a small "node → status" table beside the diagram. See `presenting.md` for the status markers and the annotation convention. Pull each node's status from `runs get --nodes` (or the per-step statuses from `runs steps`) to build the overlay.

## Example workflow

1. Start a test: `echo '{}' | clay workflows runs test wf_abc --input -`
2. Watch progress by re-running the `runs get … | jq -r '.status'` poll above until `status` is `completed`/`failed`.
3. Inspect failures: `clay workflows runs steps wf_abc wfr_xyz --status failed | jq '.data[].errors'`
4. Walk the user through the trace node-by-node (see "Tell the user what the run actually did" above), not as raw JSON.

## Testing & exploration MCP tools

- **execute_clay_action**: Run any Clay action to see its output before using it in a workflow
  - Provide `actionPackageId`, `actionKey`, and `inputs`
  - Returns raw action result — use this to understand output format before building nodes
  - Note: actions consume credits
- **run_code**: Run Python code in a sandbox to test logic before putting it in code nodes
  - Code must define `handler(context)` returning a dict
  - Supports `context.call_tool()` if tools are provided
  - Supports `context.get_input()` if inputs are provided
  - Optionally install pip packages

## Pro tips

- Poll `runs get` by re-running it (above) to monitor a run while you work.
- Pipe to `jq` for filtering: `clay workflows runs steps <workflowId> <runId> | jq '.data[] | select(.status=="failed")'`
- To save output for later analysis, capture `clay workflows runs get <workflowId> <runId> --verbose` with your file-writing tool.
- `--verbose` returns untruncated inputs/outputs; prefer it over reconstructing logs.
