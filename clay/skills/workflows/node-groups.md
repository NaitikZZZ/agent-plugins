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
- Delete: `clay workflows groups delete <workflowId> <nodeGroupId>` — ungroups
  only; member nodes stay on the graph.
