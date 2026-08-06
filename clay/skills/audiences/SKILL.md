---
name: audiences
description: Clay Audiences — create, inspect, and edit audiences (saved segments), their field definitions, and their records via the `clay audiences` CLI. Use when the user wants to segment people or companies ("create an audience of…", "who has no email?"), add/rename/hide a field on people or companies, or count and list the records matching a filter. Also covers deals/opportunities — closed-won, closed-lost, open pipeline, deal stage, deal size/ACV/ARR, close date, forecast, win rate, renewal, expansion ("which accounts have closed-won deals?") — see its `custom_objects.md`. For writing values onto records, see the `workflows` skill.
---

# Clay Audiences

Audiences is Clay's CRM-shaped store of **people** and **companies** (plus deal
records). An **audience** — also called a saved segment — is a named filter over
one entity type. Nothing is copied into it: it selects records live, so its
membership changes as records change.

Read this before any audiences work. Three supporting references:

- `filters.md` — writing the filter AST that defines an audience. Read it before
  you author or edit a filter.
- `custom_objects.md` — **deals / opportunities.** Read it before anything that
  touches them, including GTM phrasings that mean deals: closed-won, closed-lost,
  open pipeline, deal stage, deal size / ACV / ARR, close date, forecast, win rate,
  renewal, expansion, churn, "our customers". Deals are read-only and most
  `clay audiences` commands reject `--entity-type deals`.
- The `workflows` skill's `audiences.md` — writing values onto records
  (the `upsert-audiences-record` action) and triggering a workflow off an audience.

**Read with the CLI, write records with the action.** `clay audiences` covers
every Audiences primitive — segments, fields, and reading records — but it has no
command that writes a field value onto a record. That is the
`upsert-audiences-record` action's job.

## One entity type, three spellings

The same entity types are named differently depending on where you are. Get this
mapping right up front — it is the most common source of wasted round trips.

| CLI `--entity-type` | Filter AST / action `entityType` | Filter `dataPath` root        |
| ------------------- | -------------------------------- | ----------------------------- |
| `people`            | `CONTACT`                        | `contact_entity_field_values` |
| `companies`         | `ACCOUNT`                        | `account_entity_field_values` |
| `deals`             | `CUSTOM` (Opportunity)           | `opportunity`                 |

`clay audiences records get` is the only command that accepts `deals` today —
every other command takes `people` or `companies` only. CLI output can also carry
`entityType: "deals"`. For anything deal-shaped, read `custom_objects.md` first.

Workflow **triggers** use the middle spelling: an `audience_segment` trigger's
`segmentId` is the audience id from `clay audiences list`, and its `entityType`
is `CONTACT` / `ACCOUNT`, not `people` / `companies`.

## Audiences (saved segments)

```bash
clay audiences list --entity-type people          # id, name, entityType (no filter); 50/page, pass back .cursor
clay audiences get <audienceId>                   # same, plus the full filter AST
clay audiences create --entity-type people --name "Missing emails" --filter ./filter.json
clay audiences update <audienceId> --name "…" --description "…" --filter ./filter.json
clay audiences archive <audienceId>               # soft delete, idempotent; records untouched
```

- `create` and `update` take `--filter` as inline JSON, **a file path, or `-` for
  stdin**. Use a file or stdin for anything non-trivial — inline JSON in a shell
  triggers an approval prompt and invites quoting mistakes.
- `update` replaces the whole filter; there is no partial merge, and entity type
  is immutable after creation. Omitted flags are left alone.
- `get` returns an id-free filter, so `clay audiences get <id> | jq .filter` pipes
  straight back into `create --filter -` to clone an audience.

## Fields

Field ids are what record payloads and filter ASTs key on, and they are scoped
to an entity type — every subcommand takes `--entity-type`.

```bash
clay audiences fields list --entity-type people                       # every field: id, name, dataType, fieldType, hidden
clay audiences fields list --entity-type people --filter id=email     # narrow by id (repeatable, comma-separated)
clay audiences fields list --entity-type people --include-system      # system fields, hidden by default
clay audiences fields create --entity-type people --name "Lead score" --data-type number
clay audiences fields update <fieldId> --entity-type people --hidden true
clay audiences fields delete <fieldId> --entity-type people
clay audiences fields segments <fieldId> --entity-type people         # audiences whose filter references the field
```

- `fields list` returns exactly what the `get_audience_schema` MCP tool's
  `recordFields` returns — both read the same API with system fields excluded.
  Either one gives you the ids for `upsert-audiences-record`; prefer whichever
  surface you are already in.
- **Names are not ids.** Account "company name" is `org_name`. Never guess an id
  from a display name.
- `create` silently uniquifies a taken name (`"Tier (2)"`) — read the returned
  `name` and `id` rather than assuming the one you passed.
- Before `update --data-type` or `delete`, run `fields segments <fieldId>`: a
  delete rewrites saved filters with those clauses **removed**, changing what
  those audiences match. Empty `data` means nothing is affected.
- Default and system fields reject `--name` and `--data-type` changes and cannot
  be deleted; `--hidden`, `--order`, and `--description` still work.

### Default field ids

Present in every workspace, so you can write a filter against these without
listing fields first:

- **people** — `name`, `first_name`, `last_name`, `email`, `linkedin_url`,
  `phone`, `title`, `signal_summary`
- **companies** — `org_name`, `domain`, `headquarters_location`, `linkedin_url`,
  `sfdc_owner_id`, `signal_summary`, `technographics`

Anything else is workspace-defined — get its id from `fields list`.

## Records

```bash
clay audiences records search-count --entity-type people --audience-id <id>   # count a scope server-side
clay audiences records search-ids   --entity-type people --audience-id <id>   # matching ids, 50/page + .cursor
clay audiences records get --entity-type people --ids 1,2,3                   # field values, max 100 ids
```

Scope for both search commands (`--audience-id` and `--filter` are mutually
exclusive):

- neither flag → every record of the entity type
- `--audience-id <id>` → a saved audience's records
- `--filter <json|file|->` → an ad-hoc filter, matching exactly what an audience
  built from that filter would hold

Add `--archived` to either to search archived records instead of live ones.

The search commands take `people` or `companies` only; `records get` also takes
`--entity-type deals` to read deal (opportunity) records by id. To _find_ deals,
filter companies or people by their deals — see `custom_objects.md`.

`search-ids` returns ids only — feed them to `records get --ids` in batches of
100 for field values, keyed by field id (unset fields may be omitted). Records
not found are omitted rather than erroring. To size a scope, use `search-count`,
not a paging loop over `search-ids`.

## Error codes

Every command prints JSON on stdout and a typed error envelope on stderr. Exit
codes: `0` ok, `2` validation, `3` auth, `5` network, `6` not-found. `3` on an
audiences command usually means Audiences is not enabled for the workspace —
that is a workspace-config answer for the user, not something to retry.
