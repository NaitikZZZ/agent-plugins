---
name: cli
description: Clay CLI — the primary scripting surface (JSON output, typed errors). Use when running or discovering `clay` commands. For what Clay can do and which skill to use, read the `clay` skill when it is available; otherwise run `clay --help`. Use `clay --help` for command names, flags, JSON shape, and error codes.
---

# The `clay` CLI

The `clay` CLI is Clay's primary programmatic surface, optimized for agents: JSON
output and typed error codes. It authenticates via **`clay login`** (browser OAuth;
run the `setup` skill once if `clay whoami` fails). The workspace is resolved from
the stored session — there is no workspace id to pass.

## Discovering commands

When a user asks what they can do with Clay, use the `clay` skill when it is available — that is the table of
contents for product surfaces. This skill is how to invoke the CLI.

`clay --help` is the live list of top-level commands. The help text is a machine-readable
spec: use it for command names, flags, JSON output shape, and error codes. Do not treat
it as the answer to "what can I do with Clay?"

```bash
clay --help                 # top-level commands
clay <group> --help         # a group's subcommands
clay <group> <cmd> --help   # exact flags, JSON output shape, and error codes
```

## Prefer simple, single commands

Prefer running one plain `clay` command at a time. Avoid redirecting or
substituting (`&&`, `||`, `>`, `$(…)`, backticks, `$VAR`, etc.) unless it's genuinely
necessary — those forms fall through to a manual approval prompt, whereas a simple
`clay <group> <cmd>` call is auto-approved.

Piping (`|`) is fine when the other stages are common read-only helpers like `jq` that
transform stdin without opening files. Semicolon chaining (`;`) is narrower: each
clause must be `clay`, or a literal `echo` / `printf` (not `cat` / `jq` / …). Anything
else falls through to a prompt.

## When to use the CLI vs the Public API

Use the CLI for scripting and agent-driven tasks in a shell. To build a service, app,
or integration that talks to Clay over HTTP, use the **Public API** (`public-api` skill).

Full developer documentation (CLI reference, Public API reference, concepts, OpenAPI
spec) lives at: https://developers.clay.com/llms.txt
