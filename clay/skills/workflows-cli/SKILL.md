---
name: workflows-cli
description: Clay workflows — build and edit automations with `clay workflows nodes/graph/actions/code/triggers` (CLI). Use when building or editing Clay workflows.
---

# Building Clay workflows with the CLI

Supporting files in this directory: `publishing.md`, `testing.md`, `data-passing.md`,
`presenting.md`, `audiences.md`. If `clay` isn't on PATH or `clay whoami` fails, run
`setup` — retry once on `command not found` before concluding it's unavailable.

## Domain and working style

You are helping users build and edit Clay workflows.

- **Name new workflows first.** When the current workflow is blank and has a placeholder name,
  choose a concise, descriptive name from the user's initial request. Immediately before renaming,
  run `clay workflows get <workflowId>` and inspect its current `name`; only run
  `clay workflows update <workflowId> --name "<name>"` if the name is still exactly
  `Untitled workflow`. Preserve any name that has already replaced the placeholder. Do this before
  asking follow-up questions or editing the graph. When creating a workflow, choose the name before
  running `clay workflows create`. Do not rename an existing non-blank workflow unless the user asks
  you to.
- **Plan first, get approval before building.** Present a short user-facing plan (how it starts,
  main steps, outcome), then wait. Do not jump straight into `clay workflows nodes create`.
- **Narrate and visualize as you go.** After each meaningful change, say what changed and show the
  graph (`presenting.md`).
- **Ask when there's a real choice** — refer to actions by human-readable names, never bare
  `actionKey`s.

Common node types (not just agent/tool — pick the type that fits the step):

- **Claygent (agent) nodes** (`nodeType: "agent"`) — LLM loops with prompts (reasoning,
  drafting, summarizing, classifying).
  - **Create:** send `agentName`, `agentPrompt`, and `agentModel` **together in the same**
    `--input` — separate calls can persist a blank prompt. Prefer `gpt-5.4-nano` while
    building; graduate the model after the workflow works end-to-end.
  - **Reuse:** `clay claygents list --search <text>`, then send only `agentClaygentId` (the
    returned `id`). Do not send `agentName` / prompt / model — `agentName` can rewrite that
    shared prompt.
- **Tool nodes** (`nodeType: "tool"`) — run a single Clay action. (UI may label these
  "Enrich" or "Function".) `tools` may be omitted while drawing an outline; before
  validate/test/publish, set exactly one `tools` entry with `toolType: "clay_action"` plus
  `actionKey` / `actionPackageId` from `clay workflows actions schema`.
- **Conditional nodes** (`nodeType: "conditional"`) — pick exactly one outgoing branch
  (`rules` / `agentic` / `code` via `conditionalConfig`).
- **Code nodes** (`nodeType: "code"`) — deterministic Python transforms (no LLM).
- **Map / reduce** (`nodeType: "map"` / `"reduce"`) — fan-out and aggregate list
  results. Prefer these over forcing list work into a single agent/tool step when the
  graph needs real fan-out/aggregation. Gathering is via Map/Reduce **auto-gather**
  (`autoGather`, default on) — do **not** create a `collect` node (`nodes create`
  rejects it; `collect` is legacy/read-only).
- **Trigger nodes** (`nodeType: "trigger"`) — canvas entry points. Create/bind them with
  `clay workflows triggers …` (see Triggers below); do not invent a bare trigger node
  without a trigger row.

Do not collapse branching or deterministic transforms into Claygent/tool-only graphs when
`conditional` or `code` is the right fit. Node type is fixed at create — choose before
`nodes create` because it cannot be changed later. Read an existing node of the same type
(`nodes get`) and copy writable fields from `.node` when the shape is unfamiliar.

**Conditional (brief):** set top-level `conditionalConfig` as a JSON **object** (never a
stringified string). Prefer `rules` for field comparisons; use `agentic` for open-ended
classification; use `code` when routing needs a Python transform — put the handler in
top-level `code`, call `context.transition_to("Destination Name", "branch_id")` with both
args, and wire destinations with `incomingEdges` + matching `transitionId`.

