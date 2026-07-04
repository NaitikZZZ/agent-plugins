# Presenting workflow work to the user

Building, testing, and editing a workflow is a back-and-forth. The user can only
follow along if you **narrate what you're doing in plain language** and **show a
visual whenever structure matters**. These are the defaults for every workflow
skill (building, testing, simplifying, optimizing, snapshots); each skill adds
its own skill-specific visual on top.

## Defaults

- **Narrate each meaningful step.** Before a change, say what you're about to do
  and why; after it, say what happened. One or two plain sentences per step —
  refer to nodes and actions by their **human-readable names** (e.g. "Find Work
  Email (Clay)"), never internal `actionKey`s or raw node ids.
- **Summarize, don't dump.** Never make raw JSON, `jq`, or `diff` output the
  primary answer. Turn it into a short Markdown table, a count, or a one-line
  takeaway. Reserve raw output for when the user explicitly asks for it.
- **Prefer a visual when structure matters.** Reach for the right one:
  - **Mermaid graph** — for the workflow's shape (nodes and how data flows).
  - **Markdown table** — for records, per-node results, or a list of findings
    (e.g. node → inputs → output → status).
  - **Status checklist / progress line** — for long-running work (a run you're
    polling, a batch of edits).

## Show the user the graph

Users can't follow what you're building unless you show them. How you do that
depends on where you're running:

- **If the user has the Clay workflow editor open** (i.e. you're the in-product
  assistant), they already see the graph canvas update live as you create and
  wire nodes — so you don't need to redraw it. Lean on that: after each change,
  narrate in plain language what you added and how it connects, and point them at
  the node you just touched.
- **In a headless environment** (Claude Code, Cursor, a shell — no visual
  editor), the user has no canvas, so render the structure yourself. If the CLI
  supports it, `clay workflows diagram <workflowId>` returns
  `{ "format": "mermaid", "diagram": <string> }` — a Mermaid `flowchart TD` where
  node shape encodes node type (trigger, agent, tool, code, conditional,
  map/reduce, …) and conditional edges are labelled with their branch. Present it
  as a ```mermaid code block so it renders inline:

  ```bash
  clay workflows diagram <workflowId> | jq -r '.diagram'
  ```

  If the command isn't available in your CLI version, fall back to a
  plain-language walkthrough or a small hand-written node/edge list — don't retry
  it as if it were a transient error.

In either environment: do this at the natural checkpoints (after `read`, after
building/editing, after `validate_workflow --prettier`, and when narrating a
run) — redraw the diagram for changes that visually change the graph (nodes or
edges added, removed, or rewired), and for prompt-only or config-only edits just
narrate what you changed, since the graph looks the same. Whenever you do render,
surface the workflow's `url` (from `clay workflows get`/`create`) so the user can
open the real editor, and pair the diagram with a one-paragraph walkthrough of
what each node does and where its inputs come from.

## Annotating a diagram with run status

When narrating a test run, don't just list node results — locate them in the
graph. Either annotate each node label with a status marker or place a small
"node → status" table beside the `clay workflows diagram` render, so the user
sees **where** in the flow a result (or failure) came from:

| Marker | Meaning   |
| ------ | --------- |
| `[x]`  | completed |
| `[!]`  | failed    |
| `[~]`  | running   |
| `[ ]`  | not yet reached |

Pair the annotated graph with the node-by-node walkthrough (see `testing.md`),
then call out any failures and what you'll change.
