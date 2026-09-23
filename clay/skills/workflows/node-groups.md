# Canvas node groups

Groups are named frames around two or more connected nodes. They do not change
edges or node configuration. The workspace must have canvas node groups
enabled; otherwise create and delete return `auth_forbidden`.

Group ids are listed on `clay workflows graph get` under `summary.nodeGroups`
when any exist.

- Create: `clay workflows groups create <workflowId> --node-ids <id,id,...> [--name <name>]`
  — at least two ids. Triggers and nodes already in a group are rejected.
  External edges may only touch the group's entry or exit members. Sibling
  branches that share a parent may be grouped even without an edge between
  them.
- Add nodes: `clay workflows groups add-nodes <workflowId> <nodeGroupId> --node-ids <id,id,...>`
  — the resulting group is validated against the same rules as create; an
  invalid result rejects the whole change.
- Remove nodes: `clay workflows groups remove-nodes <workflowId> <nodeGroupId> --node-ids <id,id,...>`
  — removed nodes stay on the graph. The group must keep at least two nodes
  and stay valid (removing a middle node can be rejected because it would
  leave an outside node both upstream and downstream); to disband it, use
  delete instead.
- Delete: `clay workflows groups delete <workflowId> <nodeGroupId>` — ungroups
  only; member nodes stay on the graph.
- Convert to function:
  `clay workflows groups publish-as-function <workflowId> <nodeGroupId> [--name <name>]`
  — copies the group into a new published function (a standalone workflow that
  other workflows call) and replaces the group with a function call node wired
  to the same inputs and outputs. Blocked while any member has a validation
  error (`clay workflows graph validate`). Gated on the workspace's functions
  flag (separate from node groups), so it can return `auth_forbidden` even
  where create and delete work.
