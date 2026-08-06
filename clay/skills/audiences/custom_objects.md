# Deals and other custom objects

Read this whenever the request touches **deals** or **opportunities** — including
any of the GTM phrasings in "Recognizing deal language" below. Deals behave
differently from people and companies in Clay, and most of the `clay audiences`
surface does not accept them yet, so guessing here wastes round trips.

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

| Command                                                     | `deals`?                                            |
| ----------------------------------------------------------- | --------------------------------------------------- |
| `audiences records get`                                     | **Yes** — the one command that accepts it           |
| `audiences records search-ids`                              | No                                                  |
| `audiences records search-count`                            | No                                                  |
| `audiences fields list` (and create/update/delete/segments) | No                                                  |
| `audiences list` / `create`                                 | No — audiences exist over people and companies only |

Passing `--entity-type deals` to any of the "No" rows exits 2 with
`validation_error` and `must be one of: people, companies.` That is the expected
answer, not a bug to retry or work around.

```bash
clay audiences records get --entity-type deals --ids 20384191        # field values, max 100 ids
```

## Deal field ids

`fields list` does not accept `deals`, so you cannot enumerate deal fields from
the CLI. These seven exist in **every** workspace and are safe to write filters
against without listing anything:

| Field id           | Meaning                                          |
| ------------------ | ------------------------------------------------ |
| `opportunity_name` | Deal name                                        |
| `stage`            | Pipeline stage, as a CRM-specific string         |
| `amount`           | Deal value                                       |
| `close_date`       | Close date (actual once closed, expected before) |
| `opportunity_type` | Deal type, e.g. new business vs renewal          |
| `is_closed`        | Boolean — the deal has reached a terminal stage  |
| `is_won`           | Boolean — the terminal stage was a win           |

`records get` also returns Clay-managed fields (`created_at`, `updated_at`,
`origin_source_id`, `origin_source_type`, `sources`, `is_draft`,
`external_source_sync_status*`). Anything else in that output is a CRM property
mapped into the workspace — reading one deal is the only way to discover those
ids.

**Prefer the booleans over `stage`.** Stage strings come from the CRM and vary by
workspace (HubSpot emits `closedwon`, `presentationscheduled`; Salesforce uses
its own set). `is_won` / `is_closed` are normalized, so build on those and treat
`stage` as a label to display, not a value to guess.

## Recognizing deal language

These phrasings all mean deal records. When you see one, you are in this file —
and usually the answer is a company or people search filtered by deals (next
section), not a deal search.

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

## Finding deals: filter companies or people by their deals

You cannot search deals directly (no `search-ids` for `deals`), but a filter over
companies or people **can** reach into their deals with a cross-entity `BinOp` —
`entityType: "CUSTOM"` plus an `opportunity` `dataPath` root. This is how
"accounts with closed-won deals" gets answered:

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

The same filter works with `--entity-type people` to get the contacts attached to
matching deals, and it combines with ordinary company predicates in one `GroupOp`
(e.g. won deals **and** `org_name` in a region).

**Two deal predicates in one `And` group must be satisfied by the same deal.**
`is_won` `True` plus `amount` greater than 10000 matches an account only if a
single deal is both won _and_ over 10000 — an account holding a won small deal
and a separate large open one does **not** match. So "accounts with a won deal
that also have a big deal" is two searches whose ids you intersect yourself, not
one filter. State which reading you used when you report the answer; the
difference is easy to get wrong and changes the number.

## Limits worth stating up front

- **No account → deal-id walk.** `records get --entity-type companies` returns the
  account's own fields and no related deal ids, so after finding matching accounts
  you cannot list _which_ deals matched through the CLI. Report the accounts, and
  get deal detail only when the user supplies or you already know a deal id.
- **No deal audiences.** `audiences create` rejects `deals`, so "save this as an
  audience" for a deal-shaped question means saving the **company** or **people**
  audience whose filter references deals.
- **No deal counts by stage from the CLI.** `search-count` cannot take `deals`, so
  "how many deals are in negotiation" is not answerable as a single count today;
  the closest answer is a count of _accounts_ with such a deal.
