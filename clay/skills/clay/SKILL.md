---
name: clay
description: Clay — start here. A table of contents for working with Clay and which skill to use for each thing — audiences (the workspace's own people/companies/deals), search (find net-new people/companies), routines (run Clay-managed and custom functions), tables (query/export data), the CLI (ephemeral programmatic access), the Public API (build services on Clay), workflows (build automations), and feedback. Read this first to answer "what can I do with Clay?"
---

# Working with Clay

Clay is a GTM (go-to-market) data and automation product. This skill is a table of
contents: find what you want to do and go to that skill.

## How to work

Whatever you're doing in Clay, work transparently so the user can follow along:

- **Narrate as you go.** Say what you're about to do and why, then what happened —
  in plain language, referring to things by their human-readable names.
- **Summarize, don't dump.** Turn raw command output (JSON, `jq`, `diff`) into a
  short takeaway, table, or count. Reserve raw output for when the user asks.
- **Confirm the workspace once.** The first time you use Clay in a session, run
  `clay whoami` and tell the user which workspace (id) and user you're authenticated
  as. If it's wrong, they can switch with `clay logout` then running `clay login`
  again. If whoami fails on auth, run the `setup` skill.

## Answering "what can I do with Clay?"

When a user asks what they can do, you are describing **Clay's product**, not your own
abilities. Get the framing right:

- **Position it as Clay's, and as theirs to run.** Say "Clay lets you…" and "you can…",
  not "skills I have," "here's what I can run for you," or "what you can do through me."
  These are Clay capabilities the user drives; you're just the interface.
- **Don't call them "playbooks."** The surfaces below (audiences, searches, routines, tables,
  workflows, the CLI, the API) are Clay **primitives and product surfaces** — describe them
  as what they are. "Playbook" is wrong and confusing.
- **Lead with concrete, show-off use-cases, not a menu of verbs.** Ground the answer in
  outcomes the user recognizes. Good examples to draw from (pick a few relevant ones, don't
  list all):
  - "Build a net-new account list matching my ICP (industry, size, region, and revenue)."
  - "Find decision-makers by title and seniority, then enrich them with verified work emails and phone numbers."
  - "Enrich a list of leads or accounts with firmographics and contact data."
  - "Score a list of records against my ideal-customer profile."
  - "Run a saved Clay function or workflow over a batch of inputs and collect the results."
  - "Query a table and export the rows matching a filter."
  - "Check how many credits are left, or estimate what a routine costs before running it."

  Then offer to run one — the goal is a first win, not reciting a catalog.

## Choosing the right primitive

Clay exposes these core primitives (callable from the plugin/CLI/API):

| Primitive               | What it's for                                                                       |
| ----------------------- | ----------------------------------------------------------------------------------- |
| **Audiences**           | The workspace's own people, companies, and deals — read and segment what they have  |
| **Searches**            | Find companies and people using Clay's GTM database                                 |
| **Routines**            | Run Clay-managed functions, custom functions, and existing Workflows                |
| **Workflows**           | Build multi-node automations when an existing routine cannot do the job             |
| **Tables** (Enterprise) | Query **existing** Clay tables only — you **cannot** create tables programmatically |

Follow this escalation order — reach for the earliest option that fits. Often a request
uses more than one primitive, and they need to flow together — see Combining primitives.

1. **Audiences** — is the question about _their_ people, companies, contacts, leads, accounts,
   customers, or deals? Start here. Counts, fill rates, lookups, and saved segments all live in
   Audiences, and reading what the workspace already has is free and instant. Only move on once
   you know the data isn't already there — searching or enriching first spends the user's money
   to rediscover data they have. Don't route a question about their own records to the
   tables entry-point skill; that's a separate surface, and only when the user names a table.
2. **Search** — need a list of people or companies **new to the workspace**? Open the
   `search` skill. Finding prospects or accounts is Search: not a table query, not a
   routine, and not a workflow. Public search supports **people and companies only** —
   not jobs. A request framed around job posts (e.g. "companies hiring for X") can't be
   a public search: approximate it with the closest company or people filters, then use
   a routine to enrich or score for the real signal.
