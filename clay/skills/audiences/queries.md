# Search Audiences with DSL

Prefer `--query` for ad-hoc people, company, and opportunity (deal) counts and ID searches,
and for activity counts. These queries
search the workspace's existing records, not the net-new prospect database.
Use the default field IDs in `SKILL.md`; for other fields, discover IDs once with
`clay audiences fields list --entity-type people --include-system` (or
`companies`) and reuse the response. A field's existence does not mean it is
populated. See `answering-data-questions.md` for checking coverage and values.

```bash
clay audiences records search-count --query 'count from people where email is_not_null'
clay audiences records search-ids --query 'select from companies where domain = "clay.com"' --limit 100 | jq .data
```

Use `count from <root> where ...` with `search-count` to count the entire match set.
Use `select from people|companies|opportunities where ...` with `search-ids` to return `.data` and an optional `.cursor`.
To count and fetch IDs for the same scope, keep the `from ... where ...` clause and
change only `count` to `select`; the commands do not rewrite the query for you.
When paging IDs, repeat the same `select` query and
pass the cursor verbatim to `--cursor`; stop when it is absent. Use `--limit` for
ID page size, not a DSL limit clause. Counts cover the whole scope even when
the count query includes a limit. `--archived` searches archived records.
The query's `from` root determines what is counted or returned; omit
`--entity-type`. The flag is required for AST, saved-audience, and unfiltered
searches. Combining `--entity-type` with `--query` is an error, even if they name the same entity.

## Deals and activities

Use `opportunities` (not `deals`) as the DSL root to return deal counts or IDs.
Discover deal fields with `clay audiences fields list --entity-type deals`.
Use `records get --entity-type deals --ids ...` to read the returned deal IDs.

```bash
clay audiences records search-count --query 'count from opportunities where is_closed = false'
clay audiences records search-ids --query 'select from opportunities where is_closed = false' --limit 10
clay audiences records search-count --query 'count from activities'
```

Activity IDs are strings; the current `search-ids` endpoint requires numeric IDs
and cursors, so it cannot page activity IDs. Use the activities commands for a
saved audience's activity feed. Activity counts can use `count from activities`.

For associated records, use predicates such as
`select from opportunities where company.domain = "clay.com"` or
`select from companies where opportunities.exists(is_won = true)`.
The root determines what is returned: the first query returns deals, the second companies.
Activity predicates can use typed fields, for example
`count from activities where task.subject contains "demo"`.

## Supported DSL grammar

This is the syntax supported by **Audiences**. In the sketch below, `[ ... ]`
means optional and `|` means alternatives; neither is literal query text.

```text
query       := (select | count) from (people | companies | opportunities | activities) [where predicate] [limit integer]
predicate   := term [or term ...]
term        := factor [and factor ...]
factor      := not factor | (predicate) | comparison | relationship_test
comparison  := field scalar_op value
             | field (in | not_in) (value, ...)
             | field (is_null | is_not_null)
scalar_op   := = | != | < | <= | > | >= | contains | starts_with | ends_with
relationship_test := relationship.(any | exists)([row_predicate])
                   | relationship.count([row_predicate]) count_op number
                   | relationship.count([row_predicate]) (in | not_in) (number, ...)
count_op    := = | != | < | <= | > | >=
value       := "string" | number | true | false | date_expression
date_expression := today() [(+ | -) interval positive_integer unit]
unit        := day | week | month | year
```

- **Query shape:** omit `where` to match every record. Use `select from`, not
  `select * from`, and `count from`, not `select count(*)`. `search-ids` rejects
  a DSL `limit`; use `--limit` and `--cursor`. Native count queries accept a limit
  but count the whole scope.
