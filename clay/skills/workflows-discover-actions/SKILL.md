---
name: workflows-discover-actions
description: Clay workflows — discover available actions for workflow nodes (email lookup, company enrichment, phone finders, etc.) and inspect their input and output schemas. Use while building a workflow.
allowed-tools: Bash(clay *), Bash(grep *), Bash(cat *), Bash(wc *), Bash(jq *), Read, Grep
---

# Discover enrichments with search

Use this skill before choosing enrichments, connector actions, or reusable functions
for a workflow. Start with ranked search, inspect actual schemas, and use `catalog.md`
for unresolved requirements, connection discovery, or unavailable search.

If `clay workflows actions search` is unavailable or returns a workspace-enablement
error, use `catalog.md` instead. A failed search is not evidence that no matching
enrichment exists. If the CLI is not installed or authenticated, follow the `cli`
skill before attempting discovery.

For pricing and spending decisions, read `cost-and-budget.md`.

Choose the plan yourself from search results; do not call `actions recommend` in
this path.

Search returns individual actions and reusable functions. Functions may encapsulate
multiple steps, including installed waterfalls. Compare both against the requested
inputs and outputs; a suitable function can satisfy a capability without composing
several actions.

Prefer suitable Clay waterfalls over individual providers.

1. Identify the inputs available at the insertion point from the conversation and
   existing workflow inspection. For an existing workflow, use
   `clay workflows graph get <workflowId> --mode full` and inspect individual nodes
   or triggers as needed. Use only upstream outputs; fields on other branches or
   downstream nodes are not automatically available. For a blank workflow, use
   the inputs stated by the user. Unknown output shapes require inspection or
   deferred mapping; do not invent field paths.
2. Search for each distinct capability with
   `clay workflows actions search "<capability>" --limit 10`. Each call searches one query.
   Keep unrelated steps in separate searches
   so a combined shortlist does not crowd out one part of the request.
3. Save search responses to a local JSON file so large schemas do not hide later
   candidates. Use a distinct `enrichment-search-<capability>-<attempt>.json` filename
   for every search, retaining earlier files for composition and ID verification.
   Use only lowercase letters, digits, and hyphens in the capability and attempt names.
   Scan a compact view of every candidate before choosing or searching
   again:

   ```bash
   clay workflows actions search "<capability>" --limit 10 > enrichment-search-work-email-1.json
   jq '.candidates[] | {type, candidateId, name: (.displayName // .name), packageId, actionKey, functionId, description, score, creditCost, requiresApiKey, appAccountType, requiredInputNames, requiredInputCombinations, inputs: [.inputParameters[]? | {name, type: (.type // .typeSettings.type), optional}], functionInputs: ((.inputSchema.properties // {}) | keys), functionOutputs: ((.outputSchema.properties // {}) | keys), outputs: [.outputParameters[]? | {outputPath, semanticType}]}' enrichment-search-work-email-1.json
   ```

   The jq command is an optional compact-view convenience. If shell filtering
   requires approval, use the read-only file tool to inspect the saved response
   in bounded sections instead; do not require approval just to inspect results.
   Inspect complete schemas only for promising candidates, reusing the saved file
   or the type-specific inspection commands below rather than printing every candidate's full schema.

   Compare the output fields against each part of the request. Reuse the saved
   response for detailed inspection instead of repeating the same query.
   Inspect candidate inputs, outputs, credentials and limits. Prefer a plan that
   covers the request using available inputs, not merely the highest-ranked result.
   Search order is the default preference among candidates with comparable fit.
   Use this order as a relevance signal, not proof of provider accuracy.
   Choose a lower-ranked candidate for a concrete advantage in required outputs,
   input compatibility, evidence, freshness metadata, or coverage, and explain it.
   Match output semantics to the request: a title field alone does not establish
   current employment, and a location field must refer to the requested entity.
   For actions, use `clay workflows actions schema <packageId> <actionKey>` for more detail.
   For functions, inspect the saved candidate’s `inputSchema` and `outputSchema`;
   use `clay functions get <functionId>` before rejecting a promising function or
   adding steps when its outputs or validation behavior are unclear. If inspection
   establishes the requested validation, use the function's result without another
   validator for the same check. Add validation only for a missing requested guarantee,
   stale results, or an explicit independent check.
   Read input headers and alternatives before treating a field as required.
   When `requiredInputCombinations` is present and nonempty, satisfy every input in
   any one combination; the combinations override individual input optional flags.

