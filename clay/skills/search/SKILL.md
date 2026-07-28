---
name: search
description: Clay search — find people or companies in Clay's GTM database with advanced queries and page through the matches. Use filters mode when the user prefers its older structure or has existing filters-mode searches. Use when the user wants to search Clay for prospects/accounts, not query an existing table.
allowed-tools: Bash(clay *), Bash(jq *)
---

# Clay search

Search Clay's GTM database with advanced queries and return matching records — people or
companies. Use filters mode when the user prefers its older structure or has existing filters-mode searches.

This is different from `tables` (which queries data already in a Clay table) and from
`workflows` (multi-step automations). Reach for search when the user wants to _find_
prospects or accounts.

## How it works

A search in either mode is a three-step, forward-only iterator:

1. **Discover** the available query syntax and fields for the mode you choose.
2. **Create** the search and receive a `searchId`.
3. **Run** it to pull the next page of records. Repeat while `hasMore`
   is `true`.

There is no cursor: the iterator's position lives server-side and can't be replayed, so
each `run` call returns the records after the previous one.

## Choose a search mode

Use advanced search by default. It is a superset of filters mode: it supports criteria in the
source type's fields catalog, cross-entity filters, and nested Boolean logic.

Before authoring an advanced query, run `clay search query-mode reference` and use the returned
reference. Use `filters-mode` when the user prefers its older structure or has existing filters-mode
searches.

## CLI reference

Use the `clay` CLI. (In Codex/Cursor, run the `setup` skill once if `clay` isn't found
or `clay whoami` fails on auth.) Authenticate with `clay login`; the workspace is
resolved from the stored session. Output is JSON — pipe it to `jq`. Run
`clay search --help` (and `clay search <cmd> --help`) for the authoritative flags and
output shapes.

## When a criterion isn't supported

Check the reference for the search mode you choose before deciding whether it can express the
criteria. Do not invent a field or operator that is not in the reference.

If neither mode can express a criterion, split the request into what search _can_ do and what
a routine does:

1. Search on the closest available built-in filters to get a candidate set (e.g. industry,
   size, or title filters that approximate the intent).
2. Feed those results into a saved routine that enriches or scores each record for the
   attribute the user actually asked about, then filter or act on that routine's output.

Tell the user the field isn't a native search filter and offer this search → routine path
rather than returning nothing. Read the `routines` skill (`skills/routines/SKILL.md`) for how
to find and run one, and see the "Next: enrich or act on the results" section below for the
handoff command.

## Start a search

### Advanced search (default)

Read the query reference, then create a search:

```bash
clay search query-mode reference
clay search query-mode create --query '<query>'
```

`create` returns `{ "searchId": "srch_..." }`.

#### Fetch the first page (advanced search)

```bash
clay search query-mode run <searchId> [--limit <n>]
```

Returns `{ "data": [ ... ], "hasMore": <boolean> }`. `--limit` is the page size; omit it
to use the server default. Call again while `hasMore` is `true` to keep paging.

#### Page through all results (advanced search)

Use the same `run` command with the same `searchId`. Each call returns the next page:

```bash
clay search query-mode run srch_abc123 --limit 50 | jq -c '.data[]'
```

Repeat that command while the page's `hasMore` is `true`; stop when it is `false`.

### Filters mode

Use filters mode when the user prefers its older structure or has an existing filters-mode
search. Discover the available fields, then create a search:

```bash
clay search filters-mode fields --source-type people | jq '.fields[].name'
```

```bash
clay search filters-mode create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}'
```

`create` returns `{ "searchId": "srch_..." }`.

#### Fetch the first page (filters mode)

```bash
clay search filters-mode run srch_abc123 --limit 25 | jq '.data'
```

Returns `{ "data": [ ... ], "hasMore": <boolean> }`. `--limit` is the page size; omit it
to use the server default.

#### Page through all results (filters mode)

Use the same `run` command with the same `searchId`. Each call returns the next page:

```bash
clay search filters-mode run srch_abc123 --limit 50 | jq -c '.data[]'
```

Repeat that command while the page's `hasMore` is `true`; stop when it is `false`.

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

Create an advanced search, then read the `searchId` from its output and pull a page straight
into a run:

```bash
clay search query-mode create --query 'select from people where experiences.any(is_current = true and job_title is_similar_to ("software engineer") and company.industry = "Software Development")'
```

```bash
clay search query-mode run srch_abc123 --limit 25 | jq '{items: [.data[] | {id: .id, inputs: {name: .name}}]}' | clay routines runs start function:tbl_abc123 --input -
```

For filters-mode searches, create the search:

```bash
clay search filters-mode create --source-type people --filters '{"job_title_keywords":["growth engineer"],"location_cities_include":["San Francisco"]}'
```

Then read the `searchId` from that output and pull a page straight into a run:

```bash
clay search filters-mode run srch_abc123 --limit 25 | jq '{items: [.data[] | {id: .id, inputs: {name: .name}}]}' | clay routines runs start function:tbl_abc123 --input -
```
