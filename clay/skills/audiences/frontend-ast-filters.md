# Frontend AST filter support for saved segments

Use this reference when creating, updating, or cloning a saved People/Companies
segment with an AST filter (`ConditionalExpressionGroup`). This covers the AST
segment editor, not DSL query syntax or DSL-based segment filters.

Search accepts more AST shapes than the segment editor. Availability
also depends on workspace fields, sources, and configured signals. Use only the
forms supported for the selected field; do not infer support from a successful
search or count. See [Saved segment restrictions](filters.md#saved-segment-restrictions)
for how to handle criteria that cannot be represented.

## Supported shapes

Support depends on the workspace's available filter fields and their offered
operators, not just the AST node type. A field existing in the database does not
automatically make it filterable in the UI.

| Shape                              | Supported use                                                                                                                                                                                                                                                                                              |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GroupOp`                          | `And` / `Or` groups whose children are all supported.                                                                                                                                                                                                                                                      |
| Field `BinOp`                      | Available People, Company, and Deal fields with their UI operators: text comparisons, numeric comparisons, booleans, enum selections, presence checks, and date comparisons as appropriate to the field. Deal predicates belong under a People/Companies segment, not a Deals root.                        |
| `ContainAny` (“contains any of”)   | Supported by text, enum, Sources, and Workflows controls. This is a binary operator, not a collection quantifier.                                                                                                                                                                                          |
| Activity and signal recency        | The predefined recency `BinOp` with `WithinLast` / `NotWithinLast`, using days, weeks, or months. Available activity fields and predefined signal payload fields also have their own controls.                                                                                                             |
| Predefined `ColOp` with `AnyItems` | Signal collection controls: job-change employment titles/companies, promotion previous companies, News topics, website-event URL/path, and topic-intent readings. Also source sync status and the specific-signal results shape in `filters.md`. Preserve the UI-defined paths, leaf order, and operators. |

Ordinary collection controls use an `And` condition containing the edited leaf;
they do not support arbitrary extra predicates. Topic intent explicitly supports
its declared same-reading constraints (topic, tier, score, provider, recency).
Specific-signal results preserve a fixed signal ID alongside recency.

## Unsupported shapes

- Generic `AggOp` aggregation, such as count, sum, or group-by.
- Arbitrary `ColOp` predicates, including activity same-event conditions, extra
  payload/date constraints on ordinary signal collections, nested collections,
  or an inner `Or`. The predefined shapes above are the exceptions.
- `AllItems` / `NoItems` collection quantifiers. An inner negative comparison is
  not equivalent to “no element matches.”
- Arbitrary JSON paths, field-to-field comparisons, formulas, or operators the
  field's UI does not offer. A recognized field alone does not establish support
  for the whole filter.

Separate activity or signal filters do not require the same event to satisfy
both. Splitting “a matching event within the last 7 days” into independent
payload and recency filters can change the meaning.

## Field operators

These are the standard UI choices. Specialized fields may offer a narrower or
different set; do not apply every backend operator to every field.

| Field/control type                         | Operators offered                                                                                         |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Text, URL                                  | `Equal`, `NotEqual`, `Contain`, `NotContain`, `ContainAny`, `StartsWith`, `EndsWith`, `Empty`, `NotEmpty` |
| Number, currency                           | `GreaterThan`, `LessThan`, `Equal`, `GreaterThanOrEqual`, `LessThanOrEqual`, `Empty`, `NotEmpty`          |
| Boolean                                    | `True`, `False`                                                                                           |
| Select/enum                                | `Equal`, `NotEqual`, `ContainAny`                                                                         |
| Sources / Workflows array controls         | `Contain`, `ContainAny`, `NotContain`                                                                     |
| Workspace date field                       | `WithinLast`, `NotWithinLast`, `WithinNext`, `NotWithinNext`, `Empty`, `NotEmpty`, `Before`, `After`      |
| Record/deal creation and update timestamps | `WithinLast`, `NotWithinLast`, `Before`, `After`                                                          |
| Activity and signal recency                | `WithinLast`, `NotWithinLast`                                                                             |

Email, image, long text, users, JSON, message, and validation-result field types
use text controls. Use fields available in the segment editor; arbitrary JSON
subpaths are not supported.

Date units offered here are **days, weeks, and months**; no hour/year picker.
Relative values must be positive. `Before`/`After` use a date-time input, display
in the viewer's local timezone, and convert back to UTC for requests. A text field
containing an ISO date does not gain date operators.

Not every backend operator is offered: examples include `SimilarTo`, numeric
`NotEqual`, generic text `NotStartsWith`/`NotEndsWith`, and arbitrary collection
quantifiers. Preserve existing Origin source filters rather than generalizing
their operators to other text fields.

## Predefined collection shapes

Ordinary collection controls emit `AnyItems` with an `And` condition whose first
item is the edited `BinOp`. The outer path identifies the collection; the first
leaf path identifies the element property (`title`, `company`, `url`, `path`,
or `["."]` for primitive News topics). The UI does not let users select
`AnyItems` versus `NoItems` versus `AllItems`, or change the inner group to `Or`.
An inner `NotEqual`/`NotContain` is not equivalent to “no element matches.”

### Signal collection fields

These single-leaf collection shapes are allowed in saved segments. Outer paths
below are arrays of the displayed segments (the slashes are only table notation).
Use the listed leaf key and relative leaf path, with the entity of the owning
signal and the text/URL operators above. Do not append a date or other payload
condition to these shapes.

| Leaf key                                  | Outer path                                                | Leaf path     | Entity / control |
| ----------------------------------------- | --------------------------------------------------------- | ------------- | ---------------- |
| `signal_JobChange_current_title`          | `signal_events / data / fullProfile / current_experience` | `["title"]`   | CONTACT / text   |
| `signal_JobChange_current_company`        | `signal_events / data / fullProfile / current_experience` | `["company"]` | CONTACT / text   |
| `signal_JobChange_experience_title`       | `signal_events / data / fullProfile / experience`         | `["title"]`   | CONTACT / text   |
| `signal_JobChange_experience_company`     | `signal_events / data / fullProfile / experience`         | `["company"]` | CONTACT / text   |
| `signal_Promotion_experience_company`     | `signal_events / data / fullProfile / experience`         | `["company"]` | CONTACT / text   |
| `signal_News_topics`                      | `signal_events / data / newsData / newsTopics`            | `["."]`       | ACCOUNT / text   |
| `signal_WebsiteVisitorTracking_url`       | `signal_events / data / websiteEvents`                    | `["url"]`     | ACCOUNT / URL    |
| `signal_WebsiteVisitorTracking_page_path` | `signal_events / data / websiteEvents`                    | `["path"]`    | ACCOUNT / text   |

### Topic intent

Topic intent is the explicit compound exception: topic, tier, score, and provider
chips offer the other three reading properties plus recency under “Where the
same reading has.” Only these declared properties and recency are supported;
there is no arbitrary-condition builder. Tier/provider use `ContainAny` and
`NotContainAny`; topic uses those when configured topics are available, otherwise
text operators excluding `Equal`/`NotEqual`. Score uses number operators.
Constraint rows exclude `Empty`/`NotEmpty`; list-valued operators are retained
only for enum constraints. Recency constrains the signal event's activity time.

For topic intent, the outer path is `["signal_events", "data", "newTopics"]`.
Leaf keys are `signal_PersonTopicIntent_<suffix>` (CONTACT) or
`signal_CompanyTopicIntent_<suffix>` (ACCOUNT), where suffix/path are
`topic`/`["topicName"]`, `tier`/`["tier"]`, `score`/`["score"]`, and
`provider`/`["provider"]`. Put the primary edited leaf first and optional sibling
constraints after it in the same `And` condition. Recency uses the corresponding
`signal_<Type>_aggregate_occurrences` key, path
`["signal_events", "activity_time"]`, `WithinLast`/`NotWithinLast`, numeric value,
and `day`/`week`/`month`. Do not nest another collection. Tier values are
`high`/`medium`/`low`; providers are `delivr`/`intentsify` for People and also
`bombora` for Companies. Discover configured topic names instead of inventing them.

### Source sync status

Source sync status is another allowed single-leaf `AnyItems`/`And` shape. The
outer path is `["<contact|account>_entity_field_values", "field",
"external_source_sync_status_v3", sourceType, sourceId]`, with `sourceSubtype`
appended when the actual source has one. The leaf has key
`external_source_sync_status_v3`, path `["2"]`, and `Equal`/`NotEqual`/`ContainAny`.
Use the actual source metadata and owning entity, not guessed IDs. Values are
`STAGED`, `SYNCED_IN`, `DISCONNECTED`, `DELETED_FROM`, and `NOT_CONNECTED`.
Unlike the ordinary Sources control, this source-specific shape can include subtype.

### Specific-signal results

Specific-signal results support the [example in filters.md](filters.md#filter-by-signal-activity):
recency first, then a fixed signal-ID equality in the same `AnyItems` condition.
Keep that order and scope; do not append arbitrary payload conditions.

## Recognizing a compatibility problem

An unsupported saved condition may display an “Unsupported filter” pill and be
ignored when showing records. A visible chip or a matching CLI count does not
prove that every condition is represented. In particular, do not add extra
conditions to a predefined collection and assume they are supported because its
main field still displays.
