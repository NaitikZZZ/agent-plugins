# Data Passing in Clay Workflows

How you wire data between nodes depends on the node type. There are two
mechanisms; the shapes below are exactly what `edit_node` accepts and what `read`
returns — wire data this way, then `read` the node back to confirm it saved.

## Method 1: Pinned inputs on agent nodes (typed, deterministic)

Use this when the data must be exact (a number, a boolean, a specific structured
field), or comes from another node.

The **upstream node** declares an `outputSchema` describing its structured output:

```json
{
  "outputSchema": {
    "type": "object",
    "properties": {
      "company_name": { "type": "string" },
      "industry": { "type": "string" },
      "score": { "type": "number" }
    }
  }
}
```

The **downstream agent node** pins each input by adding `sourceNodeId` +
`sourcePath` **directly onto the `inputSchema` property**:

```json
{
  "inputSchema": {
    "type": "object",
    "properties": {
      "company_name": {
        "type": "string",
        "sourceNodeId": "wfn_upstream",
        "sourcePath": "$.company_name"
      },
      "score": {
        "type": "number",
        "sourceNodeId": "wfn_upstream",
        "sourcePath": "$.score"
      }
    }
  }
}
```

The reference lives **inline on the property** (`sourceNodeId` + `sourcePath`).
Use `sourcePath`, not `path`.

`inputSchema`/`outputSchema` also accept a **shorthand** that drops the
`type: "object"` + `properties` wrapper — `{ "score": { "type": "number" } }` is
equivalent to the full form above. Either works; the shorthand is terser.

**Accessing pinned inputs:** in an agent prompt, `{{company_name}}` resolves to
the pinned value.

**`sourcePath` syntax** is JSONPath: `$.field`, `$.nested.field`,
`$.array[0].name`, `$.results[0].properties.hs_email_domain`.

## Method 2: Action input mapping on tool nodes

Tool nodes (`nodeType: "tool"`) do **not** wire action inputs through
`inputSchema`. Each action parameter is mapped in the tool's `inputMappingConfig`:

```json
{
  "tools": [
    {
      "actionKey": "hubspot-lookup-object",
      "actionPackageId": "a2584689-...",
      "toolType": "clay_action",
      "inputMappingConfig": {
        "objectTypeId": { "type": "static", "value": "0-2" },
        "fields|domain": { "type": "reference", "expression": "{{domain}}" },
        "fields|fieldsToFilterBy": { "type": "static", "value": ["domain"] }
      }
    }
  ]
}
```

Each value is one of:

| `type`      | shape                                              | meaning                                                                       |
| ----------- | -------------------------------------------------- | ----------------------------------------------------------------------------- |
| `static`    | `{ "type": "static", "value": … }`                 | fixed value baked into the node                                               |
| `reference` | `{ "type": "reference", "expression": "{{var}}" }` | pull from an available variable (upstream output / trigger input)             |
| `item`      | `{ "type": "item", "path": "$.field" }`            | the current list item, in list mode (`$` = whole item, `$.field` = one field) |
| `skip`      | `{ "type": "skip" }`                               | leave the parameter unset                                                     |

**Pipe keys (`parent|sub`):** grouped/nested action parameters are addressed
with a pipe. A `fields` group with `domain` and `fieldsToFilterBy` sub-fields is
mapped as `fields|domain` and `fields|fieldsToFilterBy`.

**`inputMappingConfig` lives on the tool, not the node.** Setting it updates the
tool and re-syncs every node bound to that tool — which is why `edit_node` gives
each node its own tool instance: it keeps a tool only when the node already has
it, and otherwise creates a new one (same action, same credentials) even when you
pass a `toolId` or an `actionKey` that already has a workspace tool. Mappings you
set therefore stay local to the node. Workflows built before this may still share
a tool across nodes; if a mapping change turns up on another node, re-add the
action to that node so it gets a fresh instance.

**Gotcha — don't invent inputSchema variables on tool nodes.** A property added to
a tool node's `inputSchema` that isn't a real action parameter is **silently
dropped on save**, so any `{{var}}` referencing it resolves to nothing. Put the
`reference` directly in `inputMappingConfig` instead (e.g.
`"fields|domain": { "type": "reference", "expression": "{{domain}}" }`), then
`read` the node back to confirm it persisted.

