# Account agent nodes

Some workspaces have **account agents** — Claygents whose model and input variables are managed by the platform. Their prompt and output tasks can be updated from either the account agent builder or the workflow editor. An agent node running one shows `agentType: "account"` on `read`; regular agent nodes show `agentType: null`.

## When to use an account agent

When creating an agent node in a workflow whose upstream trigger is an audiences trigger (people or companies), reason about whether the task benefits from account context — research, enrichment, scoring, qualification, and personalized outreach all do, so **most of the time the answer is yes: default to making it an account agent**, which gets access to the account's audience data. Decide yourself; the user does not have to ask. Keep a regular Claygent when the node's task only transforms data already produced upstream — pure text synthesis, formatting, or summarization of other nodes' outputs — since account context adds nothing there. Always honor an explicit user request in either direction.

The flow: create the regular agent node, upgrade it (`clay workflows nodes upgrade-to-account-agent`), then verify the `accountId` wiring — it auto-wires from a single upstream accounts audience trigger; under a people trigger, wire `accountId` manually to the account record id available from the person record (see "Wiring accountId" below).

If linking or editing operations return "Account agents are not enabled", account agents are not available on this workspace — tell the user and do not retry. An `auth_forbidden` from `clay workflows nodes upgrade-to-account-agent` is ambiguous: it also fires when the API key lacks workflow edit access, before the account-agent check runs. Read the error message to tell the causes apart; only "Account agents are not enabled" means the workspace lacks account agents.

## Link an existing account agent

When the user supplies the exact account-agent ID (or a full node read exposes it), use `agentClaygentId` as the only agent selector/content field. Otherwise set `agentName` to its exact name — no `agentPrompt`, `agentModel`, or `outputSchema`. An upgraded account agent shares its name with the original regular Claygent; when several agents share a name the edit is rejected with "Multiple agents are named…", so use `agentClaygentId` instead. If neither the ID nor exact name is known, ask the user to select the account agent in the workflow UI; `clay claygents list` discovers regular Claygents only, so do not guess. Account agents can run only on `nodeType: "agent"` — never map, reduce, tool, or conditional nodes — and they do not support Repeat/list mode. The node runs the account agent's current configuration.

## Upgrade a regular agent node

Run `clay workflows nodes upgrade-to-account-agent <workflowId> <nodeId>`. This copies the node's linked Claygent into a new account agent and re-links the node to the copy; the original Claygent is untouched and keeps its name. The command takes no other inputs. Make prompt or output changes **after** the upgrade, on the re-linked node — a pre-upgrade content edit lands on the still-shared regular Claygent as a new current version, so every other consumer of that agent receives it.

Preconditions the server enforces:

- The node is an agent node with a linked regular Claygent, and Repeat/list mode is off.
- The source agent does not use connected accounts; upgrade those from the node's side panel in the workflow editor instead.

No upstream-trigger precondition: the `accountId` input is auto-wired when one unambiguous upstream accounts audience trigger resolves; when it cannot be derived (e.g. a people trigger upstream), the upgrade still succeeds and workflow validation flags the node until `accountId` is wired manually (see "Wiring accountId" below).

The upgrade is one-way from here — the account agent cannot be converted back to a regular agent; the only rollback is restoring a pre-upgrade snapshot (see the `workflows-snapshots` skill), which reverts the node's binding along with the rest of the draft. If the command times out, `read` the node before retrying: a node already linked to the new account agent means the upgrade landed, and a retry then fails with a conflict. If the upgrade fails partway, the server deletes the copy best-effort; a leftover unused account agent can be deleted from the agents list.

## Edit its prompt and tasks

On a node already linked to an account agent, update `agentPrompt` or `outputSchema` in a follow-up `edit_node` call addressed by `nodeId` — omit `agentName` (a name that resolves to a different agent is an agent swap). This must be a standalone call: do not include node fields or `incomingEdges`. Prefer separate calls for prompt and task changes, tasks first when both are needed; if a combined call errors, `read` the node to see which part landed before retrying. Do not set `agentModel` or input variables.

