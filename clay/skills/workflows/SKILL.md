---
name: workflows
description: Clay workflows — plan, review, build, and edit automations with the Clay CLI. Use when planning or working on a Clay workflow.
---

# Building Clay workflows with the CLI

Supporting files in this directory: `publishing.md`, `testing.md`, `data-passing.md`,
`presenting.md`, `audiences.md`, `account-agents.md`, `run-analysis.md`, `node-groups.md`,
`csv-triggers.md`.

Read this skill before proposing a workflow plan, even when the user asks for no workspace
queries or changes. For Audiences destinations or field mappings, also read `audiences.md`
before answering. Reading skill guidance does not query or change the workspace.

When working in an existing workflow, read it with `clay workflows get <workflowId>` before
planning edits, unless the user prohibits queries; then plan from the supplied draft and field
catalog. Do not ask for a workflow ID just to discuss a complete supplied draft. If its `type`
is exactly `audience_enrichment`, read the complete
`/workflows-audience-enrichment` skill and follow it together with this skill. Do not apply that
specialized skill to a workflow whose type is null, absent, or any other value.

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
- Follow the host agent's planning, user-input, and approval policies when building or editing workflows.
- **Choose Audiences writeback from the whole workflow and the user's intent.** Inspect the
  source, upstream steps, outputs, and existing destinations. Enrichment of existing Audiences
  records should write results back; for new records from searches or CSV uploads, recommend
  saving to Audiences and confirm before adding it unless already requested. Honor explicit
  destinations and no-save requests, and reuse existing writeback nodes. Read `audiences.md`
  for the decision and field-mapping rules: map obvious existing fields directly without
  offering duplicate fields, clarify ambiguous mappings, and create needed fields without
  asking permission. A missing compatible field is a reason to create one, not a decision
  to hand back to the user. In a plan, state that creation and mapping as the next steps.
  Building a node does not authorize running or publishing.
- **Ground provider names in the workspace catalog.** Until you search the current workspace's
  action catalog, describe capabilities generically (for example, "intent data enrichment"). Do
  not introduce provider or action names from general knowledge. You may name one when the user
  already named it or the catalog verified it. Never proactively mention G2 or 6sense; if the user
  asks for either, search the catalog and recommend verified alternatives instead of presenting it
  as a supported Clay action.
- **Narrate and visualize as you go.** After each meaningful change, say what changed and show the
  graph (`presenting.md`).
- **Ask when there's a real choice** — refer to actions by human-readable names, never bare
  `actionKey`s.

Common node types (not just agent/tool — pick the type that fits the step):

- **Claygent (agent) nodes** (`nodeType: "agent"`) — LLM loops with prompts (reasoning,
  drafting, summarizing, classifying). Read and follow the complete `/workflows-claygent`
  skill before creating, editing, or running one.
  - **Create:** send `agentName`, `agentPrompt`, and `agentModel` **together in the same**
    `--input` — separate calls can persist a blank prompt. Prefer `gpt-5.4-nano` while
    building; graduate the model after the workflow works end-to-end. One exception: a node
    you are about to make an account agent is created bare — see account agents below.
  - **Reuse:** `clay claygents list --search <text>`, then send only `agentClaygentId` (the
    returned `id`). Do not send `agentName` / prompt / model — `agentName` can rewrite that
    shared prompt.
- **Tool nodes** (`nodeType: "tool"`) — run a single Clay action or Clay function. (UI may
  label these "Enrich" or "Function".) `tools` may be omitted while drawing an outline; before
  validate/test/publish, set exactly one `tools` entry — either
  `{ "toolType": "clay_action", "actionKey": …, "actionPackageId": … }` for an enrichment action,
  or `{ "toolType": "clay_function", "tableId": "<functionId>" }` for a Clay function subroutine.
  Both come from `clay workflows actions list`. For the input shape, pass an action's ids to
  `clay workflows actions schema` or a function's id to `clay functions get`.
- **Conditional nodes** (`nodeType: "conditional"`) — pick exactly one outgoing branch
  (`rules` / `agentic` / `code` via `conditionalMode`).
- **Code nodes** (`nodeType: "code"`) — deterministic Python transforms (no LLM), for shaping
  and filtering; use an agent when the step needs LLM judgment. The handler goes in top-level
  `code`. Prefer `clay workflows code test` before wiring.
- **Delay nodes** (`nodeType: "delay"`) — pause a run before the next step without producing
  data. Set integer `delaySeconds` from 1 to 3600 in the create or update `--input`.
