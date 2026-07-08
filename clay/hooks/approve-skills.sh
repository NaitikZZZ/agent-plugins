#!/bin/sh
# Approval hook for the Clay plugin, wired only for Claude Code. Companion to
# approve-clay.sh (which auto-approves the `clay` CLI). This one auto-approves
# invoking Clay's own plugin skills plus the read-only WebFetch/WebSearch tools,
# so the agent stops asking on every call.
#
#   claude -> PreToolUse  (input .tool_name, .tool_input.skill)
#
# Wire it with the hook `matcher` set to "Skill|WebFetch|WebSearch"; the script
# then dispatches on tool_name.
#
# Cursor and Codex are deliberately omitted -- neither exposes a permission
# event this hook can attach to. Neither has a skill-
# invocation or WebFetch/WebSearch permission event, so there is no prompt to
# skip and nothing to auto-approve. (approve-cli.sh still wires both, because
# their `clay` CLI calls run through Cursor's beforeShellExecution and Codex's
# PermissionRequest/Bash surfaces.)

# Anything that isn't recognized falls through to the normal prompt (exit 0, no output).

# Tools other than clay skills that are approved unconditionally
allowed_tools="WebFetch WebSearch"

# Harden: no globbing, and unset variables are errors so a typo can't silently
# widen approval.
set -fu

# Fail open to the normal prompt if we lack jq to parse the event.
command -v jq > /dev/null 2>&1 || exit 0

input="$(cat)"

# Claude's PreToolUse event exposes the tool name at .tool_name; anything else
# comes back empty and falls through below.
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2> /dev/null)"
[ -n "$tool" ] || exit 0

approve=0

# Read-only web tools: allow by tool name (exact membership, so a token like
# `*` can't wildcard its way in).
case " $allowed_tools " in
  *" $tool "*) approve=1 ;;
esac

# The Skill tool carries the skill being invoked at .tool_input.skill. Only
# Clay's own skills are approved; any other skill falls through to the prompt.
if [ "$approve" -eq 0 ] && [ "$tool" = "Skill" ]; then
  skill="$(printf '%s' "$input" | jq -r '.tool_input.skill // empty' 2> /dev/null)"
  # Strip an optional "clay:" plugin-namespace prefix (a plugin skill may arrive
  # as either `clay:cli` or `cli`), then require a bare skill identifier. The
  # charset guard rejects anything with `/`, `.`, or `~`, so a crafted name
  # can't traverse out of the skills directory in the lookup below.
  skill="${skill#clay:}"
  case "$skill" in
    '' | *[!A-Za-z0-9_-]*) skill="" ;;
  esac
  if [ -n "$skill" ]; then
    # Prefer the plugin root the harness exports; fall back to this script's
    # location (hooks/ lives directly under the plugin root).
    plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
    [ -n "$plugin_root" ] || plugin_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
    # Authoritative allowlist: the plugin's own skills. Each skill's `name:`
    # frontmatter equals its directory name, so a directory match is exactly a
    # real Clay skill -- and it never drifts as skills are added or removed.
    [ -f "$plugin_root/skills/$skill/SKILL.md" ] && approve=1
  fi
fi

[ "$approve" -eq 1 ] || exit 0

# Emit Claude's PreToolUse allow verdict. Only reached after the checks above
# pass, so we never allow anything we haven't vetted.
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Clay skills and read-only web tools are allowlisted by the Clay plugin"}}'
