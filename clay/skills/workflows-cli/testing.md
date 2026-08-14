# Testing Workflows

If `clay` isn't on PATH or `clay whoami` fails on auth, run the `setup` skill.

## Commands

```bash
# Start a test run (input JSON on stdin via --inputs -; defaults to {})
echo '{"key":"value"}' | clay workflows runs test <workflowId> --inputs -
clay workflows runs test <workflowId>                  # no inputs

# Audience-segment backfill (up to --limit members) — not a draft test after publish
clay workflows runs test <workflowId> --audience-segment <segmentId> --limit 5
clay workflows runs list <workflowId> --audience-segment <segmentId>

# Partial single-node test (exactly one of --source-run or --inputs)
clay workflows nodes test <workflowId> <nodeId> --source-run <runId>
clay workflows nodes test <workflowId> <nodeId> --inputs '{"param":"value"}'
```

### Draft vs live when testing

- **Plain / manual `clay workflows runs test`** (with or without `--inputs`) starts a run
  via the manual trigger and exercises the **current draft**. Use this to verify
  unpublished edits.
- **`--audience-segment`** starts runs through that audience segment trigger. After the
  workflow is published, those runs use the **live** version — not draft-only edits you
  have not published yet. Do not conclude “the draft works” from a successful
  `--audience-segment` run on a published workflow; publish first if you need the live
  path to pick up draft changes, or use a manual test to validate the draft.

`--inputs` and `--audience-segment` cannot be combined. See `publishing.md`.

```bash
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

# Publish the tested draft as live
clay workflows publish <workflowId> --name "July enrichment rollout"
```

When you create or first load a workflow, share its `url` as a clickable Markdown
link (`[Open workflow](<url>)`) — see `presenting.md`.

## Watching a run to completion

Prefer a single blocking call with `--wait` instead of hand-rolling a poll loop.
`status` is one of `pending` / `running` / `paused` / `waiting` / `completed` /
`failed` / `cancelled`; `progress.percentage` tracks progress.

```bash
clay workflows runs get <workflowId> <runId> --wait           # poll until terminal
clay workflows runs get <workflowId> <runId> --wait 60        # same, but stop after 60s
clay workflows runs get <workflowId> <runId>                  # single request (may still be running)
```

Terminal statuses are `completed`, `failed`, `cancelled`, and `paused`. `paused`
is returned rather than waited through — the run will not advance without
`clay workflows runs resume` or the paused trigger goes live. `--wait` also returns when a node has
`waitingReason` `agent_step_limit_reached`; other `waiting` reasons are not
terminal (async work is still in flight). If `--wait` returns `status: waiting`,
human intervention is required somewhere. With `--wait <seconds>`, any other
non-terminal status means the budget ran out — check `.status` before treating
the run as done.

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

1. Start a test: `echo '{}' | clay workflows runs test wf_abc --inputs -`
2. Watch to completion: `clay workflows runs get wf_abc wfr_xyz --wait | jq -r '.status'`
3. Inspect failures: `clay workflows runs steps wf_abc wfr_xyz --status failed | jq '.data[].errors'`
4. Walk the user through the trace node-by-node (see "Tell the user what the run actually did" above), not as raw JSON.

## Testing & exploration before wiring a node

Use `clay workflows actions test` and `clay workflows code test` as documented in
the parent skill. After wiring, confirm the persisted config with
`clay workflows nodes get` or `graph get --mode full`.

## Pro tips

- Prefer `runs get --wait` over a hand-rolled poll loop when watching a run.
- Pipe to `jq` for filtering: `clay workflows runs steps <workflowId> <runId> | jq '.data[] | select(.status=="failed")'`
- To save output for later analysis, capture `clay workflows runs get <workflowId> <runId> --verbose` with your file-writing tool.
- `--verbose` returns untruncated inputs/outputs; prefer it over reconstructing logs.