- **Map / reduce** (`nodeType: "map"` / `"reduce"`) — fan-out over a list and aggregate the
  results. Use these when the fan-out itself has to be a graph step: per-item concurrency or
  retry settings, or a downstream aggregation. For the same per-record work inline on one node,
  use list mode instead (see "List mode (Repeat)"). A map node needs `mapConfig` with
  `mode: "code"` or `"agent"` plus `maxConcurrency` and `maxRetries`; a reduce node needs
  `reduceConfig` with the same `mode` plus `batchSize`. Send those every time — the create call
  accepts a config without them and `graph validate` then rejects the node. Code-mode Python goes
  in top-level `code`; agent mode takes `agentConfig.prompt`, required on `reduceConfig` and
  needed on `mapConfig` unless the node already has a Claygent linked. Every node feeding a reduce
  must be a map node with `outputKey: true` and a `keyExpressionPath`. Gathering is on by default (`gatherResults`
  inside `mapConfig` / `reduceConfig`) — do **not** create a `collect` node (`nodes create`
  rejects it; `collect` is legacy/read-only).
- **Trigger nodes** (`nodeType: "trigger"`) — canvas entry points. Create/bind them with
  `clay workflows triggers …` (see Triggers below); do not invent a bare trigger node
  without a trigger row.

Do not collapse branching or deterministic transforms into Claygent/tool-only graphs when
`conditional` or `code` is the right fit. Node type is fixed at create — choose before
`nodes create` because it cannot be changed later. Read an existing node of the same type
(`nodes get`) and copy writable fields from `.node` when the shape is unfamiliar.

Wiring a node's inputs — `inputSchema` with `sourceNodeId`/`sourcePath`, and `inputMappingConfig`
on tool nodes — is covered in `data-passing.md`. Read it before wiring the first input.

### Conditional nodes

A conditional node selects exactly one outgoing edge. Set the top-level `conditionalMode` to
`rules`, `agentic`, or `code`. Pass `rulesConditionalConfig` or `agentConditionalConfig` as a JSON
object, never as stringified JSON.

- Use `rules` for string, number, or boolean comparisons and AND/OR groups.
- Use `agentic` for open-ended classification that requires LLM judgment.
- Use `code` when routing requires a deterministic Python transform.

**Rules mode:** set `conditionalMode: "rules"`. Declare every field the rules read in top-level
`inputSchema` with `sourceNodeId` and `sourcePath`, then reference that field name from each
`BinOp`'s `dataPath`. Wrap conditions in a root `GroupOp`, even when there is only one condition.
Rules run top-to-bottom and the first match wins.

Supported operators:

- String: `Equal`, `NotEqual`, `Contain`, `NotContain`, `ContainAny`, `StartsWith`,
  `NotStartsWith`, `EndsWith`, `NotEndsWith`, `Empty`, `NotEmpty`
- Number: `Equal`, `NotEqual`, `GreaterThan`, `GreaterThanOrEqual`, `LessThan`,
  `LessThanOrEqual`, `Empty`, `NotEmpty`
- Boolean: `True`, `False`, `Empty`, `NotEmpty`

```json
{
  "nodeType": "conditional",
  "name": "Has work email?",
  "inputSchema": {
    "type": "object",
    "properties": {
      "email": {
        "type": "string",
        "sourceNodeId": "wfn_source",
        "sourcePath": "$.result.email"
      }
    }
  },
  "conditionalMode": "rules",
  "rulesConditionalConfig": {
    "rules": [
      {
        "id": "has_email",
        "name": "Email found",
        "condition": {
          "type": "GroupOp",
          "combinationMode": "And",
          "items": [
            {
              "type": "BinOp",
              "dataPath": ["email"],
              "operator": "NotEmpty"
            }
          ]
        }
      }
    ]
  }
}
```

Wire each rules destination by the matching rule id, in that destination node's `incomingEdges`.
On `nodes update`, `incomingEdges` **replaces** the node's full incoming-edge set — an entry you
omit (including the trigger connection) is silently removed, so read the node first and resend
existing edges plus the new one. `ruleId`, `routeId`, `transitionId`, and `isDefaultRoute` are
edge fields — they are only read inside an `incomingEdges` entry, never at the top level of the
node:

```json
{
  "incomingEdges": [
    { "sourceNode": "<conditionalNodeId>", "ruleId": "has_email" }
  ]
}
```

