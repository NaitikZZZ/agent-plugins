# Rebuild a table's provider waterfall

Inspect the full column settings and field groups with
`clay tables columns get <tableId>`. Follow the provider dependencies, output paths,
validation steps, and stop conditions. A separate formula that chooses among existing
values is not the provider waterfall; preserve both when the table contains both.

Preserve each provider's connected account as well as its action and inputs. The
table field calls this `authAccountId`; workflow tools use `appAccountId`. Follow
`/workflows-discover-actions` to bind that account on the tool, then read back the
persisted tool's `appAccountId`. Putting `authAccountId` in a node's configuration
does not bind its tool account. Do not describe a dropped or unsupported binding
as preserved.

Before expanding providers into nodes, search for the waterfall capability using
`clay workflows actions search "work email waterfall" --limit 10` (substitute the
actual capability). Inspect returned functions and their schemas with
`clay functions get <functionId>`. Follow `/workflows-discover-actions` when
search leaves the function unresolved.

Reuse an installed function only when its configuration preserves the source's
provider order, validation, accepted results, and outputs. A matching name or email
output schema alone does not establish equivalence. Preserve any supported function
settings that affect those semantics. If the available inspection cannot establish
equivalence, say so; do not silently replace a custom waterfall with a generic one.

For an equivalent function, bind the table's input formulas to upstream workflow
outputs, put the original run condition before the function, and expose the selected
email and provider from its outputs. Do not rebuild validation already encapsulated
by the function. If none is available, preserve the explicit provider chain and its
fall-through conditions, and report any unsupported behavior.

Keep the skip path connected to the output: when an existing email suppresses the
waterfall, preserve any independent formula selecting that existing email. Empty
optional inputs must agree with the declared output schemas; do not emit null into
a string-only output. When reusing a managed function, verify its saved reference,
input mappings, run condition, and output mappings. Report each run's actual result and any provider failure;
an attempted run does not demonstrate successful enrichment.
