# Preserve table configuration in a workflow

Read the full column settings and reconstruct formulas, input mappings, run
conditions, and referenced resources before building. Copy the configuration into
the target workflow; source rows are optional test inputs, not a dataset to migrate.

Preserve the column dependency graph, not the table's visual column order. Columns
that depend only on trigger inputs or a shared formula belong on independent
branches. Do not chain an unrelated classifier, saved Claygent, or function behind
an enrichment action: that adds a new dependency and can suppress those columns
when the enrichment fails. Apply each column's original run condition to its own
branch and join only where downstream logic actually consumes multiple results.

For a saved Claygent, reuse its actual ID and bind every referenced variable. For a
table function, resolve the referenced table with `clay functions get <functionId>`
and attach that exact ID as `tableId` for a `clay_function` tool. A node named after
the function does not preserve the reference. Read back the node after creation to
confirm the function ID and input mappings were persisted. Function nodes expose
their referenced table IDs in `subroutineIds`.

Bring a Send table data (`route-row`) column's destination table into the workflow
instead of writing to it, so each result that would have been a destination row stays in
the workflow, and recreate the destination table's columns as nodes. A list column
(`type: "list"`) sends one row per item, so use list mode (in `SKILL.md`); a row column
(`type: "row"`, the default) needs none. Each row from a list column also gets the
column's shared `rowData` and `nestedData` under `parent`, so give the per-item nodes
those values too. Workflows can't add rows to a Clay table, so don't use `route-row`,
and say so when you report the conversion. If something relies on the destination table
receiving new rows, tell the user.

Translate legacy Use AI columns into native agent nodes using the original prompt,
model, input bindings, and structured output schema. Inspect supported settings;
disclose any table-only setting that cannot be represented instead of claiming all
settings were copied.

Decide how empty optional table cells map to workflow inputs and outputs before
testing. A string-only output cannot contain null. Normalize empty text values when
that preserves the source formula's behavior, or use a supported nullable schema.
Keep boolean and numeric values typed, and preserve the difference between an
empty value and a meaningful false or zero.

Validate the persisted graph and test the final configuration. In the handoff,
distinguish preserved configuration from paths that actually executed, and identify
any untested changes.

## Search-backed tables

For a DSL search source, read `sources[].search` in `clay tables columns get`.
Use the saved `dslQuery` and `entityType` to create the equivalent Find leads
trigger; do not reconstruct filters from the table name or replace the search
with a manual trigger. If `/workflows-find-leads` is in your catalog, follow it
for the trigger schema.
Preserve the source result limit in the query when the workflow source uses a
query limit. A smaller test limit is temporary: restore the intended limit after
testing and read back the saved source.

The table projection and workflow projection can expose different field paths.
Inspect the actual trigger outputs before mapping derived fields. Preserve
fallback expressions such as LinkedIn URL or profile URL; do not guess structured
location fields by splitting a display string. Disclose any source field or
setting the workflow surface cannot represent.
