---
name: search
description: Clay search — find people, companies, or job postings in Clay's GTM database from a natural language query, and page through the matches. Use when the user wants to search Clay for prospects/accounts/jobs, not query an existing table.
allowed-tools: Bash(clay *), Bash(jq *)
---

# Clay search

Search Clay's GTM database with a natural language query. Clay turns the query into
structured filters and returns matching records — people, companies, or job postings.

This is different from `tables` (which queries data already in a Clay table) and from
`workflows` (multi-step automations). Reach for search when the user wants to _find_
prospects, accounts, or jobs.

## How it works

A search is a two-step, forward-only iterator:

1. **Create** the search from a query + source type — you get back a `searchId`.
2. **Advance** it with `next` to pull the next page of records. Repeat while `hasMore`
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
clay search create --query "<natural language>" --source-type <people|companies|jobs>
```

Returns `{ "searchId": <string> }`. `--source-type` is one of `people`, `companies`, or
`jobs`.

### Get the next page

```bash
clay search next <searchId> [--limit <n>]
```

Returns `{ "data": [ ... ], "hasMore": <boolean> }`. `--limit` is the page size; omit it
to use the server default. Call again while `hasMore` is `true` to keep paging.

## Common workflows

### Search and grab the first page

```bash
sid=$(clay search create --query "growth engineers in San Francisco" --source-type people | jq -r '.searchId')
clay search next "$sid" --limit 25 | jq '.data'
```

### Page through all results

```bash
sid=$(clay search create --query "seed-stage fintech startups" --source-type companies | jq -r '.searchId')
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
clay search create --query "growth engineers in San Francisco" --source-type people

# 3. Pull a page of records and pipe them straight into a run with the proper input schema
clay search next <searchId> --limit 25 | jq '{items: [.data[] | {id: .id, inputs: {name: .name}}]}' |
clay routines runs start <id> --input -
```