**Code nodes:** put the Python handler in top-level `code`. Prefer `clay workflows code test`
before wiring. Use for deterministic shaping/filtering; use an agent when the step needs LLM
judgment.

**Triggers** start a workflow (audience segments, schedules, webhooks, Clay tables). Create/edit
them with `clay workflows triggers …`. Clay table triggers remain UI-only.

**Audiences inside a workflow** (`upsert-audiences-record`, `audience_segment` trigger):
`audiences.md`.

**Draft vs live** and how test runs relate to publish: see `publishing.md` and `testing.md`.

## Command reference

### Creating and loading a workflow

- Create: `clay workflows create --name "My Workflow"` — returns `{ id, name, url }`. Share `url`
  as `[Open workflow](<url>)` (see `presenting.md`).
- Get: `clay workflows get <workflowId>` — same shape. Share `url` the first time you load an
  existing workflow.
- Update name: `clay workflows update <workflowId> --name "New name"` — returns the updated
  workflow.
- Delete: `clay workflows delete <workflowId>` — admin-only, deletes the workflow and its triggers,
  and cannot be undone from the CLI. Run it only when the user explicitly asks to delete the
  workflow. A repeated delete returns `not_found` rather than succeeding again.

### Reading a workflow

- `clay workflows graph get <workflowId> [--mode summary|full]` — `--mode full` returns per-node
  configuration; omit for a lighter summary (nodes, edges, triggers).
- `clay workflows nodes get <workflowId> <nodeId>` — cheaper than a full-graph read when
  you only need one node. Returns `{ "node": <object> }` — the writable fields live under `.node`,
  not the top-level envelope.

### Editing nodes

- Create: `clay workflows nodes create <workflowId> --input <json|file|->` — positioning and edge
  cleanup are handled server-side. Read an existing node first (`nodes get`) and take fields from
  `.node` for the writable shape — it's dynamic per node type. Feeding the whole get envelope into
  `--input` is a validation_error.
- Update: `clay workflows nodes update <workflowId> <nodeId> --input <json|file|->` —
  only the fields in `--input` change.
- Delete: `clay workflows nodes delete <workflowId> <nodeId>` — edge cleanup handled
  server-side.
- Test one node: `clay workflows nodes test <workflowId> <nodeId> --source-run <runId>`
  or `--inputs <json|file|->` — starts a partial run of only that node, then terminates.
  Returns immediately (does not poll); inspect with `clay workflows runs get`. Exactly one of
  `--source-run` or `--inputs` is required.
