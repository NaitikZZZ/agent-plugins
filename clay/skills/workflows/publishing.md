# Publishing workflows (draft vs live)

Editing a workflow updates the **draft**. **Publishing** is a separate step that
makes that draft the **live** version automation runs. Until the user publishes,
live audience / schedule / webhook (etc.) automation does not pick up your edits.

When the user wants automation to go live (or to ship draft changes after a prior
publish), run `clay workflows publish <workflowId>`. Do not claim that `edit_node`,
a test run, or `snapshots restore` published anything.

Speak to the user in **draft / live / publish** terms. Do not explain internal
mechanics (how triggers bind to snapshots, sentinel ids, etc.).

## Concepts

| Concept                    | Meaning                                                                                                                                                              |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Draft**                  | The current editable graph (nodes, edges, prompts, tools). A never-published workflow is still a first draft.                                                        |
| **Draft-history snapshot** | An automatic freeze of the graph (before `edit_node`, at run start). Undo/history only — not a release. See `/workflows-snapshots`.                                  |
| **Publish**                | Ship the current draft as a numbered live version. Non-paused triggers go live on that version; paused triggers stay paused (publish does not silently resume them). |
| **Live**                   | The published version automation runs. After the first publish, further draft edits do **not** change live automation until the user publishes again.                |

Draft-history snapshots and published versions share the same snapshot store;
publish marks a snapshot as a numbered release. Re-publishing an unchanged draft
keeps the same version.

After a workflow is published, individual triggers can be **paused** or **resumed**
in the UI (`live` ↔ `paused`). That does not publish a new workflow version.
Triggers still waiting in **draft** become live when the workflow is published —
there is no separate per-trigger publish control.

## Restore is not publish

`clay workflows snapshots restore` (see `/workflows-snapshots`) replaces the
**draft** only. It does **not** change what is live. Undoing an edit does not roll
back live automation — the user must publish again if they want live automation to
match the restored draft.

## What you should do

1. Build against the draft (`edit_node`, `validate_workflow`). To verify **unpublished**
   edits, use a plain / manual `clay workflows runs test` (no `--audience-segment`) —
   that exercises the current draft. Do not treat `--audience-segment` as a draft test
   after the workflow is published (that path runs the live version; see below).
2. After a successful draft e2e test, if the user wants automation to run this graph,
   run `clay workflows publish <workflowId>`. Use `--name` only to label the
   published version, not to rename the workflow.
3. If they edit a workflow that is already live, remind them that draft changes
   stay draft-only until they publish again — and that audience-trigger backfills
   still run the previous live version until then.
4. Never invent a publish API call or imply that restore/undo shipped a release.

## Which runs exercise draft vs live

| How you start the run                                                                               | What graph it uses                                           |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Plain / manual `clay workflows runs test` (optional `--inputs`)                                     | **Current draft**                                            |
| `clay workflows runs test --audience-segment …` (and live audience / schedule / webhook automation) | **Live** version after publish — not unpublished draft edits |

When checking whether draft changes work, use a manual test run. Use `--audience-segment`
to exercise the published/live path (or real automation), not to validate draft-only edits.
