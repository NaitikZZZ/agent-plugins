---
name: tables
description: Clay tables — inspect, query, and export data from an existing table, via either the `table` MCP tool (schema + natural-language query, CSV export) or the `clay tables` CLI (list tables, run structured JSON queries with pagination, toggle API query sync)
---

## About Clay Tables

Clay is a GTM (go-to-market) data and automation product. Clay tables are similar to Excel or Google Sheets. Each table contains:

- **Fields (columns)**: Can be basic fields (text, numbers, booleans), formula fields (JavaScript expressions), or action/enrichment fields (fetch data, call APIs, run AI agents)
- **Records (rows)**: Usually represent companies or people
- **Sources**: Add rows to tables from external data (APIs, CSV imports, webhooks, Clay's database of 850m+ people and 60m+ companies)

## Not supported: creating tables

These surfaces only **read** from tables that already exist — inspect the schema, query data, and export it. **Creating a new table (or adding fields/columns to one) is not supported** via the `table` MCP tool or the `clay tables` CLI. If a user asks to create a table, tell them it isn't supported here and that they'll need to create the table in the Clay app first; you can then work with it once it exists.

## Two ways to work with tables

There are two surfaces for reading table data. Pick based on how you're working:

| Surface               | Reach for it when                                                                                                                                                                                                                                                | How                                            |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| **`table` MCP tool**  | You want a quick, ad-hoc answer from natural language on a **single** table, within the tool's limits (≤ 8 fields, ≤ 5 filters, ≤ 3 group-bys, ≤ 100 rows), plus rich schema/profile metadata.                                                                   | `table(tableId, mode: "schema" \| "query", …)` |
| **`clay tables` CLI** | The query is **complex** or exceeds the MCP tool's limits: **multi-table joins**, reading **more than 100 rows** (paging through a large result set), or richer `filter`/`select`/`order_by`/`group_by`/`field_mode` than natural language can express reliably. | `clay tables list \| query \| update`          |

Both read the same tables. The MCP tool turns natural language into a ClayQL query for you but is capped at a single table and 100 rows; the CLI takes a structured JSON query that supports **joins across multiple tables** and cursor pagination, so it's the right tool for complex queries or pulling large result sets. When in doubt for a quick single-table look, use MCP; for anything complex, joined, or larger than 100 rows, use the CLI.

## MCP tool: `table`

Both modes use the `table` MCP tool with a `mode` parameter.

### Schema mode

Get the schema and structure of a Clay table — field names, types, configurations, metadata.

```
table(tableId: "the-table-id", mode: "schema")
```

Returns XML with:

- Table metadata (name, row count, workspace)
- All fields with their types, configurations, and data profiles
- Source information if applicable
- Field group information (waterfalls, etc.)

### Query mode

Query a table using natural language. Generates and runs a SQL (ClayQL) query.

```
table(tableId: "the-table-id", mode: "query", taskDescription: "Show top 10 deals by ARR")
```

Capabilities:

- Filter, group, sort, count, sum, average any field
- Can only get up to 8 fields at a time, with 5 wheres, and 3 group_bys
- Returns up to 100 rows
- Single table only — no joins or CTEs

Examples:

- "How many contacts are in Boston?"
- "Show companies with more than 50 employees sorted by funding"
- "Average deal size by stage"
- "Count of rows where email is not null"

### Saving query results to CSV

After running the `table` tool (mode: query), save the results locally as a CSV file so the user can access them. Convert the JSON results array to CSV format and write it using the Write tool.

Example flow:

1. Run the `table` tool (mode: query) to get results
2. Extract column headers from the first result row
3. Convert each row to comma-separated values (quote fields containing commas)
4. Write to a local file like `./query-results.csv`

## CLI: `clay tables`

The `clay` CLI is Clay's programmatic surface: JSON to stdout, typed errors, and per-command `--help` that documents the exact output shape. It authenticates with a Clay API key (`CLAY_API_KEY`); the workspace is resolved from the key. If `clay` isn't found or `clay whoami` fails on auth, run the `setup` skill once.

`clay tables --help` (and `clay tables <cmd> --help`) is the authoritative spec — read it for exact flags, JSON shapes, and error codes.

### List tables

Discover tables and their ids. Each row carries an `apiEnabled` flag for whether the table is enabled for public-API / CLI query sync.

```bash
clay tables list                       # { data: [{ id, name, description, workbook, apiEnabled }], cursor? }
clay tables list --api-enabled         # only tables enabled for querying
clay tables list --limit 50 --cursor "$CURSOR"
```

### Enable query sync

A table must have **API query sync enabled** before `clay tables query` can read it. Toggle it with `update`:

```bash
clay tables update tbl_abc123 --query-sync true    # { id, querySyncEnabled: true }
clay tables update tbl_abc123 --query-sync false
```

Enabling sync on a table that wasn't synced kicks off an initial sync, so the table is **not queryable the instant `update` returns** — there's a delay while its rows sync (longer for larger tables). A `query` run too soon may return no/partial rows; retry after a short wait.

### Run a structured query

Unlike the MCP tool's natural language (single table, ≤ 100 rows), the CLI takes a **structured JSON query** that supports **joins across multiple tables** and cursor pagination — so it's the right choice for complex queries or reading past 100 rows. The query is read from a file or stdin via `--query`.

```bash
clay tables query --query ./query.json | jq '.data | length'
echo '{"tables":[{"id":"tbl_abc123"}]}' | clay tables query --query - --limit 100
clay tables query --query ./query.json --limit 100 --cursor "$CURSOR"
```

- The `--query` payload is the query itself (what to fetch); pagination is separate. Minimal shape: `{ "tables": [{ "id": "tbl_..." }] }`. Beyond `tables`, it may include `filter`, `select`, `join`, `order_by`, `group_by`, and `field_mode`. Field references can use ids or names. See `clay tables query --help` for the most up to date information
- Pagination is via flags: `--limit <n>` (1–100, default 50) and `--cursor <token>`. When more rows remain, the response includes a top-level `cursor` — pass it back via `--cursor` to fetch the next page.
- Output is `{ data: [ { "<fieldId>": <cell> } ], cursor?, fields? }`, where each `<cell>` carries a `status` (`success` / `error` / `running` / `queued` / `retry` / `rate_limited` / `awaiting_callback` / `empty`) plus its value.

Typical flow: `clay tables list --api-enabled` to find the id → (if needed) `clay tables update <id> --query-sync true` → `clay tables query`. To export, redirect or convert the JSON `data` array to CSV with the Write tool as above.

## Example: combine both surfaces to query across tables

A common pattern uses **both** surfaces together: the CLI to discover tables and run the query, the MCP `table` tool to learn each table's schema so you build the query with real field ids and types. For example, "join our Accounts and Contacts tables and pull the 500 contacts at companies with more than 100 employees":

**1. List tables via CLI to get their ids.**

```bash
clay tables list --api-enabled | jq -r '.data[] | "\(.id)\t\(.name)"'
# tbl_accounts123   Accounts
# tbl_contacts456   Contacts
```

**2. Get each table's schema via the MCP `table` tool.** Do this per table id so you know the exact field ids, types, and which field links the two (the join key). Schema mode also surfaces data profiles that help you write good filters.

```
table(tableId: "tbl_accounts123", mode: "schema")
table(tableId: "tbl_contacts456", mode: "schema")
```

Say the schemas show `Accounts` has `fld_employees` (number) and `fld_account_id`, and `Contacts` has `fld_company` that references the account.

**3. Build a structured query from those field ids and run it via CLI.** The join and >100-row read are why this goes through the CLI rather than the MCP tool. Enable query sync first if `apiEnabled` was `false` for either table — and note that a freshly enabled table takes some time to sync before it's queryable, so give it a moment (or retry) before the `query` returns full results.

```bash
clay tables update tbl_accounts123 --query-sync true
clay tables update tbl_contacts456 --query-sync true

# A freshly enabled table takes a moment to sync — give it time (or retry) before the query returns full results.
query='{
  "tables": [{ "id": "tbl_contacts456" }, { "id": "tbl_accounts123" }],
  "join": [{ "table": "tbl_accounts123", "on": { "left": "fld_company", "right": "fld_account_id" } }],
  "filter": { "field": "fld_employees", "op": ">", "value": 100 }
}'

echo "$query" | clay tables query --query - --limit 100 | jq '.data | length'
```

**4. Page past 100 rows** by following the returned `cursor` until it's gone:

```bash
cursor=""
while :; do
  page=$(echo "$query" | clay tables query --query - --limit 100 ${cursor:+--cursor "$cursor"})
  echo "$page" | jq -c '.data[]'
  cursor=$(echo "$page" | jq -r '.cursor // empty')
  [ -n "$cursor" ] || break
done
```

`clay tables query --help` lists the top-level query keys (`filter`, `select`, `join`, `order_by`, `group_by`, `field_mode`) and the pagination flags; the exact inner shape — `join`'s `table` / `on.left` / `on.right`, and a filter's `field` / `op` / `value` — comes from the schema and the developer docs below. Use the field ids you read from the MCP schema in step 2 rather than guessing.

Full developer documentation (CLI reference, Public API reference, concepts) lives at:
https://claydevelopers.mintlify.app/llms.txt

## Field Types in tables

1. **Basic fields**: Contain text, numbers, or boolean values
2. **Formula fields**: Single-line JavaScript expressions that auto-calculate (use Lodash as `_` and Moment.js)
3. **Action fields**: Run enrichments that fetch data, call APIs, or invoke AI. Each cell needs to be "run" and may cost credits
4. **AI fields**: Special action fields that run LLMs on data (OpenAI, Anthropic, Claygent for web research, Image Generation)
5. **Source fields**: Contain data imported from sources (Clay's company/people/jobs dataset, CSV, webhooks, Clay actions, signals)

## Key Concepts

### Sources

Sources add rows to tables. Types include:

- **Company / People / Jobs data**: Clay CPJ data
- **API Integration**: Clay actions that fetch data from external services
- **CSV Import**: Data imported from CSV files
- **Webhook**: Data received via webhook calls
- **Manual Entry**: Manually entered data
- **Event Monitor (Signals)**: Monitors for events like job changes, news, etc.

### Actions

Actions are enrichments that run on each row. They can:

- Fetch data from 100+ data providers (email, phone, firmographics, tech stack, funding)
- Call external APIs
- Run AI agents (Claygent can browse the web)
- Search Clay's database of 850m+ people and 60m+ companies

### Formulas

Formulas are single-line JavaScript expressions that:

- Use `_` for Lodash and `moment` for date handling
- Auto-calculate when referenced fields change
- Must use optional chaining (`?.`) for safe access
- Cannot use loops, if statements, spread syntax, or template literals

### Waterfalls

Waterfalls are groups of action fields that run in sequence:

- Each action runs only if previous ones failed
- Used to maximize data coverage (e.g., try multiple email providers)
- Have a merge field that combines results

## Rebuilding a Table as a Workflow

If a user wants to convert their table logic into a Clay workflow (e.g., to make it reusable, add branching, or run it on a schedule), use `/workflows` to build a workflow that replicates the table's enrichment pipeline as connected nodes.
