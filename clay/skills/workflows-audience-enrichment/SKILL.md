---
name: workflows-audience-enrichment
description: Clay workflows — build enrichment steps and map their results back to Audiences in an existing audience enrichment workflow. Use only while editing a workflow whose `clay workflows get` output has type `audience_enrichment`.
allowed-tools: Bash(clay *), Bash(jq *), Read
---

# Build an audience enrichment workflow

Use this skill only for an existing workflow whose type is `audience_enrichment`. It owns the
workflow-specific sequence: build enrichment steps, ensure the shared final Audiences writeback,
and map enrichment results onto audience fields.

Read the complete `workflows` and `audiences` skills first. Read `/workflows-discover-actions` when
choosing provider actions, and read the `workflows` skill's `audiences.md` before mapping the
writeback.

## Verify the workflow type

Start every task with:

```bash
clay workflows get <workflowId>
```

Continue only when `.type` is exactly `audience_enrichment`. If the type is null, absent,
`account_agents`, or anything else, stop using this skill and return to the general `workflows`
skill. Never convert or reclassify a workflow implicitly.

## Plan the enrichment

Read the full graph and identify the audience trigger, existing enrichment steps, and current
writeback node. Confirm with the user:

- which audience fields should be populated
- whether the workflow should enrich people or companies
- whether the requested fields are actually missing or sparse
- the action or function to use when the workspace catalog offers consequential alternatives
- the audience size before testing or publishing

Use the `audiences` skill to inspect field fill rates and count matching records. Prefer direct
enrichment actions for provider data, Clay functions for reusable workspace logic, agents for
unstructured research or classification, conditionals for eligibility and fallbacks, and code for
deterministic transformations.

Present a short plan and get approval before editing the graph. Get separate approval before
publishing. Testing must be within the authorized scope; follow the shared policy in
`workflows-discover-actions/cost-and-budget.md` for cost disclosure and significant-spend confirmation.

## Build the enrichment path

Build from the existing audience trigger. Preserve the trigger and any existing
`upsert-audiences-record` node.

Use `clay workflows actions list` and `clay workflows actions schema` to choose and configure each
enrichment. Never guess action input names, output paths, credentials, or provider availability.
Put cheap eligibility checks before paid actions. When an enrichment can miss, use the user's
chosen fallback or conditional path rather than silently writing a blank value.

Use the general `workflows` skill for node creation, insertion, data passing, and branch wiring.
Do not manually create or reconnect the final audience writeback while building intermediate
steps.

## Ensure and configure the final writeback

After the enrichment graph is structurally complete, run:

```bash
clay workflows ensure-audience-writeback <workflowId>
```

This command calls the same server-side helper as the audience enrichment editor. It creates or
reuses exactly one `upsert-audiences-record` node, validates its entity type, and reconnects every
eligible terminal route. Do not reproduce that topology change with manual node or edge edits.

Read the returned node before updating it. Preserve its tool identity and static `entityType`, then
configure its `inputMappingConfig` with `clay workflows nodes update` using the writable shape from
`clay workflows nodes get`.

Discover destination fields with:

```bash
clay audiences fields list --entity-type people
clay audiences fields list --entity-type companies
```

Follow the `workflows` skill's `audiences.md` for the complete mapping shape. In particular:

- set `lookupFields|selectedLookupFields` to the static array `["id"]`
- bind `lookupFields|id` to the audience trigger record id: use `$.fields.id` when the trigger
  output schema contains a `fields` object, otherwise use `$.id`; inspect the trigger output schema
  and never guess the path
- do not replace the record-id lookup with email, LinkedIn URL, phone, or domain; those aliases are
  for generic or net-new audience upserts where an existing audience record id is unavailable
- include every destination id in `recordFields|selectedRecordFields` and provide its matching
  `recordFields|<id>` binding
- set `recordFields|removeNullValues` to `true` unless the user explicitly wants blanks to clear
  existing values
- bind enrichment outputs from their declared `$.result.<outputPath>` paths; never invent paths

Read the writeback node again after updating it and confirm the mappings persisted.

## Validate, test, and publish

Validate the graph and show the resulting diagram. Test a small audience sample first, inspect both
the enrichment output and the final Audiences update, and correct mappings before increasing the
limit. Publish only after the user approves the tested draft. Later edits remain draft-only until
the workflow is published again.