**Wiring a specific upstream output into a parameter.** When the value isn't
already an input the node receives — it's a precise field of an upstream output,
or comes from a node 2+ hops back — give the tool node that input the same way an
agent node pins one (`sourceNodeId` + `sourcePath`) and reference it by name in
`inputMappingConfig`:

```json
{
  "inputSchema": {
    "type": "object",
    "properties": {
      "owner_name": {
        "type": "string",
        "sourceNodeId": "wfn_enrich",
        "sourcePath": "$.result.name"
      }
    }
  },
  "tools": [
    {
      "toolType": "clay_action",
      "actionKey": "hubspot-create-object",
      "actionPackageId": "a2584689-...",
      "inputMappingConfig": {
        "fields|name": { "type": "reference", "expression": "{{owner_name}}" }
      }
    }
  ]
}
```

The input is normalized to the action's own parameters on save, but the binding
is preserved as long as `inputMappingConfig` references it — so the `{{owner_name}}`
reference resolves. `read` the node back and confirm both the input ref and the
mapping persisted.

### Output structure of enrich (tool) nodes

An enrich (tool) node's outputs are flat: the Clay action's returned fields are under `result`, and
its success flag is `success` — both at the top level. When writing `inputRefs` or `sourcePath`
expressions that point at an enrich (tool) node, address the action's fields under `$.result.*`:

```json
{ "sourceNodeId": "wfn_enrich_company", "sourcePath": "$.result.name" }
```

Everything the Clay action returned is inside `$.result.*`; `$.success` is the action's success flag.

To discover the exact field names, in order of preference:

1. Read `outputParameters` from `clay workflows actions schema <packageId> <actionKey>` — the
   action's declared output fields, available before the node has ever run. Each entry's
   `outputPath` is the field, so the path is `$.result.<outputPath>`.
2. Check the `recentOutputPaths` field on the node (populated from the most recent run), or
3. Run the action once with `execute_clay_action` and look at the returned fields — those keys
   will be available as `$.result.<field>`. Needed when the action declares no output schema,
   so `outputParameters` comes back empty.

**Example:** if `execute_clay_action` returns `{ "name": "Acme", "domain": "acme.com" }`, the
correct paths are `$.result.name` and `$.result.domain`.

## Discovering an action's dynamic fields

Some actions only reveal their real parameters once an earlier input is chosen —
a CRM "create object" exposes a different field set per object type; a dependent
dropdown's options depend on a parent selection. These are **not** in the static
action schema (`clay workflows actions schema`). Resolve them with the CLI — it
hits the live integration, so pass the connected account:

```bash
# 1. resolve a dependent dropdown's values (the "driver")
clay workflows actions dynamic-fields pkg_abc123 hubspot-create-object objectTypeId --type select --account acct_abc123
#   → [{ "value": "2-36617481", "displayName": "Pet" }, ...]

# 2. with the driver chosen, resolve the fields it reveals
clay workflows actions dynamic-fields pkg_abc123 hubspot-create-object fields --type input --account acct_abc123 --inputs '{"objectTypeId":"2-36617481"}'
#   → field objects; each "name" is already pipe-namespaced: "fields|name", "fields|age", ...
```

- `--type select` resolves a dependent dropdown's values; `--type input` resolves
  the revealed field set. The `value`s and `name`s returned are exactly what go in
  `inputMappingConfig` (`objectTypeId` as a `static` value, `fields|<sub>` keys).
- It's iterative: fill one input, then re-run with it in `--inputs` to resolve the
  next dependent parameter.
- Preconditions: the driver must be a concrete value in `--inputs` (a
  `{{reference}}` won't resolve at design time), and `--account` is required for
  actions that authenticate. Get `<packageId>`/`<actionKey>` and the connected
  account from `clay workflows actions list`.

## Choosing a method

| Scenario                                             | Method                                                                |
| ---------------------------------------------------- | --------------------------------------------------------------------- |
| Numeric scores, IDs, booleans into an **agent** node | Pinned inputs (`sourceNodeId`/`sourcePath`)                           |
| Data from 2+ hops back into an **agent** node        | Pinned inputs                                                         |
| Any input into a **tool** node                       | `inputMappingConfig` (`static` / `reference`)                         |
| An input into a **repeating (list mode) tool** node  | `inputMappingConfig` `item` (`{ "type": "item", "path": "$.field" }`) |