- **Fields:** use an existing field ID such as `email`, or the intrinsic fields
  `id` and `created_at`. Use `people.email` from companies and `company.domain`
  from people. Field lookup also accepts normalized display names (for example,
  `job_title` for “Job Title”); prefer discovered IDs to avoid ambiguous names.
  Entity prefixes accept `company`, `companies`, `account`, `accounts` and
  `person`, `people`, `contact`, `contacts`; prefer `company` and `people`.
- **Relationships:** use the other entity's prefix before `.any`, `.exists`, or
  `.count`. A `row_predicate` uses comparisons and boolean groups on that related
  record; it cannot contain another relationship call. Empty parentheses apply
  to all associated records. `.count(...)` requires a trailing comparison.
- **Values:** double-quote DSL strings; single quotes may wrap the whole query in
  the shell. Escape a double quote as `\"` and a backslash as `\\` inside a DSL
  string. Numbers are unsigned integer or decimal literals; booleans are unquoted.
  Lists use parentheses, contain at least one value, and have no trailing comma.
  Match values and operators to the field's data type.
- **Dates:** `created_at >= today() - interval 30 day` uses midnight UTC as the
  anchor. Intervals accept positive integers and singular or plural units, such
  as `week` or `weeks`. A quoted date can also be compared against a date field.
- **Logic:** precedence is `not`, then `and`, then `or`; use parentheses to make
  grouping explicit. Negate text predicates with `not (title contains "Sales")`.
  Keywords are case-insensitive. Line comments use `--` and block comments use
  `/* ... */`; `#` is not a DSL comment.
- **Empty values:** use `email is_null` or `email is_not_null`, without a value
  argument. These use Audiences empty/not-empty semantics, so an empty text value
  is not populated. Do not write `email = null` or `email is not null`.
- **Unavailable here:** selected-column lists, SQL joins/subqueries, `order by`,
  `group by`, `limit ... by`, `is_similar_to`, `clay.*` functions, jobs, and nested
  relationship calls. Activities, signals, deals, and other CPJ relationships
  require an equivalent supported AST filter when available. The executor's
  `$name` variables require API bindings; these CLI commands have no binding flag,
  so provide literal values.

## Text matching

`contains` matches a substring, not a word or a semantic category.
`starts_with` and `ends_with` match a prefix and suffix. These text operators
are case-insensitive. In Audiences,
`title contains "CTO"` can match "Director of Sales". Use `title = "CTO"`
or `title in ("CTO", "Chief Technology Officer")` for exact values; use
`title contains "Engineer"` only when that substring is the intended criterion.
For an ambiguous category, inspect a small sample of populated values before
choosing a predicate, and state the interpretation in the answer. Do not keep
guessing synonyms until a query returns results.

## Relationship predicates (a company's people, a person's company)

Use `people.<field>` from companies, or `company.<field>` from people.
These traverse existing Audiences associations; a matching email/domain alone
does not establish an association. Results always belong to the `from` entity.
Use `people.any(...)` for a company with at least one matching person
(`people.exists(...)` is equivalent). Inside the parentheses, fields refer to
that person. Do not invent SQL joins or forms such as `any people (...)`.

```text
-- One associated person must satisfy both conditions.
select from companies where people.any(email is_not_null and title contains "Engineer")

-- A simple conjunction of dotted person fields has the same meaning.
select from companies where people.email is_not_null and people.title contains "Engineer"

-- Separate any() clauses may match different people at the company.
select from companies where people.any(title = "CTO") and people.any(title = "CFO")

-- At least two associated people satisfy the inner predicate.
select from companies where people.count(email is_not_null) >= 2

-- People whose associated company has a domain.
select from people where email is_not_null and company.domain is_not_null
```

Prefer explicit `any(A and B)` when conditions must hold on the same related
record, especially with mixed `and`/`or` expressions. Separate `any(A)` and
`any(B)` clauses do not require different people, but allow them.
`people.title != "CTO"` means a related person has a nonmatching title;
it does **not** mean the company has no CTO.

Combine company fields and person conditions, then reuse the scope:

