<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://claydevelopers.mintlify.app/logo/clay-logo-dark.png">
    <img src="https://claydevelopers.mintlify.app/logo/clay-logo-black.png" alt="Clay" height="40">
  </picture>
</p>

<p align="center">
  <strong>Build with Clay in your AI coding agent</strong> — skills, MCP tools, and the <code>clay</code>
  CLI, for Claude Code, Codex, and Cursor.
</p>

<p align="center">
  <a href="https://claydevelopers.mintlify.app">Docs</a> · <a href="./GETTING_STARTED.md">Getting started</a>
</p>

Clay is a go-to-market data and automation platform — search for companies and
people, run enrichment routines, and query tables, all from natural language.
This repo is the plugin marketplace for `clay`: one plugin source, three
coding-agent targets, sharing one set of skills and one CLI.

## Example

> "Find 20 Series B fintech companies in NYC, then get me each CEO's work email."

Your agent turns that into a **Search** for the company list, then a **Clay-managed
function** (`find work email`) per contact — no Clay UI, no manual list-building:

```
Acme Corp        Jane Doe        jane.doe@acmecorp.com
Northbeam        Alex Chen       alex@northbeam.io
Ledgerly         Sam Osei        sam.osei@ledgerly.com
```

## Install

- **Claude Code:** `/plugin marketplace add clay-run/agent-plugins` then `/plugin install clay@clay-plugins`
- **Codex:** `codex plugin marketplace add clay-run/agent-plugins`, then open **Plugins** and install `clay`
- **Cursor:** Teams/Enterprise — Settings → Plugins → Add Marketplace → Import from Repo → [`clay-run/agent-plugins`](https://github.com/clay-run/agent-plugins).

Requires **Claude Code v2.1.91+**. Codex and Cursor don't add a plugin's `bin/`
to PATH automatically — [`GETTING_STARTED.md`](./GETTING_STARTED.md) covers that.

## Set up

New here? Point your coding agent at **[`GETTING_STARTED.md`](./GETTING_STARTED.md)**
and ask it to set Clay up for you. It walks through signing in with `clay login`,
getting `clay` on PATH, and choosing the right Clay primitive (Search, Routines,
or Tables) for your task.

## Feedback

Ask your agent to run the bundled `clay-feedback` skill to send a bug report or
product feedback straight to the Clay team.