3. **Routines** — run an existing function or workflow. Open the `routines` skill. Prefer a
   Clay-managed function for standard enrichment (work email, phone, job title, company
   domain, tech stack, funding, etc.) — check `clay routines list` before promising one or
   building anything. Custom functions cover team-specific logic (account scoring, inbound
   routing, CRM cleanup, etc.) and **cannot be built from the CLI/API**; they can only be
   **invoked**. If no existing routine fits, either surface that a new custom function must
   be created in the Clay app, or build a workflow in the CLI (next step).
4. **Workflows** — multi-node flows built from a code editor or the CLI. **Only use
   when an existing routine genuinely can't do it**: embedded custom code, >100k-row batches, step-by-step
   run inspection, or inputs from diverse sources stitched together.
5. **Tables** — query data from an **existing** table the user named. Finding people or
   companies is Search, not a table query. You **cannot** create new tables through the
   plugin/CLI/API; if a task needs a new table, surface that to the user.

If you are unsure what to surface, ask the user. There are often multiple ways to accomplish the same task,
so when the choice is ambiguous, do not pick one arbitrarily.

## Combining primitives

The escalation above picks a starting surface, not a single primitive for the whole
request. Often a request uses several primitives that need to flow together. These are
some example next hops:

- **Write into Audiences in bulk** — a routine whose workflow uses `upsert-audiences-record`
  (for example after a Search or CSV import). See `routines`; build the workflow in the `workflows-cli` skill's
  `audiences.md` if none exists.
- **Act on a saved audience now** — pull its current members with `clay audiences`, then
  run a routine over them (same as Search pages). One-shot; it does not keep firing. See
  `audiences` and `routines`.
- **Trigger a workflow off an audience** — when membership changes, not a one-shot routine
  run. See the audience trigger section in the `workflows-cli` skill's `audiences.md`.

## Cost & budget

**Credit-consuming actions spend the user's money — always check in with the user and get
their explicit go-ahead before running one.** Never kick one off on your own initiative or
"to be helpful." First show the user the estimated cost and the remaining balance, then wait
for them to confirm.

Actions that consume credits (or count against plan/search limits) and require a check-in
first include running a routine, testing or resuming a workflow, and some types of search.

Before running a credit-consuming routine, check its per-item `estimatedCreditCost`
(`clay routines get <id>`) against the remaining workspace balance (`clay credits`). See the
`routines` skill for how to size a run against the balance.

## Skills

| Skill                 | Use it for                                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `audiences`           | Any question about the workspace's own people/companies/deals — counts, fill rates, lookups, and segments.                |
| `search`              | Finding net-new people or companies in Clay's GTM database — prospects and accounts that aren't already in the workspace. |
| `routines`            | Creating a routine from an existing function/workflow, running a saved routine, and fetching its results.                 |
| `tables-cli`          | Reading, querying, and exporting data from an existing Clay table via the CLI (creating tables is not supported).         |
| `cli`                 | Ephemeral, programmatic access to Clay capabilities from a shell — run a routine, query a table, search, etc.             |
| `public-api`          | Building services and applications on top of Clay over HTTP.                                                              |
| `workflows-cli`       | Building and editing Clay workflows via the CLI.                                                                          |
| `workflows-vs-tables` | Explaining the difference between Workflows and Tables, or recommending which to use.                                     |
| `clay-feedback`       | Sending a bug report or product feedback to the Clay team.                                                                |

## If another Clay MCP is connected

If `clay-for-reps` (the Clay MCP for sales reps) is also connected in your session,
ignore its tools entirely. That server is designed for interactive conversational prospecting
in chat apps (ChatGPT, Claude.ai) — it shares the same Clay workspace but is a completely
different product. Use the `clay` CLI and these skills for all automation, data enrichment,
and GTM operations.

## First-time setup

Run the `setup` skill.

## Keeping Clay up to date

Check `clay update --check` to make sure you're on the latest CLI version. To update Clay — update the plugin (which
pins the `clay` CLI it bundles) — use the `update` skill.
