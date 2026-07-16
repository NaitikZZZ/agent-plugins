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
3. **Run** it to pull the next page of records. Repeat while `hasMore`
   is `true`.

There is no cursor: the iterator's position lives server-side and can't be replayed, so
each `run` call returns the records after the previous one.

## CLI reference

Use the `clay` CLI. (In Codex/Cursor, run the `setup` skill once if `clay` isn't found
or `clay whoami` fails on auth.) Authenticate with `clay login`; the workspace is
resolved from the stored session. Output is JSON — pipe it to `jq`. Run
`clay search --help` (and `clay search <cmd> --help`) for the authoritative flags and
output shapes.

### Start a search

```bash
clay search filters-mode fields --source-type <people|companies>
clay search filters-mode create --source-type <people|companies> --filters '<json>'
```

The fields command returns the allowed filter names, types, enum values, and guidance.
Create returns `{ "searchId": <string> }`. `--source-type` is one of `people` or
`companies`.

### When the user asks to filter on a field that isn't a built-in filter

Search only accepts the filters returned by `clay search filters-mode fields` for that source type.
When the user wants to narrow by an attribute that isn't in that list — e.g. "companies
using React", "Series A companies", "people who recently changed jobs", "accounts with a
specific tech in their stack", or any derived/enriched signal — **do not invent a filter
name or force it into an existing filter.** Search cannot evaluate it. Funding amount
ranges are native filters, but funding stages are not.

Instead, split the request into what search _can_ do and what a routine does:

1. Search on the closest available built-in filters to get a candidate set (e.g. industry,
   size, or title filters that approximate the intent).
2. Feed those results into a saved routine that enriches or scores each record for the
   attribute the user actually asked about, then filter or act on that routine's output.

Tell the user the field isn't a native search filter and offer this search → routine path
rather than returning nothing. Read the `routines` skill (`skills/routines/SKILL.md`) for how
to find and run one, and see the "Next: enrich or act on the results" section below for the
handoff command.

### Run the search

```bash
clay search filters-mode run <searchId> [--limit <n>]
```

Returns `{ "data": [ ... ], "hasMore": <boolean> }`. `--limit` is the page size; omit it
to use the server default. Call again while `hasMore` is `true` to keep paging.

## Common workflows

### Search and grab the first page

Run these one at a time, reading the `searchId` from the `create` output and passing it
literally to `run`:

```bash
clay search filters-mode fields --source-type people | jq '.fields[].name'
```

```bash
clay search filters-mode create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}'
```

`create` prints `{ "searchId": "srch_..." }`. Take that id and page:

```bash
clay search filters-mode run srch_abc123 --limit 25 | jq '.data'
```

### Page through all results

Paging is just repeated `run` calls with the same `searchId`. Run `run`, read `hasMore`
from its output, and if it's `true` run the exact same command again — the server advances
the iterator for you.

```bash
clay search filters-mode create --source-type companies --filters '{"industries":["Software Development"],"country_names":["United States"]}'
```

```bash
clay search filters-mode run srch_abc123 --limit 50 | jq -c '.data[]'
```

Repeat that `run` line while the page's `hasMore` is `true`; stop when it's `false`.

## Next: enrich or act on the results

Search only _finds_ records. To do something with them — enrich them (emails, firmographics,
social profiles, …) or take an action (send to a CRM, trigger outreach, etc.) — feed the
results into a saved routine. Read the `routines` skill (`skills/routines/SKILL.md`)

**Search → results → run a routine is the common workflow.** Most searches aren't the end
goal — the user wants the found records enriched or acted on. After returning results,
default to offering this next step rather than stopping at the raw matches.

```bash
clay routines list
```

```bash
clay routines get function:tbl_abc123
```

```bash
clay search filters-mode create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}'
```

Then read the `searchId` from that output and pull a page straight into a run:

```bash
clay search filters-mode run srch_abc123 --limit 25 | jq '{items: [.data[] | {id: .id, inputs: {name: .name}}]}' | clay routines runs start function:tbl_abc123 --input -
```
