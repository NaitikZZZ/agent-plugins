# CSV upload triggers

A `csv_upload` trigger runs a workflow from a CSV file: each row starts one run,
with the row's cells as the run inputs. It is the CLI equivalent of dropping a CSV
onto a CSV trigger in the workflow editor.

The trigger must already exist and be a `csv_upload` trigger, and every command takes its
id. To get the id, list the workflow's trigger ids with `clay workflows graph get
<workflowId>` (`.triggers[].id`) — this is available on both the CLI and Sculptor. To
create the trigger: on the CLI use `clay workflows triggers create <workflowId> --input
'{"triggerType":"csv_upload"}'` (its result carries the new `resourceId`); in Sculptor,
where `triggers create` isn't available, create it from the trigger in the workflow editor,
then read its id with `graph get`.

A `csv_upload` trigger goes live when it's created — with no separate publish step — but it
can still be paused from the editor, and a paused trigger makes `csv run` fail. Neither
`triggers get` nor `graph get` reports a trigger's status, so a run failing as not-live is the
signal that it is paused. On the CLI resume it with
`clay workflows triggers update <triggerId> --input '{"status":"live"}'`; in Sculptor, which
has no `triggers update`, have the user resume the trigger in the editor.

A run always executes the workflow's **current draft graph** as it stands the moment the
run starts — there is no way to run the last published version through this command. Any
unpublished edits run against the real CSV rows. So if the draft has changes the user
doesn't want to run, reconcile the draft first (revert/restore — see `publishing.md`);
publishing would promote those same draft edits to live, not avoid them. Don't tell a
user a CSV run is production-equivalent just because the trigger is "live."

## Upload, run, unlink

The flow has three commands, each taking the trigger id:

1. **Link a file** — `clay workflows triggers csv upload <triggerId> --file leads.csv`.
   Uploads the file and links it to the trigger, inferring one string column per CSV
   header as the trigger's input schema. This does not start a run. Header names must be
   unique: a duplicate header silently overwrites the earlier column of the same name in
   every run (both the schema and the per-row values collapse on the last one). Check the
   returned `csvFile.headers` for duplicates and have the user rename them before running.
2. **Run it** — `clay workflows triggers csv run <triggerId>`. Starts one run per row
   of the linked file and returns a `batch.key`. Add `--limit <n>` to process only the
   first `n` rows. Rows run asynchronously; the command returns once the batch is
   accepted, not when every run finishes. This spends credits — one workflow run per row,
   so a large file multiplies the workflow's per-run cost. Before running, follow the
   credit preflight in the `clay` skill: show the estimated cost (row count × per-run cost)
   and the remaining balance, and get explicit confirmation. Use `--limit` when the user
   wants a small test batch first.
3. **Unlink** — `clay workflows triggers csv remove <triggerId>`. Detaches the file.
   The inferred input schema is kept, so downstream input mappings survive.

Before running, make sure the trigger is connected to a downstream node. On a freshly
created workflow the trigger is unwired, so `csv run` is still accepted and returns a
`batch.key`, but every row's run then fails with "Workflow has no initial node." Wire the
trigger to the first node of the workflow (in the editor, or with `clay workflows nodes` /
graph edits) before running.

Uploading a new file replaces the linked one, but does not rewrite existing downstream
mappings: if the new file's headers differ, source paths that referenced removed columns
resolve to `undefined`. Compare the new headers against the workflow's input mappings and
rewire stale references before running.

`csv run` is **not** idempotent: each invocation assigns a fresh batch and starts the
whole file again — a lost response or timeout that you retry doubles the runs and credit
spend. (Re-running deliberately reuses each row's identity, which groups the reruns under
the same subjects; it does not dedupe them away.) After an ambiguous result, inspect the
workflow's runs before rerunning rather than blindly retrying.

## Attaching a CSV the user uploaded in chat

`--file` takes any readable path, so a file the user attached in chat is uploaded the
same way. An attached file is available at `/mnt/session/uploads/<filename>` (the
session tells you the filenames it mounted). Attach it to the trigger the user or you
created with, e.g.:

```
clay workflows triggers csv upload <triggerId> --file /mnt/session/uploads/leads.csv
```

If no `csv_upload` trigger exists yet, create one first (see above — CLI
`triggers create`, or the editor in Sculptor), then upload. Confirm the columns from the
command's `csvFile.headers` (watch for duplicates), then run only after the credit
preflight and the user's explicit go-ahead.

## Downstream mappings

Each header becomes a top-level string field on the run input, so downstream nodes
read `$.<header>` (e.g. `$.email`). Headers are stored verbatim as literal keys, but
`$.<header>` paths interpret dots and brackets as nested lookups — so any header that
is not a simple identifier (contains a space, dot, or bracket) must use escaped bracket
notation: a header `Company Name` is `$["Company Name"]`, and a literal `company.name`
column is `$["company.name"]`, not `$.company.name` (which would look for a nested
`name`). Inspect the linked columns with
`clay workflows triggers csv upload … | jq -r '.csvFile.headers[]'` or
`clay workflows triggers get <triggerId>`.