- Upgrade to an account agent: `clay workflows nodes upgrade-to-account-agent <workflowId> <nodeId>`
  — copies the node's linked agent into a new account agent and re-links the node. One-way: the
  node cannot be converted back from here; restoring a pre-upgrade snapshot is the only rollback.
  Preconditions the server enforces: the node is an agent node linked to a regular agent with
  Repeat off. The node's `accountId` input is auto-wired when a single upstream accounts
  audience trigger resolves; otherwise (e.g. a people trigger upstream) the upgrade still
  succeeds, workflow validation flags the node, and `accountId` must be wired manually to a
  numeric Audiences account record id (see the node's `inputSchema`). A source agent
  that uses connected accounts is rejected (upgrade it from the node's side panel in the
  workflow editor instead). An `auth_forbidden` is ambiguous — missing edit access fires before
  the account-agent capability check — so branch on the error message: only "Account agents are
  not enabled" means the workspace lacks account agents. After upgrading, `read` the node to see
  the new binding; prompt and task edits happen in the account agent's own builder. If the
  command times out, read the node back before retrying: a node already linked to the new
  account agent means the upgrade landed. Run the command with `--help` for exit codes and
  examples.
- Default to account agents under audiences triggers: when creating an agent node in a
  workflow whose upstream trigger is an audiences trigger (people or companies), reason
  about whether the task benefits from account context — research, enrichment, scoring,
  qualification, and personalized outreach all do, so most of the time default to making it
  an account agent: create the regular agent node, run `upgrade-to-account-agent` on it,
  then verify the `accountId` wiring. Keep a regular Claygent when the node only transforms
  data already produced upstream (pure text synthesis, formatting, or summarization of
  other nodes' outputs). Always honor an explicit user request in either direction.
- Before any account-agent work (linking, upgrading, swapping, editing prompt/tasks, or
  changing `accountId` wiring), read `account-agents.md` in this skill directory in full.

### Validating and formatting

- `clay workflows graph validate <workflowId>` — structural checks only. Read-only: it neither
  repositions nodes nor persists a snapshot.
- `clay workflows graph format <workflowId>` — validates and re-runs auto-layout. Unlike
  `graph validate` this persists a snapshot, so it needs edit access.

### Testing actions and code

- `clay workflows actions test <packageId> <actionKey> [--inputs <json|file|->]` — consumes
  credits. Returns `{ "result": <object>, "metadata"?: <object> }` — action fields live under
  `.result` (use those for `$.result.<field>` wiring); `metadata` is credit/refund accounting when
  the runner reports it. Discover `packageId`/`actionKey` with `clay workflows actions list`
  (see `/workflows-discover-actions`), and the input shape with `clay workflows actions schema`.
- `clay workflows code test --file <path|-> [--inputs <json|file|->] [--tools <json|file|->] [--packages <csv>]`
  — runs Python in a sandbox to test code before adding it to a node. The file must define
  `handler(context)` returning a dict. `--inputs` backs `context.get_input()`, `--tools`
  (a JSON array of `{actionKey, actionPackageId}`) backs `context.call_tool()`, and
  `--packages` installs extra pip packages. Exits 0 even on handler failure — inspect
  `isError` in the JSON, not the exit code.

### Triggers

- Get: `clay workflows triggers get <triggerId>` — trigger ids come from `clay workflows graph get`,
  which returns them alongside the nodes; a workflow id is not accepted here.
- Create: `clay workflows triggers create <workflowId> --input <json|file|->` — the one trigger
  command that takes a workflow id. Its output is a confirmation, not the trigger — see the wiring
  note below. The writable shape is dynamic per trigger type — read an existing trigger first, same
  pattern as nodes.
- Update: `clay workflows triggers update <triggerId> --input <json|file|->` — takes the trigger
  id, not the workflow's. Only the fields in `--input` change.
- Delete: `clay workflows triggers delete <triggerId>` — trigger id again.

**Audience multi-segment sharing:** multiple `audience_segment` triggers (different `segmentId`s)
may share one trigger node when they have the **same trigger type** and the **same outgoing edge**.
Multiple `audience_scheduled` triggers may share a node when they also have the **same schedule**.
Pass an explicit `workflowNodeId` to bind/share; omit it (or pass `createTriggerNode: true`) to get
a new node. Do not mix `audience_segment` with `audience_scheduled` on one node. `audience_manual`
is a run companion created by the UI/run path — do not create it via the CLI.

### Listing resources

One command per resource kind: `clay workflows list`, `clay tables list`, `clay functions list`.
Audience segments are CLI-only: `clay audiences list --entity-type people|companies`.

Every command's `--input`/`--inputs` accepts inline JSON, a file path, or `-` for stdin — pick whichever
is easiest to construct for the payload at hand. Run `clay workflows <command> --help` for the exact
output shape, error codes, and examples before using a command for the first time; don't guess at flags.

**`clay workflows actions test` is a single-shot preview only** — capped at ~25 runs/day per
user. Use it once to confirm an action's input/output shape, never to enrich or process a
batch of records. To run an action over many inputs, use a managed routine
(`clay routines runs start`), a table column, or a workflow node — none of which are
subject to that daily cap.

### Enabling batching on a tool node

Some actions support batching multiple workflow runs into a single provider call, cutting
cost/rate-limit pressure for high-volume workflows. Not every action supports it, and the
catalog doesn't flag which ones do — enable batching only when the user explicitly raises
batching, rate limits, or large volumes of rows/runs; never proactively.

Set it via `nodes update` after the tool node already has `tools` configured:

```bash
clay workflows nodes update <workflowId> <nodeId> --input '{
  "batchRunSettings": { "enabled": true, "maxBatchSize": 50 }
}'
```

`maxBatchSize` is optional and gets clamped to the action's real maximum. If the action
doesn't support batching, the update rejects — relay that to the user rather than retrying.
Create with `tools` first, then enable batching in a follow-up update (same conversation turn
is fine as two calls).

### List mode (Repeat)

An agent, code, or tool node can run once per item in an upstream list instead of once over
the whole list. In the editor this is the **Repeat** toggle. Describe it to the user as
**"runs once per item"** — never say it "maps over the list" or call it a map/loop.

Enable it on the node with `listMode: true` **and** `listEntriesRef` in the same
`clay workflows nodes update` (or on create), pointing at the upstream array:

```bash
clay workflows nodes update <workflowId> <nodeId> --input '{
  "listMode": true,
  "listEntriesRef": { "sourceNodeId": "wfn_upstream", "path": "$.results" }
}'
```

Always set `listEntriesRef` when turning list mode on: without it the node looks for an
`entries` input instead of the upstream array, and repeats over the wrong thing. Pass
`null` to clear it.

For tool nodes, map each input that should vary per item with `inputMappingConfig` `item`
(`{ "type": "item", "path": "$.field" }`) — not a `reference` to the upstream list (that
resolves to the whole aggregate). See `data-passing.md`. `listFailureMode` is
`"fail_at_end"` (default) or `"ignore_errors"`.

**When to use it:** the same per-record work over a list (enrich each row, draft one message
per lead). **When not:** a single aggregate step over the whole list — leave `listMode` off.
Unsupported on account agent nodes and on trigger/conditional/map/reduce/collect/fork/join.
If the workspace has list mode disabled, the update rejects — relay that rather than retrying.

### Wiring the first node after creating a trigger

`triggers create` returns only a confirmation (`resourceId`, `operation`), and `resourceId` is the
**trigger** id, not the canvas node's. Passing it as an `incomingEdges` source wires the node to an
id that doesn't exist there. Read the trigger back first and take `workflowNodeId` from that:

```bash
trigger_id=$(clay workflows triggers create wf_1 --input trigger.json | jq -r '.resourceId')
node_id=$(clay workflows triggers get "$trigger_id" | jq -r '.workflowNodeId')
```

Wire it with `incomingEdges: [{ "sourceNode": "<workflowNodeId>" }]`. Do not send
`sourceNodeId` inside `incomingEdges` — graph summary uses that key on the read side.

**Trigger edge constraint:** a trigger may have zero or one direct outgoing edge, never more.
Before wiring a node with `incomingEdges` from a trigger's `workflowNodeId`, check
`clay workflows graph get <workflowId>` (default summary) for any edge whose `sourceNodeId` is
that trigger node id — `summary.edges` already covers trigger→node edges. If it already has a
target, do not add another direct edge; add work downstream instead, or ask the user whether to
rewire. Before validating or running, each trigger must be connected to one first executable node.

## Capabilities without a `clay workflows` command

Building a workflow often touches adjacent surfaces — tables, functions, audiences — that have
their own CLI commands elsewhere rather than a `clay workflows` subcommand:

- **Table schema** — `clay tables columns list <tableId>` (abbreviated) or
  `clay tables columns get <tableId>` (full settings).
- **Table rows** — `clay tables query-live <tableId> --query <clayql>`, against live Postgres.
  It takes ClayQL directly — write the query yourself off the columns above; there is no
  natural-language query option. Don't reach for `clay tables query` instead — that reads a
  different store (synced ClickHouse, gated on Enterprise sync).
- **One audience segment** — `clay audiences get <audienceId>`, which includes the filter AST that
  selects its records.
- **Audience record fields** — `clay audiences fields list` with `--entity-type people` or
  `--entity-type companies` returns the ids for `upsert-audiences-record` (see `audiences.md`).
  Mind the two vocabularies: the flag is `people`/`companies`, while `upsert-audiences-record`
  still wants `entityType: "CONTACT"`/`"ACCOUNT"`.
- **Function schemas** — `clay functions get <functionId>` returns `inputSchema` and `outputSchema`.
  `clay workflows actions list` carries the `functionId` to pass it.

Search DSL has no CLI command. When a capability isn't listed here and has no `clay` command, it's
genuinely unavailable rather than hidden — tell the user that instead of hunting for a command that
will not appear.
