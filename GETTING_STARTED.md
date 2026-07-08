# Getting started with Clay

> This file is written to be handed to your coding agent. Point it here (paste
> the link or the file itself) and ask it to set Clay up for you — installing,
> putting `clay` on PATH, and signing in are all things the agent can do on
> your behalf by following the steps below.

Build with Clay in your AI coding agent — skills, MCP tools, and the Clay CLI.

## Installation

### Claude Code

```
/plugin marketplace add clay-run/agent-plugins
/plugin install clay@clay-plugins
```

### Codex

```
codex plugin marketplace add clay-run/agent-plugins
```

Then open **Plugins** and install **clay**.

### Cursor

Teams/Enterprise: Settings → Plugins → Add Marketplace → Import from Repo → [`clay-run/agent-plugins`](https://github.com/clay-run/agent-plugins).

Otherwise (local install): the repo root is a *marketplace*, so clone it and copy the plugin itself — the `clay/` folder, which holds the plugin manifest — into your Cursor plugins dir, then reload Cursor:

```
git clone https://github.com/clay-run/agent-plugins.git
cp -R agent-plugins/clay ~/.cursor/plugins/local/clay
rm -rf agent-plugins
```

## Put `clay` on your PATH

In **Claude Code** the bundled `clay` CLI is on the agent's PATH automatically — skip this section.

**Codex and Cursor do not add a plugin's `bin/` to PATH.** The simplest fix is to ask the agent to run the bundled **`setup` skill**, which handles this — and signing in — for you. To do it by hand, drop a forwarder — *not* a symlink, since the launcher locates its own files by path — into a directory on your PATH:

```
mkdir -p ~/.local/bin
launcher="$(find ~/.codex ~/.cursor ~/.claude ~/.config -type f -path '*/bin/clay' 2>/dev/null | sort | tail -1)"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$launcher" > ~/.local/bin/clay
chmod +x ~/.local/bin/clay
```

## Sign in

Already ran the bundled `setup` skill above? You're signed in too — skip to **What's next**.

The `clay` CLI and the Clay MCP server (`clay mcp`, the local proxy the plugin registers) share one session:

```
clay login
```

This opens a browser, you sign in and pick a workspace, and the session is stored on disk — there's nothing separate to configure for the MCP server. The flow waits up to 5 minutes for the browser round-trip; if your shell tool's timeout is shorter, background the command and poll `clay whoami`, or run `clay login` in your own terminal instead.

**Restart your agent afterward** — `clay mcp` resolves its session once at startup, so an already-running MCP server won't see a session created after it launched.

Verify with `clay whoami` — exit 0 prints your user and workspace; exit 3 means you're not signed in.

## What's next

Once you're set up, run the bundled **`clay` skill** — it's the entry point for what Clay can do: choosing the right primitive (Search vs. Routines vs. Tables), and links out to every other skill (`routines`, `workflows`, `tables`, `search`, `public-api`, `cli`).