Always give a conditional a no-match fallback, in all three modes: create the destination and mark
its edge `isDefaultRoute: true`. That edge is the only thing the run reads — setting
`rulesConditionalConfig.defaultTargetNodeId` instead saves and validates, then fails the run with
"no default route connected" the first time nothing matches. If the run should stop instead of
routing onward, set `rulesConditionalConfig.endRunOnNoMatch` (rules mode only) and leave the
fallback edge off. Do not use a bare edge from a conditional unless it is truly the default route.

**Agentic mode:** set `conditionalMode: "agentic"` and include at least one stable route in
`agentConditionalConfig.routes`. A prompt without routes is rejected. When updating the prompt,
re-include the complete routes array.

```json
{
  "conditionalMode": "agentic",
  "agentConditionalConfig": {
    "prompt": "Decide whether the review is positive or negative.",
    "routes": [
      {
        "id": "positive",
        "name": "Positive",
        "description": "Praise or a good experience"
      },
      {
        "id": "negative",
        "name": "Negative",
        "description": "Complaints or a bad experience"
      }
    ]
  }
}
```

Create the destination nodes first, then wire each one with `incomingEdges` whose `routeId`
matches the route's `id`:

```json
{
  "incomingEdges": [
    { "sourceNode": "<conditionalNodeId>", "routeId": "positive" }
  ]
}
```

**Code mode:** set `conditionalMode: "code"` and put the Python handler in top-level `code`.
Call `context.transition_to("Destination Node Name", "branch_id")` with both arguments, then wire
the destination with the matching `transitionId`:

```json
{
  "incomingEdges": [
    { "sourceNode": "<conditionalNodeId>", "transitionId": "branch_id" }
  ]
}
```

For agentic and code conditionals, create placeholder destinations first, create the conditional
with stable route/transition ids, then attach each destination with the matching edge id.

### Triggers, audiences, and draft vs live

**Triggers** start a workflow (signals, audience segments, schedules, webhooks, Clay tables, CSV
uploads, Find leads searches). Create/edit them with `clay workflows triggers …`. Clay table
triggers remain UI-only. A Find leads trigger (`triggerType: "action_source_scheduled"`) runs a
Clay search and starts one run per record it finds; if a Find leads skill (`workflows-find-leads`)
is in your catalog, follow it for the `dataSource` shape and how to run the trigger.

**Running a workflow from a CSV** (upload a file, one run per row): the `clay workflows triggers
csv` commands — including attaching a CSV the user dropped in chat (at
`/mnt/session/uploads/<filename>`). See `csv-triggers.md`.

**Choose the trigger from context.** When the choice is clear and the user requested
a draft, create it without asking for confirmation again. When signals, segments, or other sources could
match the request, use the user's intended event, population, cadence, and prior
discussion to distinguish them. A shared keyword does not favor any trigger type.
If the choice remains ambiguous, ask the user to choose between the plausible sources
and wait before binding the trigger. Do not pick a default and merely ask to proceed. Read
`trigger-selection.md` for selection rules and examples.

**Audiences inside a workflow** (`upsert-audiences-record`, `audience_segment` trigger):
`audiences.md`.

**Draft vs live** and how test runs relate to publish: see `publishing.md` and `testing.md`.

**Investigating run data** (failures, traffic, durations, credits, searching run content):
`clay workflows analysis …` — see `run-analysis.md`.

## Command reference

Every command's `--input`/`--inputs` accepts inline JSON, a file path, or `-` for stdin — pick
whichever is easiest to construct for the payload at hand. Run `clay workflows <command> --help`
for the exact output shape, error codes, and examples before using a command for the first time;
don't guess at flags.

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

- Insert at a selected target: `clay workflows nodes insert <workflowId> --input <json|file|->` — when
  the current context names a workflow insertion target, pass its `type`, `nodeId`, and optional
  `handleId` through as `target` and describe the new node as `step`. Use this instead of manually
  creating and rewiring a node. The command reads the current graph and atomically preserves the
  downstream path. Configure any remaining node fields afterwards with `nodes update`.
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
- Account agents (agent nodes backed by a platform-managed Claygent with account context):
  `clay workflows nodes create-account-agent <workflowId> <nodeId> [--name <name>]` links a new
  one, from the platform template, to an agent node that has no linked agent — create the node
  bare (name and edges, no agent fields), run this with a specific `--name`, then set the prompt
  and tasks on the linked node. `clay workflows nodes upgrade-to-account-agent` converts a node
  already backed by a regular Claygent, and is one-way. Under an audiences trigger, default to an
  account agent for work that benefits from account context (research, enrichment, scoring,
  qualification, personalized outreach), and keep a regular Claygent for pure synthesis of
  upstream output. Include a downstream write-to-audiences node for account-agent results,
  reusing an existing node when possible; follow `audiences.md` for mappings and explicit
  destination or no-save instructions.
