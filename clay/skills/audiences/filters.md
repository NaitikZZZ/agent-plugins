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

## Filter by signal activity

Signal events captured on a record (see `SKILL.md`, "Signals write activities
onto records") are filterable through the `signal_events` dataPath root — this
is how "companies with a job posting in the last 30 days" is expressed, and it
is what the app's signal-based segments store.

Every example below is a whole filter, rooted at a `GroupOp` — `--filter` runs
`ConditionalExpressionGroup.safeParse`, so a bare `BinOp` or `ColOp` is rejected as
a `validation_error` before any request is made.

**Any event of a type within a window** — a `BinOp` whose `key` is the type's
aggregate-occurrences key and whose operator is a relative-time window:

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "BinOp",
      "key": "signal_JobPost_aggregate_occurrences",
      "dataPath": ["signal_events"],
      "operator": "WithinLast",
      "value": 30,
      "timeUnit": "day",
      "entityType": "ACCOUNT"
    }
  ]
}
```

The key is `signal_<Type>_aggregate_occurrences` where `<Type>` is the
`signal.type` spelling from `clay signals list`: `JobChange`, `JobPost`,
`NewHire`, `News`, `Promotion`, `LinkedinPostMentions`, `PersonTopicIntent`,
`CompanyTopicIntent`, `WebsiteVisitorTracking`. `Custom` and `FakeSignal`
events are not filterable this way.

**Events from one specific signal** — put the window clause and a `signal_id`
equality inside a `ColOp` over `signal_events`. The id is the `sig_…` value
(`signal.id` in `clay signals list` output — one of the few places that id,
rather than `td_…`, is what you need):

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "ColOp",
      "dataPath": ["signal_events"],
      "operator": "AnyItems",
      "entityType": "ACCOUNT",
      "condition": {
        "type": "GroupOp",
        "combinationMode": "And",
        "items": [
          {
            "type": "BinOp",
            "key": "signal_JobPost_aggregate_occurrences",
            "dataPath": ["signal_events"],
            "operator": "WithinLast",
            "value": 30,
            "timeUnit": "day",
            "entityType": "ACCOUNT"
          },
          {
            "type": "BinOp",
            "dataPath": ["signal_events", "signal_id"],
            "operator": "Equal",
            "value": "sig_abc123",
            "entityType": "ACCOUNT"
          }
        ]
      }
    }
  ]
}
```

**Event payload predicates go inside the same `ColOp` condition as the window
clause — never beside it in the root group.** Deeper `dataPath`s reach into the
event's data, e.g. `["signal_events", "data", "confidence"]` or
`["signal_events", "data", "jobPostData", "title"]`.

Clauses inside one `ColOp` condition lower to a **single** `signal_events` scan, so
they all have to hold for the **same event**. Two signal clauses sitting side by side
in the root group lower to **separate** scans, each free to match a different event —
so "a job post in the last 30 days" AND "title contains VP" would match a company
whose VP posting is two years old and whose recent posting is for an intern. Bind
them together instead:

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "ColOp",
      "dataPath": ["signal_events"],
      "operator": "AnyItems",
      "entityType": "ACCOUNT",
      "condition": {
        "type": "GroupOp",
        "combinationMode": "And",
        "items": [
          {
            "type": "BinOp",
            "key": "signal_JobPost_aggregate_occurrences",
            "dataPath": ["signal_events"],
            "operator": "WithinLast",
            "value": 30,
            "timeUnit": "day",
            "entityType": "ACCOUNT"
          },
          {
            "type": "BinOp",
            "dataPath": ["signal_events", "data", "jobPostData", "title"],
            "operator": "Contain",
            "value": "VP",
            "entityType": "ACCOUNT"
          }
        ]
      }
    }
  ]
}
```

Payload shapes differ per signal type; read a real event's shape (or an existing
segment's filter) before authoring one, and always keep the aggregate-occurrences
clause in the condition so the scan stays scoped to that signal type and window.

A signal `ColOp` does compose with ordinary **field** predicates in the root group —
ICP fit AND recent signal activity is the standard signal-based-play segment, and a
field predicate is evaluated against the record rather than an event, so there is no
event for it to disagree about. The rule above is only about two `signal_events`
clauses: those belong in one condition, not side by side. Validate with
`records search-count --filter` like any other filter.

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
