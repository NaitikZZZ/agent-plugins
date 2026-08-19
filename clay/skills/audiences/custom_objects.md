# Deals and other custom objects

Read this whenever the request touches **deals** or **opportunities** — including
any of the GTM phrasings in "Recognizing deal language" below.

**Deals are filterable — but a deal query is rooted at people or companies.** Any
deal criterion you can name (won, open, stage, amount, close date, deal source,
CRM role) is expressible; you write it as a predicate inside a **people** or
**companies** search rather than as a filter over deals. That is Clay's data model,
not a CLI limitation, and it is exactly what the product UI does: open the Filters
panel on People and there is a **Deals** section — Is won, Stage, Amount, Close
date, Deal creation date, Role — sitting alongside People attributes. Read
"Filtering deals" below before you conclude anything is unsupported.

## What a deal is in Audiences

A deal is a **custom object** — a third record type alongside people and
companies. Opportunity is the only custom object type that exists today, so
"deal", "opportunity", and "custom object" all mean the same records.

| Where you are           | Spelling                                |
| ----------------------- | --------------------------------------- |
| CLI `--entity-type`     | `deals`                                 |
| CLI output `entityType` | `"deals"`                               |
| Filter AST `entityType` | `CUSTOM`                                |
| Filter `dataPath` root  | `opportunity`                           |
| CRM source              | Salesforce `Opportunity`, HubSpot deals |

Deals link to both companies and people: one deal belongs to an account and can
have several associated contacts (with CRM roles such as "Decision Maker").

## Deals are read-only

Deals only enter a workspace through a CRM sync. There is no way to create,
update, or delete one from the CLI, and the `upsert-audiences-record` action
takes `ACCOUNT` or `CONTACT` only — it cannot write a deal. If a user asks to
create or edit a deal, say so and point them at their CRM; do not reach for a
workaround.

## What the CLI supports today

| Command                                 | `deals`?                                            |
| --------------------------------------- | --------------------------------------------------- |
| `audiences records get`                 | **Yes**                                             |
| `audiences records search-count`        | **Yes — whole population only** (see below)         |
| `audiences records search-ids`          | **Yes — whole population only** (see below)         |
| `audiences fields list`                 | **Yes**                                             |
| `audiences fields create/update/delete` | No — deals are read-only                            |
| `audiences fields segments`             | No — no audience can reference a deal field         |
| `audiences list` / `create`             | No — audiences exist over people and companies only |

Passing `--entity-type deals` to any of the "No" rows exits 2 with
`validation_error` and `must be one of: people, companies.` That is the expected
answer, not a bug to retry or work around.

```bash
clay audiences records search-count --entity-type deals              # how many deals in the workspace
clay audiences records search-ids   --entity-type deals              # their ids, --limit per page + .cursor
clay audiences records get --entity-type deals --ids 20384191        # field values, max 100 ids
```

`--archived` works on both search commands for deals, same as for people and
companies.

### `--entity-type deals` is the whole-population case, not the query case

The two search commands take `deals`, but with **no scope**: `--audience-id`, or a
`--filter` with any clauses in it, exits 2 with `validation_error` asking for an
unfiltered scope. The filter compiler resolves a query against a people or company
base entity, so `--entity-type deals` has nothing to hang a predicate on.

```bash
clay audiences records search-count --entity-type deals                          # ✅ every deal — the denominator
clay audiences records search-ids   --entity-type deals                          # ✅ every deal id — a full export
clay audiences records search-count --entity-type deals --filter ./won.json      # ❌ validation_error
clay audiences records search-count --entity-type deals --audience-id audseg_a   # ❌ validation_error
```

Use `--entity-type deals` for the two questions it answers well — the total deal
count (a denominator for any rate) and a full enumeration. Every **selective** deal
question goes through the next section instead.

## Deal field ids

Every id here is usable both as a filter predicate (on the `opportunity` root) and
as a key in `records get` output. `fields list --entity-type deals` enumerates a
workspace's deal fields; these seven exist in **every** workspace, so you can write
filters against them without listing first:

| Field id           | Meaning                                          |
| ------------------ | ------------------------------------------------ |
| `opportunity_name` | Deal name                                        |
| `stage`            | Pipeline stage, as a CRM-specific string         |
| `amount`           | Deal value                                       |
| `close_date`       | Close date (actual once closed, expected before) |
| `opportunity_type` | Deal type, e.g. new business vs renewal          |
| `is_closed`        | Boolean — the deal has reached a terminal stage  |
| `is_won`           | Boolean — the terminal stage was a win           |

Three Clay-managed fields are filterable too — they are the UI's "Deal creation
date", "Deal last updated", and "Deal source":

| Field id           | Meaning                          |
| ------------------ | -------------------------------- |
| `created_at`       | When the deal record was created |
| `updated_at`       | When it last changed             |
| `origin_source_id` | Which sync brought it in         |

So "deals created since April" is a `created_at` `After` predicate on the
`opportunity` root, same shape as any other deal filter.

`records get` returns the rest of the Clay-managed set as well
(`origin_source_type`, `sources`, `is_draft`, `external_source_sync_status*`).
Anything beyond those is a CRM property mapped into the workspace, and it varies
per workspace. Listing the deal fields is how you discover those ids and their
data types:

```bash
clay audiences fields list --entity-type deals > /tmp/deal-fields.json
jq -r '.data[] | "\(.id)  \(.dataType)  \(.name)"' /tmp/deal-fields.json
```

**Prefer the booleans over `stage`.** Stage strings come from the CRM and vary by
workspace (HubSpot emits `closedwon`, `presentationscheduled`; Salesforce uses
its own set). `is_won` / `is_closed` are normalized, so build on those and treat
`stage` as a label to display, not a value to guess.

## Recognizing deal language

These phrasings all mean deal records. When you see one you are in this file, and
the query is a **people or companies** search carrying the predicate in the right
column — see "Filtering deals" below.

| The user says                                                                                                             | Predicate                              |
| ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| closed won, closed-won, won, we won, new logo, new customer, "our customers"                                              | `is_won` is `True`                     |
| closed lost, closed-lost, lost, we lost, lost to a competitor, no-decision                                                | `is_closed` `True` + `is_won` `False`  |
| open pipeline, open deals, active deals, in flight, live deals, still working                                             | `is_closed` is `False`                 |
| pipeline, pipegen, pipeline generation, pipeline coverage, "in the funnel"                                                | deals exist at all, usually open       |
| deal stage, sales stage, discovery, qualification, demo/presentation, proposal, quote, contract sent, negotiation, verbal | `stage`                                |
| deal size, deal value, ACV, ARR, MRR, TCV, bookings, contract value, average selling price                                | `amount`                               |
| close date, expected close, closing this quarter, slipped, pushed                                                         | `close_date`                           |
| forecast, forecast category, commit, best case, upside                                                                    | `stage` / `close_date` + `amount`      |
| win rate, conversion rate, sales cycle, days to close, velocity                                                           | `is_won` + `created_at` / `close_date` |
| new business, expansion, upsell, cross-sell, renewal, churn, downgrade                                                    | `opportunity_type`                     |
| deal owner, AE, account executive, rep, book of business                                                                  | a workspace-specific owner field       |

Quota, attainment, and net revenue retention are **derived** numbers — Clay
stores the deals, not the target. Compute them from `amount` and say what you
divided by.

## Filtering deals: root the query at people or companies