- **Read `account-agents.md` in full before any account-agent work** (linking, upgrading,
  swapping, editing prompt/tasks, or changing `accountId` wiring). Preconditions, `accountId`
  wiring, the ambiguous `auth_forbidden`, timeout-retry semantics, and what an account agent
  already sees live there; `--help` carries exit codes and examples.

### Validating and formatting

- `clay workflows graph validate <workflowId>` — structural checks only. Read-only: it neither
  repositions nodes nor persists a snapshot.
- `clay workflows graph format <workflowId>` — validates and re-runs auto-layout. Unlike
  `graph validate` this persists a snapshot, so it needs edit access.

### Running a workflow

- `clay workflows runs test <workflowId> [--inputs <json|file|->] [--audience-segment <id> --limit <n>] [--trigger <triggerId>]`
  starts a run (`--limit` is required with `--audience-segment`; `--inputs`, `--audience-segment`,
  and `--trigger` are mutually exclusive). `--trigger` runs a source trigger — Find leads, CSV
  upload, or audience segment — and starts one run per record; the trigger must be live, which
  for Find leads and segment triggers means publishing the workflow first (a CSV trigger is live
  from creation). `runs get`, `runs steps`, `runs list`, `runs pause`, `runs resume` inspect and control
  runs, and `clay workflows publish <workflowId>` ships the draft. Flags, the `--wait` poll, and
  which runs exercise draft vs live are in `testing.md` and `publishing.md`.

### Testing actions and code

- `clay workflows actions test <packageId> <actionKey> [--inputs <json|file|->]` — consumes
  credits. Returns `{ "result": <json|null>, "metadata"?: <object> }` — action fields live under
  `.result` (use those for `$.result.<field>` wiring); `metadata` is credit/refund accounting when
  the runner reports it. A `result` of `null` with `metadata.status` `SUCCESS_NO_DATA` means the
  action ran fine and found nothing — that is a valid result, not an error.
  Discover `packageId`/`actionKey` with `clay workflows actions list`
  (see `/workflows-discover-actions`), and the input shape with `clay workflows actions schema`.
- `clay workflows code test --file <path|-> [--inputs <json|file|->] [--tools <json|file|->] [--packages <csv>]`
  — runs Python in a sandbox to test code before adding it to a node. The file must define
  `handler(context)` returning a dict. `--inputs` backs named calls such as
  `context.get_input("email")`; `get_input()` requires a key and has no zero-argument form. `--tools`
  (a JSON array of `{actionKey, actionPackageId}`) backs `context.call_tool()`, and
  `--packages` installs extra pip packages. Exits 0 even on handler failure — inspect
  `isError` in the JSON, not the exit code.

Both are single-shot previews. External CLI users have per-user daily caps (defaults ~25 action
tests and ~10 code tests, overridable per workspace). Clay's built-in GTM Agent and Workflows
Sculptor are exempt.
Use them to confirm an input/output shape,
never to enrich or process a batch of records: for that use a managed routine
(`clay routines runs start`), a table column, or a workflow node, none of which are subject to
those caps.

`rate_limited` (HTTP 429, exit 4) includes daily caps and temporary throttling. If the message
says the daily allowance is exhausted, stop testing; do not sleep or retry in this session.
`details.retryAfter` gives the delay in seconds.

### Triggers

- Get: `clay workflows triggers get <triggerId>` — trigger ids come from `clay workflows graph get`,
  which returns them alongside the nodes; a workflow id is not accepted here.
- Create: `clay workflows triggers create <workflowId> --input <json|file|->` — the one trigger
  command that takes a workflow id. Its output is a confirmation, not the trigger — see the wiring
  note below. The writable shape is dynamic per trigger type — read an existing trigger first, same
  pattern as nodes. When no trigger of the target type exists to read, the core writable fields per
  type: `audience_segment` = `triggerType, segmentId, entityType ("CONTACT"|"ACCOUNT")`;
  `audience_signal` = `triggerType, signalId (signal.id, "sig_…"), entityType`;
  `audience_scheduled` = those plus `scheduleConfig`; `scheduled` = `triggerType, scheduleConfig`;
  `webhook` / `manual` = `triggerType, inputSchema`. `clay_table` triggers cannot be created
  from here — they are wired from inside a Clay table ("Invoke Workflow" action).
  For the `scheduleConfig` shape and the remaining trigger types, read
  `clay workflows triggers create --help` — it is the single source for the field detail.
