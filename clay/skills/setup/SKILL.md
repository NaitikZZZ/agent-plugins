---
name: setup
description: Clay setup — install and authenticate the `clay` CLI, which is how the plugin talks to Clay. Use when `clay` is not found on PATH or the `clay` found in the PATH is the wrong version, `clay whoami` fails, the CLI isn't signed in, the Cursor plugin never appears after a local install, or the user wants to configure Clay. Signs the user in and runs first-run onboarding for new users.
allowed-tools: Bash, Read, Edit, Write
---

# Clay setup

Skills reach Clay through the **`clay` CLI**. **`clay login`** opens a browser once and stores
the session on disk; the CLI re-reads it on every command, so `clay whoami` succeeding is the
whole proof.

## 1. Check current state

Run this and read the printed **exit_code and JSON**, not any status string:

```bash
clay whoami; echo "exit_code=$?"
```

- **exit_code=0** with a `user`/`workspace` object → the CLI is authenticated.
  Also confirm it isn't an old install shadowing the bundled launcher, which a `whoami`
  alone can't tell you — compare the resolved version against the version this plugin
  pins in `bin/cli-version` (two levels up from this skill's directory):

  ```bash
  # A released binary reports `<semver>+<commit>`; compare only the semver.
  clay --version | cut -d+ -f1
  cat "<THIS_SKILL_DIR>/../../bin/cli-version"
  ```

  - **same version, or newer than the pin** → the CLI is current. If `whoami`
    reported `onboarded: false`, do step 6 before stopping. Otherwise tell the
    user (name the workspace) and stop — unless the reported symptom was
    specifically "the Cursor plugin never appears in Settings → Plugins," in
    which case this only proves a `clay` on PATH works, not that it's the Cursor
    plugin's own install; still do step 2 to confirm.
  - **older than the pin** → an outdated `clay` is shadowing the bundled launcher. Do
    step 3 to put the launcher ahead of it on PATH, then re-run this check.

- **`clay: command not found`** (or exit 127) → the CLI isn't on your PATH. One
  exception first, on any platform: exit 127 with a JSON envelope on stderr saying
  `no bundled launcher found` is the forwarder from a previous setup reporting that
  the plugin cache itself is gone — reinstalling the forwarder won't help; tell the
  user to reinstall the Clay plugin instead (on Cursor, reinstalling means redoing
  step 2 — the working install method is policy-dependent). Otherwise, route by
  platform:
  - **Claude Code**: if the plugin was just installed in this session, this is expected —
    Claude Code only adds a newly installed plugin's `bin/` to PATH starting with the
    _next_ session. Don't install a forwarder for this: resolve the bundled launcher's
    absolute path once and invoke that directly for the rest of this session instead of
    waiting on a restart —

    ```bash
    shim="$(sh -c 'ls -1dt "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/clay/*/bin/clay 2>/dev/null | head -n1')"
    [ -x "$shim" ] || { echo "could not locate the bundled clay launcher; reinstall the plugin"; exit 1; }
    "$shim" whoami; echo "exit_code=$?"
    ```

    Use this same resolved path in place of bare `clay` for every remaining command in
    this skill (step 4's `clay login` included) — but re-run the `ls -1dt` one-liner
    fresh immediately before each one rather than reusing `$shim` across separate tool
    calls: each Bash call starts a new shell, so a variable set in one call is gone in
    the next. Bare `clay` starts working again on its own once the agent is next
    restarted, so no restart is needed just for PATH. Only fall back to
    step 3's forwarder if the launcher can't be located at all (e.g. the plugin cache is
    gone), if another `clay` install is shadowing the bundled one after a restart, or if
    bare `clay` is still not found after a restart — that last case means the
    next-session auto-PATH isn't happening, so this is no longer a one-restart hiccup
    the launcher path can paper over.

  - **Codex**: skip step 2 and go straight to step 3, then step 4 — Codex does not add a
    plugin's `bin/` to PATH automatically, so restarting alone won't fix this.
  - **Cursor**: do step 2 first (it decides where the plugin's files permanently live);
    then step 3, then step 4.

- **exit_code=3** (`auth_*`) → the CLI works but isn't authenticated. Skip to step 4.
- **exit_code=5** (`network_*`) → a connection problem. Check `CLAY_API_URL` and the
  network; do not restart the sign-in flow.

## 2. Cursor only: resolve which install path applies

Skip this entire section on Claude Code and Codex — they don't have this policy layer.

On Cursor, Teams/Enterprise org policy can silently block the naive "copy the plugin folder
into `~/.cursor/plugins/local/clay`" approach: the plugin never appears in Settings → Plugins
no matter how many times you restart, because the org disabled local sideloading. Read
`cursor-install.md` (in this same directory as this `SKILL.md`) in full and follow it — it
covers reading Cursor's resolved policy and choosing/applying the right install path (team
marketplace, personal marketplace import, or local sideload). If that runbook **stops**
(marketplace import still pending, or every import path is blocked), wait for the user/admin
and a full Cursor restart before continuing — do not jump to step 3 with no launcher on disk.
Otherwise continue to step 3 below (including when marketplace import is the only allowed
path and the plugin cache already has a launcher).

## 3. Put `clay` on your PATH (if it was "command not found" or is an outdated version)

The plugin bundles the CLI launcher at `bin/clay` in the plugin root; it downloads
and checksum-verifies the real binary on first use. The launcher is version-stable
(it reads its neighbor `bin/cli-version` and fetches that CLI), so the forwarder
just needs to point at the newest launcher on disk.

Install a small forwarder onto your PATH (in `~/.local/bin`) that resolves the
newest bundled launcher **at runtime** rather than baking in one absolute path.
This is what lets it survive plugin updates (which install a new version directory)
and work no matter which agent (Claude Code / Codex / Cursor) installed the plugin.
It picks the most-recently-modified launcher — an install-time heuristic that works
across both version-named cache dirs (Claude/Codex) and commit-hash-named ones
(Cursor). If one agent's cache lags behind another's, the freshest install wins, so
the CLI can briefly trail the newest pin until the caches converge — every launcher
is self-contained, so it still runs a valid checksum-verified CLI.

First confirm a launcher actually exists where the forwarder will look — this is
the same resolution the forwarder performs, run once now so a missing plugin
cache fails loudly here instead of as a confusing 127 later (run it through `sh`
so unmatched globs stay harmless even if your shell is zsh):

```bash
sh -c 'ls -1dt \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/clay/*/bin/clay \
  "${CODEX_HOME:-$HOME/.codex}"/plugins/cache/*/clay/*/bin/clay \
  "$HOME"/.cursor/plugins/cache/*/clay/*/bin/clay \
  "$HOME"/.cursor/plugins/local/clay/bin/clay \
  "$HOME"/.config/clay-plugin/clay/bin/clay \
  2>/dev/null | head -n1'
```

If this prints nothing, **stop** — no bundled launcher exists in any known plugin
cache, so the forwarder below would have nothing to exec. Tell the user to
reinstall the Clay plugin (on Cursor, that means redoing step 2 — the working
install method is policy-dependent), then re-run this skill. (If you read this SKILL.md
from a plugin root outside these caches, report that path to the user — the
plugin is installed somewhere this forwarder doesn't search.)

If it printed a path, install the forwarder (keep its search list in sync with
the pre-flight above and with step 1's Claude Code one-liner):

```bash
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/clay" <<'EOF'
#!/bin/sh
# Resolve the newest bundled clay launcher at runtime so this forwarder survives
# plugin version bumps and works whichever agent (Claude/Codex/Cursor) installed it.
# CLAUDE_CONFIG_DIR and CODEX_HOME relocate those agents' state roots (and with
# them the plugin cache), so honor them when set — they expand here at runtime,
# from the invoking process's environment.
launcher="$(ls -1dt \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/clay/*/bin/clay \
  "${CODEX_HOME:-$HOME/.codex}"/plugins/cache/*/clay/*/bin/clay \
  "$HOME"/.cursor/plugins/cache/*/clay/*/bin/clay \
  "$HOME"/.cursor/plugins/local/clay/bin/clay \
  "$HOME"/.config/clay-plugin/clay/bin/clay \
  2>/dev/null | head -n1)"
# Match the launcher's bootstrap-failure contract: JSON envelope on stderr and a
# categorical exit code (127 = command not found).
[ -x "$launcher" ] || { printf '{"error":{"code":"internal_error","message":"clay: no bundled launcher found in plugin cache; reinstall the Clay plugin"}}\n' >&2; exit 127; }
exec "$launcher" "$@"
EOF
chmod +x "$HOME/.local/bin/clay"
```

Ensure `~/.local/bin` is on PATH (for this session and future ones):

```bash
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH"
     for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
       [ -e "$rc" ] && ! grep -q '.local/bin' "$rc" && printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
     done ;;
esac
```

`command -v clay` should now resolve — but confirm it's actually the bundled
launcher and not a shadowing install, since nothing pins the bundled path for a
bare `clay`:

```bash
# A released binary reports `<semver>+<commit>`; compare only the semver.
clay --version | cut -d+ -f1
# <LAUNCHER> is the path the pre-flight above printed. Read the pin from there
# rather than relative to this SKILL.md — the plugin copy you are reading is not
# necessarily the one the forwarder resolves.
cat "$(dirname "<LAUNCHER>")/cli-version"
```

- **same version, or newer than the pin** → whichever `clay` is first on PATH is current;
  leave it as-is (a different `clay` taking precedence — e.g. a newer standalone install —
  is fine).
- **exit 127 with `no bundled launcher found`** on stderr → the forwarder ran but found no
  launcher. The plugin cache disappeared since the pre-flight above, or the check hit a
  different stale forwarder; don't touch PATH — tell the user to reinstall the Clay plugin.
- **older than the pin** → an older `clay` is shadowing the forwarder you just installed.
  Move the `export PATH=...` line above in your shell rc so `~/.local/bin` comes before the
  old install's directory, open a new shell, and re-run the check.

**Restart required (Codex and Cursor):** a running process resolved its PATH before this
step ran, so it won't see the newly-created `~/.local/bin/clay` entry until it's restarted.
This restart is one-time — the forwarder never needs repointing after plugin updates.
**Stop here** — tell the user to fully quit and reopen the agent (Codex/Cursor), then re-run
this skill from step 1. Do **not** continue to step 4 (`clay login`) in the same session: the
next tool call still inherits the old PATH, so login can fail or keep using a shadowing binary.

## 4. Sign in

Only after step 1's `command -v clay` / version check succeeds in **this** session (including
after a restart from step 3). Run `clay login`. It opens a browser, the user signs in and picks
a workspace, and the CLI stores the session locally on disk and re-reads it on every command, so
there's nothing else to configure and no restart to follow it. The flow waits up to 5 minutes for
the browser round-trip. If your shell tool lets you set a per-command timeout, request at least 5
minutes and just run it directly and block on it:

```bash
clay login   # request a timeout of at least 5 minutes if your tool supports one
```

If your tool's timeout can't be raised past 5 minutes and it doesn't support
backgrounding a long-running command, ask the user to run `clay login` in their own
terminal instead, then poll:

```bash
clay whoami; echo "exit_code=$?"   # poll this until exit_code=0
```

**Codex specifically:** the shell tool's timeout is usually shorter than the
5-minute browser round-trip, so a foreground `clay login` gets killed
mid-sign-in. The flow itself works on a local Codex session — approved commands
run on the user's machine, outside the sandbox — it just has to survive the
timeout. The recipe:

1. Run `clay login` in the background so the 5-minute wait survives the tool
   timeout:

   ```bash
   nohup clay login >/tmp/clay-login.out 2>/tmp/clay-login.err &
   ```

2. Read the sign-in URL from `/tmp/clay-login.err` and show it to the user to open
   in their own browser (`clay login` also tries to open the browser itself — the
   URL is the fallback). URLs from earlier attempts won't work.
3. Do NOT try to complete the sign-in with Codex's built-in browser tool: the user
   isn't driving it, so their credentials aren't available to enter — and if it
   runs in an isolated or remote context it can't reach the `127.0.0.1` callback
   anyway, so the sign-in is throwaway.
4. Poll `clay whoami; echo "exit_code=$?"` until `exit_code=0`.

If the backgrounded process dies (`clay whoami` never succeeds), fall back to the
run-it-in-their-own-terminal flow above.

## 5. Verify

```bash
clay whoami; echo "exit_code=$?"
```

`exit_code=0` with a `user`/`workspace` object means the CLI is authenticated.

If it exits 3 (`auth_*`) after a successful `clay login`, treat it as a session problem —
not a workspace-role problem. `whoami` only checks that the stored credential is accepted
(`/public/v0/me`); OAuth consent already rejects Viewers, so a completed `clay login` cannot
leave you with a valid-but-wrong-role session. Parse the stderr `error.code` (usually
`auth_invalid` / `auth_required`): the session may not have been written, `CLAY_CONFIG_HOME`
may point at a different store, or a stale key is still winning. Re-run `clay login` (or
`clay logout` then `clay login`) and recheck — do not send the user to an Admin for an
Editor/Admin role change.

Once `whoami` succeeds, re-run the pinned-version check from step 1 — auth success alone
doesn't prove PATH isn't still an old standalone `clay` that lacks the replacement commands:

```bash
# A released binary reports `<semver>+<commit>`; compare only the semver.
clay --version | cut -d+ -f1
cat "<THIS_SKILL_DIR>/../../bin/cli-version"
```

- **same version, or newer than the pin** → if `whoami` (or the `clay login`
  that just ran) reported `onboarded: false`, do step 6. Otherwise setup is
  complete.
- **older than the pin** → do step 3 to put the bundled launcher ahead on PATH, then
  recheck version (and `whoami`) before declaring done.

## 6. First-time onboarding

If `clay whoami` or `clay login` reported `onboarded: false`, run the `onboard`
skill now — it owns the rest: it checks server-side whether this user has been
onboarded (ruling out an outdated CLI hiding the field), welcomes them, offers
the starter tasks, and stands down quietly for anyone onboarded before. It also
defers to any concrete task the user is waiting on. If `onboarded` is `true` or
absent, skip this step — setup is complete.

If you've been substituting a resolved launcher path for bare `clay` this
session (step 1's Claude Code fresh-install case), keep doing so for every
command the onboard skill runs — bare `clay` still isn't on PATH until the next
session. If the skill isn't invocable yet (a plugin installed earlier in this
same session hasn't registered its skills), locate the skill file and follow it
directly:

```bash
find ~/.codex ~/.cursor "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ~/.config -type f \
  \( -path '*/clay/skills/onboard/SKILL.md' -o -path '*/clay/*/skills/onboard/SKILL.md' \) 2>/dev/null | sort | tail -n1
```

## Troubleshooting

| Symptom                                                                        | Cause                                                                                                                              | Fix                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plugin never appears in Settings → Plugins; plugin log shows `userLocal=false` | `allowUserLocalPluginImports` disabled by org policy                                                                               | Use path 1 (team marketplace, admin) or path 2 (personal marketplace, if third-party imports are enabled) — see step 2                                                                                                                                                          |
| "Add Marketplace" → Import options are greyed out or missing                   | Third-party imports policy-locked (`allowThirdPartyPluginImports` off)                                                             | This same flag gates path 1 too, so path 1 isn't a workaround here — an admin must enable `allowThirdPartyPluginImports` first for any marketplace path (1 or 2). Until then, use path 3 (local sideload, if `allowUserLocalPluginImports` is separately still on) — see step 2 |
| The plugin's skills never appear right after applying path 3 in Cursor         | Didn't fully quit and reopen Cursor after installing — a new chat or Reload Window isn't enough for a newly-added local plugin     | Fully quit (Cmd/Ctrl+Q) and reopen Cursor — see step 2                                                                                                                                                                                                                          |
| `clay whoami` exits 3                                                          | Not signed in                                                                                                                      | Run `clay login` — see step 4                                                                                                                                                                                                                                                   |
| `clay whoami` exits 3 right after a successful `clay login`                    | Session not usable (`auth_invalid` / `auth_required` — wrong store, stale key, login didn't stick); not an Editor/Admin role issue | Re-run `clay login` (or `logout` then `login`); check `CLAY_CONFIG_HOME` / stderr `error.code` — see step 5                                                                                                                                                                     |