4. If the candidates leave a gap, change the search rather than repeating the same
   constraints in slightly different words. Try the missing capability; if that
   returns the same options, broaden to the parent capability or entity enrichment.
   When broadening, remove the narrow constraints from the query instead of
   appending them to a broader phrase. Search for the category of information or
   the entity itself, then inspect the returned schemas for the missing field.
   A general enrichment can contain the needed field even when a specialized action
   does not. Keep the user's requirements when checking the broader results.
5. Consider whether results already found can work together. A list or history can
   be filtered or reduced with native workflow logic. An identifier or URL can feed
   a detail action when its schema supports that input. Check limits and missing
   matches; do not claim complete coverage when the available actions are capped.
   Native processing can transform already retrieved data; it cannot bypass a
   retrieval limit or fetch unseen rows. Do not replace a missing capability with
   an unspecified native join, pagination loop or other unverified operation.
   Name the supported retrieval step and retain its limitations.
6. Select one or more grounded results and pass them to the existing workflow
   builder. Copy each `candidateId`, `packageId`, `actionKey` or `functionId`
   verbatim from the tool response; never reconstruct an identifier from memory.
   Immediately before handing off, extract the selected identifiers from the saved
   JSON with jq, or read the selected entries with the read-only file tool. `candidateId` identifies a search result,
   not a builder payload. For search and catalog selections, pass the extracted
   `actionKey` and `packageId` as the builder’s `actionKey` and `actionPackageId`
   for `toolType: "clay_action"`; pass `functionId` as `tableId` for
   `toolType: "clay_function"`.
   Check every handed-off identifier against this extracted list; a plausible-looking
   identifier is not sufficient.
   Explain the fit and any remaining gap. The user's multi-part request already
   permits a multi-step plan; ask only for genuinely missing facts or consequential
   choices that prevent proceeding.

Stop when the plan covers the request or changed searches stop adding useful
options. Do not exhaustively inspect every result or repeat searches just to fill a
shortlist. Before declaring a capability unavailable, try a broader search as well
as the specific one. A search error is a technical failure, not evidence that no
matching enrichment exists; report it separately from any catalog recovery.

If a specific and a broader search still leave a requirement unsupported, use
`clay workflows actions list` to look for a complementary action, unless the session
explicitly restricts discovery to search only. Save and filter the catalog locally. Include output field names and paths in
the filter, not just action names or descriptions: a generically named enrichment
may already expose the missing facts. Inspect the matched fields and credit costs,
then verify promising candidates with the type-specific inspection commands above. Use this recovery for a
concrete gap. Subsequent searches should resolve missing capabilities, ambiguous
output semantics, or coverage limitations. Do not make an extra search or catalog
pass solely to find a cheaper or simpler plan. Listed credits may be reported,
but should not override stronger fit or drive exploration. When the ranked results
support the requirements and no material ambiguity remains, stop. Explain any
requirement that remains unsupported.

Check requiresApiKey before requiring a provider connection (for catalog selections,
read actionLabels.requiresApiKey on the selected action). When a connection is required,
or the user requests their own credentials, use the action's appAccountType with
`clay app-accounts list --filter type=<appAccountType>`.
Reuse the returned accounts for other selected actions with the same connection type.
If multiple accounts match and the user's intent or existing workflow does not identify
which to use, ask. For the workspace's own credentials, exclude isClayManaged accounts.
Pass the chosen account's id explicitly as appAccountId, even when passing a toolId.
If no accessible accounts are returned, explain that a connection or access is needed.
Do not fetch the full catalog for credential checks.

Unknown schemas do not prove
an action cannot do the work: distinguish a promising candidate from verified field
mappings. For table lookups and research actions, an empty declared output schema means
the builder must resolve dynamic outputs before mapping; it does not make the
action unavailable. Clay's table-lookup actions are valid built-in operations,
not unnecessary external enrichments. When one supports the requested cross-table
read, select it and defer only its dynamic field mapping; do not substitute an
unspecified native join.
Do not execute actions merely to rank them or invent output paths.

Use the existing workflow-building instructions for node construction and data mapping. Resolve dynamic
fields when needed, preserve workflow capability and credential checks, and keep
uncertain results distinct from confirmed outputs. Search discovers candidates;
the builder remains responsible for creating and validating the workflow.

When the remaining gap is evidence rather than a missing field, search for a
research or source-reading action that can perform the verification. Do not stop
at an unverified numeric field plus an unspecified “verify later” step. Select
a supported verification capability, require appropriate source evidence, and
keep unverifiable results unknown. This does not guarantee universal coverage.
Do not add research to ordinary lookups that do not have this evidence gap.
