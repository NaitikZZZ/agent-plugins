# Canvas node groups

Groups are named frames around two or more nodes. Members do not need to be
connected. Groups do not change edges or node configuration. The workspace must
have canvas node groups enabled; otherwise create, add-nodes, remove-nodes, and
delete return `auth_forbidden`. This file is withheld from the session when the
flag is off — do not invent groups or mention them if you cannot read this file.

Group ids are listed on `clay workflows graph get` under `summary.nodeGroups`
when any exist.

## When to group

Count every canvas node, including the trigger. Eight to ten ungrouped nodes is
the point where the graph becomes hard to scan.

- **Building a new graph of more than 8–10 nodes:** group as you go. After each
  logical stage has two or more members, create a named group for that stage.
  Do not wait until the whole graph is finished, and do not ask permission to
  group work you are already authorized to build.
- **An existing workflow already has more than 8–10 ungrouped nodes:** propose
  named groups that match the current stages, then wait for the user to accept
  before creating them. Skip the suggestion when the graph is already grouped
  in a way that matches those stages, or when the user asked you not to
  reorganize the canvas.
- **Fewer than about eight nodes:** leave the canvas ungrouped unless the user
  asks for groups.

Name each group after the job that stage does, for example "Find and enrich",
"Score and route", or "Write to CRM". Prefer a few stage-sized groups over one
group around the whole workflow or many two-node frames. Group by that job even
when the members are not a single chain (sibling branches, or parallel steps
that do the same work). Do not put unrelated subgraphs in one group just
because create would accept them.

Triggers cannot be members. If a proposed group would include the trigger, drop
the trigger and group the first executable stage instead. If a selection would
break the create rules below, shrink it to a valid subset rather than forcing
the group.

## Create rules

A selection is valid when it has at least two nodes, none is a trigger, none
already belongs to another group, and no path leaves the group and comes back
(an outside node cannot be both upstream and downstream of the selection).
External edges may attach to any member. Members do not need to form one
component.

Create, add-nodes, and remove-nodes all apply these rules to the resulting
membership. An invalid result rejects the whole change, except that
remove-nodes deletes the group when fewer than two members would remain.

## Commands

- Create: `clay workflows groups create <workflowId> --node-ids <id,id,...> [--name <name>]`
  — at least two ids. Omit `--name` to generate a name from the members; `--name` keeps that name.
- Add nodes: `clay workflows groups add-nodes <workflowId> <nodeGroupId> --node-ids <id,id,...>`
- Remove nodes: `clay workflows groups remove-nodes <workflowId> <nodeGroupId> --node-ids <id,id,...>`
  — removed nodes stay on the graph. If fewer than two members would remain,
  the group is deleted (`nodes` is empty). The remaining membership must still
  be valid (removing a node can be rejected when it would leave an outside
  node both upstream and downstream).
- Delete: `clay workflows groups delete <workflowId> <nodeGroupId>` — ungroups
  only; member nodes stay on the graph.
- Convert to function:
  `clay workflows groups publish-as-function <workflowId> <nodeGroupId> [--name <name>] [--description <description>]`
  — copies the group into a new published function (a standalone workflow that
  other workflows call) and replaces the group with a function call node wired
  to the same inputs and outputs. External edges on any member are rewired onto
  that call node. Stricter than create: the members must be one connected
  component (sibling branches that share a parent count). Blocked while any
  member has a validation error (`clay workflows graph validate`). Gated on the
  workspace's functions flag (separate from node groups), so it can return
  `auth_forbidden` even where create and delete work.
