# Writing an audience filter

A filter is a `ConditionalExpressionGroup` AST — the same shape an audience
stores, `records search-ids` / `search-count` accept ad hoc, and the Clay UI's
filter editor produces. `clay audiences create --help` carries the full node and
operator reference; read it once instead of guessing at the shape.

The parts that cost the most time:

- **`key` + `dataPath` name the field.** `dataPath` is
  `[<root for the entity type>, "field", <fieldId>]` — see the entity-type table
  in `SKILL.md` for the root. `key` is the field id.
- **A filter is always rooted at people or companies, never deals** — and that is
  how you filter by deals. An `opportunity` `dataPath` is a cross-entity predicate
  _inside_ a people or companies filter, which is the supported way to ask any deal
  question; `--entity-type deals` itself accepts no `--filter`. See
  `custom_objects.md`.
- **`Empty`, `NotEmpty`, `True`, and `False` take no `value`.** Every other
  operator does. The relative-time operators (`WithinLast` / `WithinNext` and
  their `Not-` forms) take a numeric `value` plus `timeUnit` (`day` / `week` /
  `month`).
- **Match on nothing to match everything:**
  `{"type":"GroupOp","combinationMode":"And","items":[]}`.
- **Node `id`s are UI bookkeeping** — they are stripped, so never author them.

## Node types

- `GroupOp` — combines child `items` with `combinationMode` (`And` / `Or`).
  Nestable, so mixed AND/OR logic is a group inside a group.
- `BinOp` — compares one field to a `value`: `{ key, dataPath, operator, value, entityType }`.
- `ColOp` — a collection/subquery: `{ key, dataPath, operator, condition, entityType }`,
  where `condition` is a `GroupOp` and `operator` is `AllItems` / `AnyItems` / `NoItems`.
- `AggOp` — an aggregate over a group: `{ aggregation: { groupByPath, operator, value }, expression, entityType }`.

## Copy-paste starting point

People with no email:

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "BinOp",
      "key": "email",
      "dataPath": ["contact_entity_field_values", "field", "email"],
      "operator": "Empty",
      "entityType": "CONTACT"
    }
  ]
}
```

Swap `email` for any field id from `clay audiences fields list`, and swap the
`CONTACT` / `contact_entity_field_values` pair for `ACCOUNT` /
`account_entity_field_values` to filter companies.

## Validate before you create

**Run `records search-count --filter` before `audiences create`.** One call tells
you both that the AST is valid and that it selects a sane number of records —
cheaper than create → inspect → archive, and it catches an inverted operator
(`Empty` vs `NotEmpty`) that a successful create would not.

```bash
clay audiences records search-count --entity-type people --filter ./missing-email.json
clay audiences create --entity-type people --name "Missing emails" --filter ./missing-email.json
```

Report the count to the user before creating the audience — a filter that matches
0 or matches everything is usually a mistake worth catching together.

## Copy a filter you know works

An existing audience is the most reliable reference for a workspace-specific
field, since `get` returns the filter already stripped of editor ids:

```bash
clay audiences get <audienceId> | jq .filter        # inspect a known-good filter
clay audiences get <audienceId> | jq .filter | clay audiences create --entity-type people --name "Copy" --filter -
```
