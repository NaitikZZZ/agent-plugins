---
name: workflow-snapshots
description: Clay workflows — version history: view snapshots, see what changed, and restore or undo a previous state. Use when the user mentions snapshots or asks to undo an edit.
allowed-tools: Bash(clay *), Bash(jq *), Read
---

# Workflow snapshots & version history


Snapshots are immutable, point-in-time captures of the entire workflow graph — nodes, edges, prompts, scripts, tools, and positions.

## Key concepts

- **Automatic creation**: A snapshot is created automatically before every `edit_node` call and when a run starts
- **Content-addressed**: Each snapshot has a SHA-256 hash of its contents. Identical workflow states deduplicate to the same hash
- **Immutable**: Once created, a snapshot never changes
- **Run isolation**: Runs are pegged to a specific snapshot. Editing the workflow doesn't affect in-flight runs

## CLI reference

Use the `clay` CLI. (In Codex/Cursor, run the `setup` skill once if `clay` isn't
found.) It needs only `CLAY_API_KEY`; the workspace is resolved from the key.
Output is JSON — pipe it to `jq`.

### List recent snapshots

```bash
clay workflows snapshots list <workflowId>
```

Returns `{ data: [...] }`, newest first, each with `id`, `hash`, `createdAt`, and
`nodeCount`/`edgeCount`. So `data[0]` is the most recent snapshot.

### Show a snapshot (whole graph, or one node)

```bash
clay workflows snapshots get <workflowId> <snapshotId>
clay workflows snapshots get <workflowId> <snapshotId> --node-id <nodeId>
```

Returns the full captured graph: `nodes` (with types, prompts, code, tools) and
`edges`. `--node-id` narrows `nodes` to a single node (edges are left intact).

### Diff two snapshots

There is no built-in diff. Fetch both and compare with `jq` — but this raw `diff`
is the underlying mechanism, not the thing you show the user:

```bash
clay workflows snapshots get <workflowId> <oldSnapshotId> | jq '.nodes' > old.json
clay workflows snapshots get <workflowId> <newSnapshotId> | jq '.nodes' > new.json
diff <(jq -S . old.json) <(jq -S . new.json)
```

**Translate the diff into a plain-language change summary** rather than pasting the
raw `diff` output — e.g. "Node _Find Email_'s prompt changed; the edge _Research →
Draft_ was removed; a new _Score Lead_ agent node was added." When the change alters
the graph's structure (nodes or edges added/removed/rewired), render before/after
Mermaid diagrams so the user can see it, not just read it (see `workflows/presenting.md`).

The only built-in diagram command always renders the workflow's **current** graph:

```bash
clay workflows diagram <workflowId> | jq -r '.diagram'   # always the current graph
```

There's no diagram command for an arbitrary snapshot id, so hand-write a small
node/edge list from that snapshot's `nodes`/`edges` for its side. Label the diagrams
by the direction of the change: "before" is the state you're changing *from*, "after"
is the state you're ending up *with* — and use the command above for whichever side is
the current graph. When previewing a restore (see "Restore to a snapshot" below), the
restore overwrites the current graph with the snapshot, so the current graph is the
"before" and the snapshot you're restoring to is the "after".

### Restore to a snapshot

```bash
clay workflows snapshots restore <workflowId> <snapshotId>
```

Restores the workflow to the exact state captured in the snapshot. This replaces
all current nodes, edges, prompts, scripts, and tools. Restore is destructive and
does NOT snapshot the current graph first — the pre-restore state is recoverable
only if it was already captured (snapshots are taken automatically before each
edit and at run start). If the current graph has unsnapshotted changes you might
want back, run `snapshots list` first and note the latest snapshot id.

**Before restoring, show the user what will change.** Summarize the difference
between the current graph and the target snapshot in plain language, and — when the
structure differs — show before/after diagrams (see "Diff two snapshots" above),
so the user can confirm the revert before it destructively overwrites the current
state. After restoring, render the restored graph so they can see the result.

## Common workflows

### Undo the last edit

Every `edit_node` call creates a snapshot before applying changes, so the most
recent snapshot (`data[0]`) is the state right before the last edit.

```bash
# Find the most recent snapshot, then restore to it
snap=$(clay workflows snapshots list <workflowId> | jq -r '.data[0].id')
clay workflows snapshots restore <workflowId> "$snap"
```

To undo multiple edits, pick an older snapshot id from the list instead.

### Compare current state to a previous version

List snapshots, then diff two of them with the `jq` recipe above.

### Review what a run executed

Since runs are pegged to snapshots, inspect the exact workflow state a run used by
looking up the run's snapshot id and passing it to `snapshots get`.
