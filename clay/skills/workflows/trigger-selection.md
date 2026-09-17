# Choosing a workflow trigger

When the request and prior context identify the trigger, proceed with the requested
work. If the user asked for a draft, create it without asking them to confirm that
clear choice again.

Choose what starts a run before binding a source. Signals, segments, tables, and other
sources can share names or keywords. Neither a matching object name nor a recognized
signal type is enough to choose a trigger. "Make a workflow with new hires" could refer
to a signal, a segment, or another source established in the conversation.

First use the request, prior discussion, and any explicitly referenced object to infer
the intended source, population, event, and cadence. Inspect plausible resources with
the relevant skill and compare their type, scope, and configuration when needed. Do
not enumerate unrelated objects when context already identifies the source. Processing
segment members, reacting to signal events, accepting incoming data, and running on a
schedule are different intents; none has priority based on keywords alone. A segment
can also be the population a signal watches, without being the workflow's trigger.

If the request and available context leave multiple plausible triggers, ask one concrete
question before creating or binding the trigger. For example: "Should this run when a
new-hire signal fires, or when someone enters the New hires segment?" Continue work
that does not depend on the answer. Ask only about the unresolved distinction; do not
ask again when context already makes the choice clear. Present the plausible sources
as a choice and wait for the answer; selecting one and asking "Shall I proceed?" does
not resolve which source the user intended.

| Ambiguous request                          | Distinction to resolve                                                                                                                                  |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Make a workflow with new hires"           | New-hire signal events versus members of a similarly named segment.                                                                                     |
| "Reach out when accounts are hiring"       | `NewHire` means someone joined; `JobPost` means an open role was posted.                                                                                |
| "Follow up with people in new roles"       | `JobChange` means a tracked person changed employers; `Promotion` means advancement at the same company; `NewHire` watches hiring at tracked companies. |
| "Automate funded companies"                | A `News` funding event versus membership in a segment defined by funding data.                                                                          |
| "Follow up on intent"                      | Person versus company topic intent, website visits, or membership in a high-intent segment. Check supported types and surfaces in the signals skill.    |
| "Process new leads"                        | New segment members, newly discovered prospects, or incoming webhook/CSV records. Resolve the source from context.                                      |
| "Run weekly for new hires"                 | A scheduled pass over matching records versus a run for each arriving signal event. Monitoring cadence alone does not specify workflow cadence.         |
| "Work through this list and keep watching" | Processing existing records and responding to future events are separate requirements; establish both scopes.                                           |

After selecting a trigger, read `clay workflows triggers create --help` for its supported
configuration and use the relevant source skill. Do not substitute a different source
because the selected one is unavailable or needs setup; explain the limitation.

For an audience signal trigger, bind
`audience_signal` to the underlying `signal.id` (`sig_…`), not the signal management
entry ID, with the matching `entityType` (`CONTACT` or `ACCOUNT`). Use one trigger per
signal. If several signals match, compare their monitored scope and configuration;
ask which one when the context does not distinguish them. If no fitting signal exists,
follow the signals skill's creation and availability guidance instead of substituting
a similarly named segment.

A segment filtered by recent signal events is useful when membership in that rolling
window is the intended trigger. It is not interchangeable with reacting to each signal
event. Do not substitute one for the other just because they contain similar records.