```bash
scope='from companies where domain is_not_null and people.any(email is_not_null and title contains "Engineer")'
clay audiences records search-count --query "count $scope"
clay audiences records search-ids --query "select $scope" --limit 10
```

Do not page through every result when the user asks only for the first 10.
Fetch field values with `records get` only if needed to answer or validate the
interpretation; count and ID commands do not return field values.

## Existence and relationship counts

Use `.exists(...)` (equivalent to `.any(...)`) for “at least one”, and `.count(...)`
when the number of matching related records matters. Put field conditions inside
the parentheses; put a numeric count comparison after them. Empty parentheses
mean all associated records, without a field condition.

| Question about a company                                        | Predicate                                                |
| --------------------------------------------------------------- | -------------------------------------------------------- |
| Has any associated person                                       | `people.exists()`                                        |
| Has a person with both a title and an email                     | `people.exists(title is_not_null and email is_not_null)` |
| Has no person with an email, including companies with no people | `not people.exists(email is_not_null)`                   |
| Has at least three associated people                            | `people.count() >= 3`                                    |
| Has exactly two people with an email                            | `people.count(email is_not_null) = 2`                    |
| Has no people with an email                                     | `people.count(email is_not_null) = 0`                    |
| Has either zero or two people with an email                     | `people.count(email is_not_null) in (0, 2)`              |

Conditions inside one `.exists(...)` or `.count(...)` apply to the same related
record. Separate calls are independent: `people.exists(title = "CTO") and
people.exists(title = "CFO")` may match different people. Negation outside the
call means no matching people; `people.exists(title != "CTO")` only requires
one non-CTO and can still match a company that also has a CTO.

Count comparisons support `=`, `!=`, `<`, `<=`, `>`, `>=`, `in`, and `not_in`
with numeric values. Positive upper bounds (`< N` / `<= N`), nonzero exclusions
(`!= N`), and `not_in` lists that omit zero only consider companies with at least
one matching person. Companies with zero matches never form a group. When zero
satisfies the requested condition, include it explicitly using the **same inner
predicate** in both count expressions:

| Requested matching-person count | Zero-inclusive predicate                                                               |
| ------------------------------- | -------------------------------------------------------------------------------------- |
| At most three                   | `people.count(email is_not_null) = 0 or people.count(email is_not_null) <= 3`          |
| Anything except two             | `people.count(email is_not_null) = 0 or people.count(email is_not_null) != 2`          |
| Neither two nor three           | `people.count(email is_not_null) = 0 or people.count(email is_not_null) not_in (2, 3)` |

Wrap the entire `or` expression in parentheses before combining it with another
condition using `and`. Do not add the zero branch when the request excludes zero,
such as `people.count(...) != 0` or `people.count(...) not_in (0, 2)`.
The dedicated zero-match forms `= 0`, `< 1`, and `<= 0` already include companies
with no matches and need no extra branch.

```bash
clay audiences records search-ids --query 'select from companies where domain is_not_null and (people.count(email is_not_null) = 0 or people.count(email is_not_null) <= 3)' --limit 10
clay audiences records search-count --query 'count from companies where people.exists(email is_not_null) and people.count() >= 3'
```

The second command counts **companies** with at least three associated people
and at least one person with an email. `people.count(...)` filters companies by
the number of related people; it does not return that number or change the
result entity. Use `count from people ...` to count people themselves.
Nested relationship calls inside `.any(...)`, `.exists(...)`, or `.count(...)`
are unsupported.

Use `--audience-id` for saved audiences. If diagnosis reports an unsupported construct, retry with an equivalent `--filter`
AST on a supported people/company root using `filters.md` and `custom_objects.md`. Do not drop unsupported conditions.
The flags are mutually exclusive, and there is no automatic retry or translation.
Creating or updating saved audiences still uses the AST. Unfiltered deal counts
and ID searches use `--entity-type deals` without `--query`.
