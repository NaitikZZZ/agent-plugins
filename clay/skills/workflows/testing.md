# Testing Workflows

If `clay` isn't on PATH or `clay whoami` fails on auth, run the `setup` skill.

## Commands

```bash
# Start a test run (input JSON on stdin via --inputs -; defaults to {})
echo '{"key":"value"}' | clay workflows runs test <workflowId> --inputs -
clay workflows runs test <workflowId>                  # no inputs
clay workflows runs test <workflowId> --live           # run the published (live) version

# Audience-segment backfill (up to --limit members) — runs the current draft unless --live
clay workflows runs test <workflowId> --audience-segment <segmentId> --limit 5
clay workflows runs test <workflowId> --audience-segment <segmentId> --record-ids 8814,8815
clay workflows runs list <workflowId> --audience-segment <segmentId>

# Run a source trigger (Find leads search, CSV upload, audience segment) — one run per record
clay workflows runs test <workflowId> --trigger <triggerId>                # CSV / segment: current draft; Find leads: published version
clay workflows runs test <workflowId> --trigger <triggerId> --live         # CSV / segment: pinned to the published version
clay workflows runs test <workflowId> --trigger <triggerId> --replay     # Find leads: re-run already-found records too
clay workflows runs test <workflowId> --trigger <triggerId> --limit 5    # audience segment trigger: --limit or --record-ids required
clay workflows runs list <workflowId>

# Partial single-node test (exactly one of --source-run or --inputs)
clay workflows nodes test <workflowId> <nodeId> --source-run <runId>
clay workflows nodes test <workflowId> <nodeId> --inputs '{"param":"value"}'
```

### Draft vs live when testing

- **Plain / manual `clay workflows runs test`** (with or without `--inputs`) starts a run
  via the manual trigger and exercises the **current draft**. Use this to verify
  unpublished edits.
- **`--audience-segment`** starts runs for members of that segment through the segment
  trigger's manual companion. It needs no publish — the companion is created live even while
  the segment trigger is still a draft — and like the plain form the runs exercise the
  **current draft** unless you pass `--live`. Real segment automation (membership changes,
  schedules) runs the live version, so a passing `--audience-segment` run does not prove the
  published graph works — use `--live` for that.
- **`--live`** (works with or without `--audience-segment`) pins the runs to the
  workflow's published (live) version instead of the draft. It fails with
  `validation_error` if the workflow has never been published.

- **`--trigger <triggerId>`** runs whichever source sits behind that trigger and starts one
  run per record it returns. Which graph the runs use depends on the source:
  - **CSV upload** and **audience segment** triggers run the **current draft** unless you pass
    `--live`, so you can keep editing and re-run the same records against the draft.
  - A **Find leads** trigger always runs the **published version** — the source hands its
    records to the trigger's live version, and `--live` changes nothing. Draft edits are not
    exercised until you publish; to check one node against a real record first, use
    `clay workflows nodes test <workflowId> <nodeId> --source-run <runId>` with a run the
    source already produced.

  The trigger named by `--trigger` must be live. A Find leads or audience segment trigger goes
  live when the workflow is published, so `clay workflows publish` first for those — "is draft,
  not live" means publish, not retry. To run segment members against the draft without
  publishing, use `--audience-segment` instead, which does not check the trigger's status. A
  CSV trigger is live from creation and needs no publish (see `csv-triggers.md`); do not publish
  just to test one. "has no source yet" / "has no CSV file
  yet" mean the source is not provisioned or no file is linked. It returns `{ ok: true }` rather
  than a run id — watch the runs with `clay workflows runs list`. On an audience segment trigger
  it is bounded like `--audience-segment`: pass `--limit` (max 10) or `--record-ids`. Triggers
  this command cannot run (manual, webhook, scheduled, signal, Clay table) are rejected; use the
  plain form or the trigger's own entry point for those.

`--record-ids` runs exactly those Audiences records instead of the segment's first
`--limit` members; pass one or the other, not both.

`--inputs`, `--audience-segment`, and `--trigger` cannot be combined. See `publishing.md`.

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

## Finding runs after starting a trigger

Inspect `clay workflows runs list <workflowId>` before choosing filters. On a fresh
workflow triggered once, its runs are sufficient; check the expected row count and
follow pagination when needed. On an existing workflow, use trigger IDs and creation
times to narrow the results, but these may not distinguish overlapping executions of
the same trigger.

`batchId` (CLI `.batch.id`) identifies a legacy workflow batch record. `batchKey`
(CLI `.batch.key`) is a trigger execution/deduplication key, not that record's ID.
Never compare them. A run can legitimately have no `.batch`; this does not mean it
hasn't started. The run-list output does not expose the trigger's batch key.

If a filter finds no runs, inspect the unfiltered response before polling again.
Runs can appear asynchronously; an empty lookup does not mean you should retrigger
the workflow.

## Watching a run to completion

Prefer a single blocking call with `--wait` instead of hand-rolling a poll loop.
Once you have run IDs, wait on those runs rather than repeatedly rediscovering them.
There is no universal completion time: code, provider calls, agent steps, and explicit
delays take different amounts of time. Use status and progress to decide whether more
waiting is useful.
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
