# Cursor plugin install: resolving which path applies

On Cursor, Teams/Enterprise org policy can silently block the naive "copy the plugin folder
into `~/.cursor/plugins/local/clay`" approach: the plugin never appears in Settings → Plugins
no matter how many times you restart, because the org disabled local sideloading. Detect the
actual policy before choosing a path, so you don't burn restarts on a path that can never work.

## Read the signal

Cursor caches its resolved org policy locally, so you can read the actual gates instead of
guessing. The cache lives in the `adminSettings.cached` row of Cursor's SQLite state DB:

```bash
case "$(uname -s)" in
  Darwin) cursor_appsup="$HOME/Library/Application Support/Cursor" ;;
  *)      cursor_appsup="$HOME/.config/Cursor" ;;
esac
statedb="$cursor_appsup/User/globalStorage/state.vscdb"

python3 - "$statedb" <<'PY'
import json, sqlite3, sys

path = sys.argv[1]
row = None
try:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    row = conn.execute(
        "SELECT value FROM ItemTable WHERE key LIKE '%adminSettings.cached%' "
        "ORDER BY length(value) DESC LIMIT 1"
    ).fetchone()
except sqlite3.Error:
    pass

if not row:
    print("no cached admin settings — not on a Cursor team, or Cursor hasn't run yet; "
          "fall back to the plugin-log heuristic below")
    sys.exit(0)

try:
    cached = json.loads(row[0])
except ValueError:
    print("cached admin settings weren't valid JSON; fall back to the plugin-log heuristic below")
    sys.exit(0)

if isinstance(cached, str):
    # VS Code-family state rows are sometimes double-encoded: a JSON string holding JSON.
    try:
        cached = json.loads(cached)
    except ValueError:
        pass
if not isinstance(cached, dict):
    print("cached admin settings weren't a JSON object; fall back to the plugin-log heuristic below")
    sys.exit(0)

def allowed(flag):
    # Team policy is opt-out (missing/true means allowed); non-team users are unrestricted.
    return cached.get(flag) is not False

def mcp_allowed():
    cfg = cached.get("allowedMcpConfiguration")
    if not isinstance(cfg, dict):
        return True  # absent, or a shape this heuristic doesn't know — treat as unrestricted
    if cfg.get("disableAll") is True:
        return False
    # Membership checks assume entries are plain server-name strings — same
    # heuristic caveat as the rest of this function (see path 4 below).
    allowlist = cfg.get("allowedMcpServers") or []
    override = cfg.get("allowUserOverrideMcpServers") is True
    if not allowlist and not override:
        return True  # no restriction configured
    if "clay" in allowlist:
        return True
    return override and "clay" not in (cfg.get("deniedMcpServers") or [])

local_ok = allowed("allowUserLocalPluginImports")
marketplace_ok = allowed("allowThirdPartyPluginImports")

if local_ok and marketplace_ok:
    print("path 3 (local sideload): allowed. path 1/2 (marketplace import): also allowed.")
elif local_ok:
    print("path 3 (local sideload): allowed; marketplace import (path 1/2) is policy-blocked")
elif marketplace_ok:
    print("local sideload is policy-blocked; path 1/2 (marketplace import) is allowed")
elif mcp_allowed():
    print("plugin imports are policy-blocked entirely; path 4 (Option A) is the only self-serve path")
else:
    print("plugin imports AND user MCP servers are both policy-blocked — nothing here is "
          "self-serve; only an admin can unblock this (allowUserLocalPluginImports, "
          "allowThirdPartyPluginImports, or the MCP allowlist)")
PY
```

Windows/WSL isn't verified anywhere in this skill (the `*` branch above assumes a Unix-style
`$HOME`, and nothing else here has been tested off macOS) — if this doesn't resolve a real path,
skip straight to the plugin-log fallback below.

**Never write to `adminSettings.cached` or any other row in `state.vscdb` to force a flag on.**
It's re-fetched from the server on every sync and the import RPC re-enforces the same policy
server-side, so editing the local cache doesn't unlock anything — it just corrupts local state
until the next refetch. A blocked flag is the real answer; surface the admin instructions
instead of working around it. The same DB also holds `cursorAuth/accessToken` — don't read,
use, or mention it; it has no legitimate role in this skill.

If `state.vscdb` or `sqlite3`/`python3` isn't available, fall back to Cursor's plugin-load log
instead, which is a weaker but still useful signal:

```bash
latest_session="$(ls -td "$cursor_appsup/logs"/*/ 2>/dev/null | head -1)"
plugin_log="$(find "$latest_session" -name 'Cursor Plugins.log' 2>/dev/null | head -1)"
[ -n "$plugin_log" ] && grep -o 'loadAllPlugins completed[^)]*)' "$plugin_log" | tail -1
```

This prints something like:

```
loadAllPlugins completed in 42.3ms (claude=true, userLocal=false, userSettings=true, marketplace=0 sources, total=3 plugins, failures=0)
```

`userLocal=false` means local sideload is policy-blocked — skip straight to path 2 or path 4.
`userLocal=true` means path 3 will work. If neither signal is available at all (nothing has
launched Cursor yet), assume `userLocal=true` and try path 3 first; the result after restart
will confirm or refute it.

## Apply a path, most legitimate first

Try these in order. Paths 1 and 2 need a human in the Cursor UI and can't be automated from
here — print the exact steps and keep going instead of stopping to wait, so the user ends up
with a working setup (path 3 or 4) while any admin/manual step is still pending. Never leave the
user with nothing just because the "best" path needs someone else to act.

**1/2. Marketplace import — team (admin) or personal (any user).** Both are UI-only, not
automatable from here, and use the same flow: Settings → Plugins → Add Marketplace → Import from
GitHub → enter `clay-run/agent-plugins`, choosing **team** scope (path 1, best for orgs — every
member gets the plugin) or leaving it at **personal** scope (path 2). Team scope needs an admin
with the `team.plugins.manage` permission (team role OWNER); personal scope needs no admin, but
only offer it if the policy read above says it's allowed — `allowThirdPartyPluginImports` gates
both scopes, since `clay-run/agent-plugins` is a third-party marketplace either way. The import
itself is a server-side RPC tied to the account — there's no CLI/script shortcut to complete it,
only to know in advance whether it'll work. State the steps and move on; after the user (or their
admin) does this and fully restarts Cursor, re-run `SKILL.md` step 1 to verify.

**3. Local sideload (automatable, gated by `allowUserLocalPluginImports`).** Skip this path
entirely unless the policy read above (or the plugin-log fallback) showed local sideload is
allowed — running the copy anyway when it's blocked just leaves a dead, never-loading entry under
`~/.cursor/plugins/local/clay` for the user to find and be confused by. If allowed, copy this same
plugin's files into Cursor's local-plugin directory. Resolve the plugin root as two levels up
from the setup skill's own directory (`.../clay/skills/setup` — the same directory that holds
this `cursor-install.md` and `SKILL.md`):

```bash
# Replace <THIS_SKILL_DIR> with the setup skill's directory (the one containing this
# cursor-install.md and SKILL.md, e.g. .../clay/skills/setup):
plugin_root="$(cd "<THIS_SKILL_DIR>/../.." && pwd -P)"
# A bad <THIS_SKILL_DIR> substitution must stop here, before the rm -rf below can
# destroy an existing install: empty means the cd failed, and the manifest check
# catches a substitution that resolved to a real but wrong directory.
[ -n "$plugin_root" ] && [ -f "$plugin_root/.cursor-plugin/plugin.json" ] \
  || { echo "could not resolve plugin root from <THIS_SKILL_DIR>" >&2; exit 1; }
target="$HOME/.cursor/plugins/local/clay"
# Resolve $target through pwd -P too — comparing raw strings would miss a symlinked or
# alternate-spelling path pointing at the same real directory as $plugin_root, and rm -rf
# would delete the source before the copy.
target_real="$(cd "$target" 2>/dev/null && pwd -P)"
if [ "$plugin_root" != "$target_real" ]; then
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  cp -R "$plugin_root" "$target"
fi
```