- Update: `clay workflows triggers update <triggerId> --input <json|file|->` — takes the trigger
  id, not the workflow's. Only the fields in `--input` change.
- Delete: `clay workflows triggers delete <triggerId>` — trigger id again.
- CSV: `clay workflows triggers csv upload|run|remove <triggerId>` — link a CSV file to a
  `csv_upload` trigger and run one workflow run per row. See `csv-triggers.md`.

**Webhook payloads:** the trigger URL (`webhookUrl` on `triggers get`) accepts a JSON body. An
object body becomes the run inputs as-is, so `inputSchema` describes the object and downstream
nodes read `$.email`. A top-level array body is stored whole under `payload`, never spread into
index keys, so declare `"payload": { "type": "array", "items": { … } }` in `inputSchema` and read
`$.payload[0].email` (or iterate it in a list-mode node with `listEntriesRef` `$.payload`). Senders
like HubSpot post arrays of events, so check the sender's shape before writing the schema. When you
control the sender, post an object.

**Audience multi-segment sharing:** multiple `audience_segment` triggers (different `segmentId`s)
may share one trigger node when they have the **same trigger type** and the **same outgoing edge**.
Multiple `audience_scheduled` triggers may share a node when they also have the **same schedule**.
Pass an explicit `workflowNodeId` to bind/share; omit it (or pass `createTriggerNode: true`) to get
a new node. Do not mix `audience_segment` with `audience_scheduled` on one node. `audience_manual`
is a run companion created by the UI/run path — do not create it via the CLI.

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
per lead), inline on one node. **When not:** a single aggregate step over the whole list — leave
`listMode` off; and when the fan-out needs its own graph step (per-item concurrency or retries, or
a downstream reduce), use map/reduce nodes instead.
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
Before wiring a node with `incomingEdges` from a trigger's `workflowNodeId`, check the default
summary for an edge already leaving that trigger node —
`clay workflows graph get <workflowId> | jq '.summary.edges[] | select(.sourceNodeId == "<triggerNodeId>")'`.
If it already has a target, do not add another direct edge; add work downstream instead, or ask
the user whether to rewire. Before validating or running, each trigger must be connected to one
first executable node.

## Capabilities without a `clay workflows` command

Building a workflow often touches adjacent surfaces — tables, functions, audiences — that have
their own CLI commands elsewhere rather than a `clay workflows` subcommand:

- **Table schema** — `clay tables columns list <tableId>` (abbreviated) or
  `clay tables columns get <tableId>` (full settings).
- **Table rows** — `clay tables query-live <tableId> --query <clayql>`, against live Postgres.
  It takes ClayQL directly — write the query yourself off the columns above; there is no
  natural-language query option. Don't reach for `clay tables query` instead — that reads a
  different store (synced ClickHouse, gated on Enterprise sync).
- **Bulk enrichment migration** — for a known bulk enrichment table, use
  `clay tables columns get <tableId>` to determine the
  source origin and column DAG. When a source includes `audience`, use its configuration
  (global when `isGlobal`; otherwise `segments[].id`). Do not assume every bulk enrichment is
  Audiences-backed.
  `clay tables rows list <tableId> --limit <n>` is only an optional,
  unfiltered, unordered sample (`n` at most 20): it returns `truncated: true`, accepts and returns no
  cursor, and completed passthrough rows may already be deleted. Never treat it as a complete source dataset.
- **One audience segment** — `clay audiences get <audienceId>`, which includes the filter AST that
  selects its records.
- **Audience record fields** — `clay audiences fields list` with `--entity-type people` or
  `--entity-type companies` returns the ids for `upsert-audiences-record` (see `audiences.md`).
  Mind the two vocabularies: the flag is `people`/`companies`, while `upsert-audiences-record`
  still wants `entityType: "CONTACT"`/`"ACCOUNT"`.
- **Function schemas** — `clay functions get <functionId>` returns `inputSchema` and `outputSchema`.
  `clay workflows actions list` carries the `functionId` to pass it.
- **Listing what exists** — one command per resource kind: `clay workflows list`,
  `clay tables list`, `clay functions list`, and
  `clay audiences list --entity-type people|companies` for audience segments.

The raw CPJ Search DSL has no CLI command; `clay searches query-mode`
covers Clay search itself (see the `searches` skill). When a capability isn't listed here and has no
`clay` command, it's genuinely unavailable rather than hidden — tell the user that instead of
hunting for a command that will not appear.
