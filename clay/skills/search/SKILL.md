---
name: search
description: Clay search — find people or companies in Clay's GTM database from structured filters, and page through the matches. Use when the user wants to search Clay for prospects/accounts, not query an existing table.
allowed-tools: Bash(clay *), Bash(jq *)
---

# Clay search

Search Clay's GTM database with structured filters and return matching records —
people or companies.

This is different from `tables` (which queries data already in a Clay table) and from
`workflows` (multi-step automations). Reach for search when the user wants to _find_
prospects or accounts.

## How it works

A search is a three-step, forward-only iterator:

1. **Discover** valid filters for the source type with `fields`.
2. **Create** the search from structured filters + source type — you get back a `searchId`.
3. **Advance** it with `next` to pull the next page of records. Repeat while `hasMore`
   is `true`.

There is no cursor: the iterator's position lives server-side and can't be replayed, so
each `next` call returns the records after the previous one.

## CLI reference

Use the `clay` CLI. (In Codex/Cursor, run the `setup` skill once if `clay` isn't found.)
It needs only `CLAY_API_KEY`; the workspace is resolved from the key. Output is JSON —
pipe it to `jq`. Run `clay search --help` (and `clay search <cmd> --help`) for the
authoritative flags and output shapes.

### Start a search

```bash
clay search fields --source-type <people|companies>
clay search create --source-type <people|companies> --filters '<json>'
```

The fields command returns the allowed filter names, types, enum values, and guidance.
Create returns `{ "searchId": <string> }`. `--source-type` is one of `people` or
`companies`.

### Get the next page

```bash
clay search next <searchId> [--limit <n>]
```

Returns `{ "data": [ ... ], "hasMore": <boolean> }`. `--limit` is the page size; omit it
to use the server default. Call again while `hasMore` is `true` to keep paging.

## Common workflows

### Search and grab the first page

```bash
clay search fields --source-type people | jq '.fields[].name'
sid=$(clay search create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}' | jq -r '.searchId')
clay search next "$sid" --limit 25 | jq '.data'
```

### Page through all results

```bash
sid=$(clay search create --source-type companies --filters '{"industries":["Software Development"],"funding_amounts":["1m_5m","5m_10m","10m_25m"]}' | jq -r '.searchId')
while :; do
  page=$(clay search next "$sid" --limit 50)
  echo "$page" | jq -c '.data[]'
  [ "$(echo "$page" | jq -r '.hasMore')" = "true" ] || break
done
```

## Next: enrich or act on the results

Search only _finds_ records. To do something with them — enrich them (emails, firmographics,
social profiles, …) or take an action (send to a CRM, trigger outreach, etc.) — feed the
results into a saved routine. Read the `routines` skill (`skills/routines/SKILL.md`)

**Search → results → run a routine is the common workflow.** Most searches aren't the end
goal — the user wants the found records enriched or acted on. After returning results,
default to offering this next step rather than stopping at the raw matches.

```bash
# 1. Pick the routine first and check what inputs it expects (its input schema)
clay routines list
clay routines get <id>

# 2. Find people, then read the searchId from the output and page through records
clay search fields --source-type people
clay search create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}'

# 3. Pull a page of records and pipe them straight into a run with the proper input schema
clay search next <searchId> --limit 25 | jq '{items: [.data[] | {id: .id, inputs: {name: .name}}]}' |
clay routines runs start <id> --input -
```