**This is the main path for every selective deal question.** A people or companies
filter reaches into their deals with a cross-entity `BinOp` — `entityType:
"CUSTOM"` plus an `opportunity` `dataPath` root. Any deal field works as the
predicate, so "who has a closed-won deal", "accounts with a deal over $50k", and
"deals created since April" are all one search:

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "BinOp",
      "key": "is_won",
      "dataPath": ["opportunity", "field", "is_won"],
      "operator": "True",
      "entityType": "CUSTOM"
    }
  ]
}
```

```bash
clay audiences records search-count --entity-type companies --filter ./won.json   # how many accounts
clay audiences records search-ids   --entity-type companies --filter ./won.json   # their ids
clay audiences records get --entity-type companies --ids <ids>                    # org_name, domain, …
```

Swap `--entity-type people` for the same filter to get the **contacts** on matching
deals instead of the accounts, and combine deal predicates with ordinary people or
company predicates in one `GroupOp` (won deals **and** `title` contains "VP").

**Pick the root by who the user is asking about.** Both roots see the same deals —
they differ in what comes back:

| Root        | Returns                            | Use when                                                                  |
| ----------- | ---------------------------------- | ------------------------------------------------------------------------- |
| `companies` | the accounts the deals belong to   | "which customers…", "accounts with open pipeline", anything account-level |
| `people`    | the contacts attached to the deals | "who should I email", "champions on won deals", anything person-level     |

**The person or company _is_ usually the answer.** A deal-shaped question is almost
always really a who-question — who to email, which accounts to prioritize, whose
renewal is coming. Rooting at people or companies hands that back directly, which is
why this shape is the right one rather than a detour. Lead with those records, and
reach for deal detail only when the user actually wants per-deal figures.

### `Role` is the one deal field with a different path

A contact's CRM role on a deal ("Decision Maker", "Champion") is not an
`opportunity` field. It lives on the relationship, so it uses a different root and
a `metadata` segment, and it only works with `--entity-type people`:

```json
{
  "type": "GroupOp",
  "combinationMode": "And",
  "items": [
    {
      "type": "BinOp",
      "key": "opportunity_role",
      "dataPath": ["opportunity_role", "metadata", "roles"],
      "operator": "Contain",
      "value": "Decision Maker",
      "entityType": "CUSTOM"
    }
  ]
}
```

It takes `Contain` / `NotContain` / `Empty` / `NotEmpty` only — no equality.

### Two deal predicates in one `And` group must be satisfied by the same deal

`is_won` `True` plus `amount` greater than 10000 matches an account only if a
single deal is both won _and_ over 10000 — an account holding a won small deal and
a separate large open one does **not** match. So "accounts with a won deal that
also have a big deal" is two searches whose ids you intersect yourself, not one
filter. State which reading you used when you report the answer; the difference is
easy to get wrong and changes the number.

## What to say when the answer must be per-deal

The people/company root answers "who", and that covers most deal questions. Two
things it does not give you, worth naming rather than working around:

- **Counts are of records, not deals.** `search-count --entity-type companies
--filter ./won.json` is "how many **accounts** have a won deal", not how many won
  deals exist — an account with three won deals counts once. So "how many deals are
  in negotiation" has no single-call answer: report the account count with that
  wording, and use `search-count --entity-type deals` if a total-deal denominator
  helps. Never present an account count as a deal count.
- **No record → deal-id walk in the CLI.** `records get` returns a person's or
  account's own fields, not their related deal ids, so after a match you cannot list
  _which_ deals matched. Report the people or companies (usually what was wanted),
  and use `records get --entity-type deals` only for deal ids the user supplies or
  you already hold.
- **Deals cannot be sorted yet.** Neither search command orders its results and
  neither takes a sort flag — `search-ids` returns ids in ascending id order — so
  "the biggest wins", "top 10 by amount", and "the most recent closes" have no
  server-side answer. A true top-N means pulling every candidate's `amount` through
  `records get` and sorting locally, which is the full walk the audiences skill's
  budgets warn you off. Narrow until the candidate set is small enough to pull in
  full — a shorter close-date window first, then one stage or owner — and say the
  ranking covers that window rather than implying it is the workspace's top N.

And one hard limit:

- **No deal audiences.** `audiences create` rejects `deals`, so "save this as an
  audience" for a deal-shaped question means saving the **company** or **people**
  audience whose filter references deals. That audience stays live as deals change,
  same as any other.
