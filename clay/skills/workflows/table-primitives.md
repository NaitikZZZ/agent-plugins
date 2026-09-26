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