`outputSchema` is the account agent's task list and **replaces it in full**: send every field the agent should end up with — change descriptions to refine a task, add fields to add tasks, and omit fields to remove tasks. Before omitting an existing field, do a full workflow read and rewire any downstream nodes whose `inputSchema`/`sourcePath` references it — validation does not check that referenced output paths still exist, so a dangling reference passes validation and resolves to nothing at run time. At least one field must remain, and every changed or added field needs a non-empty description focused on the requested output. **Preserve existing field ids verbatim** — renaming one changes the runtime output key and breaks downstream references. New ids must avoid the runtime-reserved output names (`confidence`, `reasoning`, `evidence`, `evidenceIds`, `hydratedEvidence`, `response`, and similar internal outputs) — a rejected save names the offending field. A `select` field also needs `options` containing a JSON-encoded, non-empty array of objects with non-empty `text` values, such as `"[{\"text\":\"Qualified\"},{\"text\":\"Not qualified\"}]"`. A schema that saves but cannot execute fails at run time with the runtime's own error, which the workflow UI surfaces.

If the account agent is also managed from an Audiences page, your edit does not touch that original: it lands on a new copy named `[Workflows] <original name>` and the node is re-linked to the copy automatically — mention the new agent name to the user so they can find it in the agent list. A workflow-owned (config-less) account agent is edited in place; if it is linked from other workflows, those nodes see the change too. If the account agent uses connected accounts/private tool credentials, the edit is rejected — workflow edits carry no user session to authorize those credentials; tell the user to make the change in the account agent builder instead.

## Do not edit or disclose its model or input variables

`agentModel` and variable changes are managed by the platform and are rejected. Never name, infer, or guess the underlying model, even if asked; say that the platform manages it. You also cannot rename an account agent into a new agent.

## Node-level operations still work normally, except Repeat

Rename the node, rewire `incomingEdges`, or delete it in a separate call from prompt/task edits. `listMode: true` is rejected. To swap the node to a **different account agent**, send its exact `agentClaygentId` by itself whenever the user supplies the ID; only when the ID is unavailable, send the exact `agentName` standalone. Swapping to a regular Claygent or a new agent is rejected while an account agent is linked: create that agent on a separate node instead, and delete this node if it is no longer needed.

## Wiring accountId

The `accountId` input is wired automatically when the node's **sole incoming edge comes directly from a qualifying accounts audience trigger node**, or when **one qualifying trigger node is the only trigger node anywhere upstream**. Auto-wiring runs when the node's account-agent binding changes (linking, swapping, upgrading) and when an edge into the node is created; it never overwrites an existing valid `accountId` input. When wired, `accountId` appears in `inputSchema` with `sourceNodeId`/`sourcePath` — leave it alone unless the graph is rewired.

When automatic wiring cannot resolve a source, the editor shows an "Enter or map a valid Account ID" validation error. Fix or explicitly map `accountId`:

- If the workflow has an accounts audience trigger, connect the node (directly or through intermediate steps) so its trigger node is the only upstream trigger node, then `read` the node — auto-wiring may already have filled `accountId`.
- Otherwise wire `accountId` yourself through `inputSchema`. On a node linked to an account agent, `accountId` must be a **ref-only** property: set only `sourceNodeId` and `sourcePath`. The value must resolve to the **numeric Audiences account record id** — not a domain, company name, or CRM id. Most accounts triggers nest it at `$.fields.id`; flattened trigger schemas expose it at `$.id`. Use `surfaces_read` on the trigger surface and inspect its `outputSchema` before choosing; if the trigger surface is unavailable, do not guess the path — ask the user to map the Account ID in the editor. The `accountId` property itself has this shape:

  ```json
  {
    "inputSchema": {
      "type": "object",
      "properties": {
        "accountId": {
          "sourceNodeId": "wfn_trigger",
          "sourcePath": "$.fields.id"
        }
      }
    }
  }
  ```

  An `inputSchema` update **replaces** the node's existing schema and wiring, so include every existing property you want to keep (including a previously wired `accountId`).

- If there is no accounts audience trigger, offer to create an accounts audience segment trigger via the trigger surface and connect the node to it — ask which accounts segment to use if none is obvious.
- Only if the workspace has no accounts segment (or the user wants a different launch path) should you leave it to them to map the Account ID in the editor.