**4. Direct MCP registration — "Option A" (automatable, gated by `allowedMcpConfiguration`).**
Independent of the entire plugin/marketplace system, so it works even when every plugin policy
is locked down — but it's a separate policy surface, not a guaranteed fallback: the `mcp_allowed`
check above can also come back blocked (org disabled all user-defined MCP servers, or restricted
them to an allowlist that excludes `clay`). If it's blocked, stop and tell the user only an admin
can help — don't attempt this path. The `mcp_allowed` check itself is a heuristic inferred from
Cursor's policy schema, not a guarantee — an empty allowlist with `allowUserOverrideMcpServers:
false` is read as "no restriction configured," but some org configs may intend that combination as
"no user-defined MCP servers at all." If Option A still doesn't work after applying it, treat that
as the real signal and fall back to telling the user only an admin can help. If allowed, tradeoff:
MCP tools only — no bundled skills or hooks, which means the `setup` skill won't be available as a
first-class skill afterward either. That's fine to re-run later: the permanent copy this path
creates (below) includes this same `cursor-install.md`, so read it from
`~/.config/clay-plugin/clay/skills/setup/cursor-install.md` next time — no need to keep the
`/tmp` clone from `GETTING_STARTED.md` around after this setup run finishes.

First, keep a permanent copy of the plugin's files outside any directory Cursor scans as a
plugin source (so it never shows up as a broken, unloaded plugin), but inside a directory
`SKILL.md` step 3's PATH search already checks:

```bash
# <THIS_SKILL_DIR> is the setup skill's own directory, e.g. .../clay/skills/setup:
plugin_root="$(cd "<THIS_SKILL_DIR>/../.." && pwd -P)"
# Same guard as path 3: a bad substitution must fail before the rm -rf below.
[ -n "$plugin_root" ] && [ -f "$plugin_root/.cursor-plugin/plugin.json" ] \
  || { echo "could not resolve plugin root from <THIS_SKILL_DIR>" >&2; exit 1; }
target="$HOME/.config/clay-plugin/clay"
target_real="$(cd "$target" 2>/dev/null && pwd -P)"
if [ "$plugin_root" != "$target_real" ]; then
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  cp -R "$plugin_root" "$target"
fi
```

Then merge (never clobber — other MCP servers may already be configured) a `clay` entry into
`~/.cursor/mcp.json`:

```bash
mcp_json="$HOME/.cursor/mcp.json"
mkdir -p "$(dirname "$mcp_json")"
if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  if [ -f "$mcp_json" ]; then
    cat "$mcp_json" > "$tmp" || { echo "could not read $mcp_json; leaving it untouched" >&2; exit 1; }
  else
    echo '{}' > "$tmp"
  fi
  if jq '.mcpServers.clay = {command:"clay", args:["mcp"]}' "$tmp" > "$tmp.out"; then
    mv "$tmp.out" "$mcp_json"
  else
    echo "could not parse $mcp_json as JSON; leaving it untouched" >&2
    rm -f "$tmp" "$tmp.out"
    exit 1
  fi
  rm -f "$tmp"
else
  python3 - "$mcp_json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        raw = f.read()
except FileNotFoundError:
    raw = "{}"
try:
    config = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(f"could not parse {path} as JSON; leaving it untouched")
config.setdefault("mcpServers", {})["clay"] = {"command": "clay", "args": ["mcp"]}
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
fi
```

## Don't run two paths at once

Whichever path ends up active, clean up the others so re-running this skill later converges
instead of piling up duplicate `clay` MCP registrations. One case can't be cleaned up in this
run: path 4 applied now while a marketplace import is still pending with the user or an admin.
When that import completes later, both registrations exist at once — `SKILL.md` step 1 checks
for exactly that dual registration on any later run and points back to this section.

- Landed on path 3 or a marketplace path? Remove any Option A leftovers:

  ```bash
  rm -rf "$HOME/.config/clay-plugin/clay"
  mcp_json="$HOME/.cursor/mcp.json"
  if [ -f "$mcp_json" ]; then
    if command -v jq >/dev/null 2>&1; then
      tmp="$(mktemp)"
      if jq 'del(.mcpServers.clay)' "$mcp_json" > "$tmp"; then
        mv "$tmp" "$mcp_json"
      else
        rm -f "$tmp"
      fi
    else
      python3 - "$mcp_json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
config.get("mcpServers", {}).pop("clay", None)
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
    fi
  fi
  ```

- Landed on path 4 (Option A) because `userLocal=false`? Remove any dead local-sideload copy so
  Cursor doesn't show a permanently-broken plugin entry:

  ```bash
  rm -rf "$HOME/.cursor/plugins/local/clay"
  ```

After applying a path, **fully quit Cursor (Cmd/Ctrl+Q) and reopen it** — a new chat or
"Reload Window" is frequently not enough to pick up a newly-added local plugin or a new
`mcp.json` entry, unlike the lighter session-refresh restart in `SKILL.md` step 4. Once done,
return to `SKILL.md` and continue with step 3.
