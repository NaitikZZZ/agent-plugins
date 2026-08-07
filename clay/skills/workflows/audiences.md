# Audiences in workflows

How Audiences shows up while building a workflow: writing records with
`upsert-audiences-record`, and triggering a workflow off an audience.

For everything else about Audiences — creating and editing audiences (saved
segments), managing field definitions, reading and counting records, and writing
filter ASTs — use the **`audiences` skill**. Do not rediscover the `clay audiences`
CLI here.

**Read with the CLI, write records with the action.** `clay audiences` has no
command that writes a field value onto a record, so any workflow step that
populates people or companies uses the action below.

## The backfill shape: audience → enrich → upsert back

This is the standard answer when a field the user wants is missing or sparse on
their records, and the most common reason to build a workflow over Audiences:

1. **Save an audience of the records that need the field** — an `Empty` filter on
   it, via `clay audiences create`. That audience is the work queue, and it drains
   itself as records get filled.
2. **Trigger the workflow on that audience** (`audience_segment`, below).
3. **Enrich** in a tool node.
4. **Write the result back** with `upsert-audiences-record`, looking the record up
   by `email` / `linkedin_url` (people) or `domain` (companies).

Propose this shape and get sign-off before building any of it — and lead with the
count, from `clay audiences records search-count`, so the user can see the size
and cost of what they are approving. Don't start creating nodes off an unconfirmed
plan.

Before proposing it, confirm the data really is missing: read the existing field
first (see the `audiences` skill's `answering-data-questions.md`). A workflow that
re-enriches data the workspace already has spends credits for nothing.

## Triggering a workflow off an audience

An `audience_segment` trigger's `segmentId` is the audience id from
`clay audiences list` or `clay audiences create`. Its `entityType` is `CONTACT` /
`ACCOUNT` — **not** the `people` / `companies` vocabulary the CLI flags use.

To backfill existing members through the workflow, see `testing.md`
(`clay workflows runs test <workflowId> --audience-segment <segmentId> --limit N`).

## upsert-audiences-record

This is the way to update Audiences records. Creates or updates a contact or account via `inputMappingConfig`. The config is a flat object with pipe-namespaced keys (`<group>|<fieldId>`) — never dot-notation, never nested.

When attaching this action to a tool node, use:

- `actionKey: "upsert-audiences-record"`
- `actionPackageId: "b1ab3d5d-b0db-4b30-9251-3f32d8b103c1"`

### Lookup vs record fields

- **Lookup fields** are the keys used to find an existing audience record. For contacts these are fixed (`email`, `linkedin_url`, `phone`); for accounts (`domain`, `linkedin_url`). The values you pass under `lookupFields|<id>` are matched against existing records — if any match, the record is updated; otherwise a new one is created.
- **Record fields** are the data written onto the matched (or newly created) record. These are workspace-defined and vary per workspace; call `get_audience_schema` (or `clay audiences fields list`) to discover the available ids.

### Required keys

- `entityType` (static) — `"ACCOUNT"` or `"CONTACT"`.
- `lookupFields|selectedLookupFields` (static array) — lookup-key field ids.
- `lookupFields|<id>` for every id above — value to match on.
- `recordFields|selectedRecordFields` (static array) — fields to write.
- `recordFields|<id>` for every id above — value to write.
- `recordFields|removeNullValues` (static bool) — `true` skips blanks; `false` overwrites with them.

Every id in a `selected*` array MUST have a matching `<group>|<id>` binding, or the action returns `ERROR_BAD_REQUEST`.

### Discover real field IDs

Call `get_audience_schema` with `entityType` first — schema ids and English names often differ (account "company name" is `org_name`). It returns `lookupFields` (fixed: CONTACT → `email`, `linkedin_url`, `phone`; ACCOUNT → `domain`, `linkedin_url`) and `recordFields` (workspace-defined).

### Worked example — account upsert

```json
{
  "entityType": { "type": "static", "value": "ACCOUNT" },
  "lookupFields|selectedLookupFields": {
    "type": "static",
    "value": ["domain"]
  },
  "lookupFields|domain": { "type": "reference", "expression": "{{domain}}" },
  "recordFields|selectedRecordFields": {
    "type": "static",
    "value": ["org_name", "domain"]
  },
  "recordFields|org_name": {
    "type": "reference",
    "expression": "{{org_name}}"
  },
  "recordFields|domain": { "type": "reference", "expression": "{{domain}}" },
  "recordFields|removeNullValues": { "type": "static", "value": true }
}
```
