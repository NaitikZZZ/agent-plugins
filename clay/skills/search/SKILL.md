---
name: search
description: Clay search — find people or companies in Clay's GTM database with advanced queries and page through the matches. Use when the user wants to search Clay for prospects/accounts, not query an existing table.
allowed-tools: Bash(clay *), Bash(jq *)
---

# Clay search

Search Clay's GTM database with advanced queries and return matching records — people or
companies.

**Audiences** is the workspace's own people and companies — read and segment what they already have.
**Search** is Clay's GTM database for net-new lists. This is not the tables entry-point skill (querying
data already in a table) and not the workflows entry-point skill (automations). Reach for Search when the
user wants to _find_ prospects or accounts not in the workspace yet.

## How it works

A search is a three-step, forward-only iterator:

1. **Discover** the query grammar and queryable fields.
2. **Create** the search and receive a `searchId`.
3. **Run** it to pull the next page of records. Repeat while `hasMore`
   is `true`.

There is no cursor: the iterator's position lives server-side and can't be replayed, so
each `run` call returns the records after the previous one.

Before authoring a query, run `clay search query-mode reference` and use the returned
reference. It supports criteria in the source type's fields catalog, cross-entity filters,
and nested Boolean logic.

Run `clay search --help` (and `clay search <cmd> --help`) for flags and output shapes.
If `clay` isn't on PATH or `clay whoami` fails on auth, run the `setup` skill.

## When a criterion isn't supported

Check the reference before deciding whether it can express the criteria. Do not invent a
field or operator that is not in the reference.

If the query can't express a criterion, split the request into what search _can_ do and what
a routine does:

1. Search on the closest available built-in criteria to get a candidate set (e.g. industry,
   size, or title criteria that approximate the intent).
2. Feed those results into a saved routine that enriches or scores each record for the
   attribute the user actually asked about, then filter or act on that routine's output.

Tell the user the field isn't a native search filter and offer this search → routine path
rather than returning nothing. See the `routines` skill and "Next: enrich or persist the
results" below for the handoff.

## Warn before large generic searches

Before `create`, if the ask is generic and large — few criteria beyond something like
industry + location (e.g. "all tech companies in NYC") — stop and suggest refining first.
Offer 2–3 concrete narrowing options search can express (company size, title/seniority,
open roles, tech stack, products and services, named companies/domains, or a small result
`limit`). Do not create until they confirm or narrow; continue with the broad query only if
they insist. Skip when the ask is already clearly bounded. After they insist, still apply
**Warn before near-exhaustion** below when relevant.

## Start a search

```bash
clay search query-mode reference
clay search query-mode create --query '<query>'
```

`create` returns `{ "searchId": "srch_..." }`.

### Paging

`run` returns `{ "data": [ ... ], "hasMore": <boolean>, "periodQuota"?: { "limit", "used",
"remaining", "resetsAt" } }`. `--limit` is the page size. `periodQuota` appears on
successful `run` responses only — not on `create`; do not invent values.
Reuse the same `searchId`; each call returns the next page. Continue while `hasMore` is
`true`, but after every `run` that returns `periodQuota`, apply **Warn before
near-exhaustion** below before the next page. Stop when `hasMore` is `false`, or when the
quota is near exhaustion — unless the user explicitly asks to continue.

```bash
clay search query-mode run <searchId> [--limit <n>]
```

## Warn before near-exhaustion

When `periodQuota` is present, before a create or run that will consume `N` results (the
volume you plan to pull, not the full match set), check `remaining − N`. If that would
leave under 15% of `limit`, stop and ask first:

> This search will return {{N}} results and leave {{remaining − N}} of your period quota.

Continue only if they confirm. Otherwise offer a smaller pull that keeps at least 15%
remaining, or stop. Skip when `periodQuota` is absent.

Example: `limit` 10,000, `remaining` 2,000, `N` 1,500 → 500 left (5% of cap) → warn.

## Quotas (do not retry)

If a create or run fails with `quota_exceeded` (exit 1, HTTP 402), the workspace has hit a
plan result cap (per-request, per-search, or period) or a credit/usage limit. Short backoff
will not help. Read the error message and choose one of:

1. **Per-request size** — message names a "per request" limit. Retry once with
   `--limit` ≤ that cap (e.g. free plans often allow 50 per request).
2. **Partial per-search or period remaining** — message says you have already requested
   `N` of a single-search or period cap of `M`, and `N < M`. The page was larger than the
   remaining allowance. Retry once with `--limit` ≤ `M − N` to collect the last allowed
   results, then stop. Example: cap 50, already requested 40, `--limit 20` failed → retry
   with `--limit 10`.
3. **Fully exhausted / credits** — already requested `N` equals the cap `M`, period reset
   date is the only path forward, or the message is about credits/usage. **Stop paging.**
   Tell the user to upgrade or wait for the named period reset. For upgrade, get the
   workspace id, then share the plan selector:

```bash
clay whoami | jq -r '.workspace.id'
```

`https://app.clay.com/workspaces/<workspaceId>/billing/plan-selector`

Do not retry.

`validation_error` (exit 2) means malformed input (bad flags/filters/query), not a quota.
`rate_limited` (exit 4) is a short HTTP 429 backoff and may be retried after `details.retryAfter`.

## Next: enrich or persist the results

Search only _finds_ records. After paging results, offer one of two plugin paths — both via
`clay routines runs start`. See the `routines` skill for sizing runs and fetching results.

### Enrich without persisting

**Prefer Clay-managed routines for standard enrichment.** Before reaching for the raw
action catalog or building a workflow, list the full, paginated routines set and check
`source: managed` first. Clay ships managed routines that cover most enrichment — e.g.
**Work Email**, **Company Domain**, **Enrich Person**, **Enrich Person and Find Contact
Details**, **Company Job Openings**. Match on each routine's input schema
(`clay routines get <id>`), not its name. Only fall through to the action catalog or a new
workflow when no managed or custom routine fits.

```bash
clay routines list
```

```bash
clay routines get function:tbl_abc123
```

After Search has results, use the **`routines` skill** to start the run: list or get
the routine schema, then `clay routines runs start`.

### Persist into Audiences

When the user wants Search hits **kept in the workspace**, find or create a routine whose
underlying workflow upserts with `upsert-audiences-record`. If none exists, build the workflow
using the `workflows` skill's `audiences.md`, then to run in bulk see the `routines` skill.
