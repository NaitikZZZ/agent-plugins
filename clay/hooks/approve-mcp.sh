#!/bin/sh
# Shared approval hook for the Clay plugin: auto-approve tool calls to Clay's own
# MCP server (the stdio `clay mcp` server)
# The verdict shape differs per agent, selected by the first argument:
# claude | cursor | codex.
#
#   claude -> PreToolUse         (input .tool_name == "mcp__clay__<tool>")
#   codex  -> PermissionRequest  (input .tool_name == "mcp__clay__<tool>")
#   cursor -> beforeMCPExecution (input .tool_name + .command / .url per server)
# Anything that isn't Clay's MCP server falls through to the normal prompt (exit 0, no
# output).

agent="${1:-claude}"

# Harden: no globbing, and unset variables are errors so a typo can't silently
# widen approval.
set -fu

# Fail open to the normal prompt if we lack jq to parse the event.
command -v jq > /dev/null 2>&1 || exit 0

input="$(cat)"

approve=0

case "$agent" in
  cursor)
    # Cursor's beforeMCPExecution fires for EVERY MCP server, so we must scope to
    # Clay's server ourselves. Cursor's event carries no configured-server-name
    # field (only tool_name/tool_input plus, for stdio servers, the launch
    # `command`), so that command string is the only anchor we have. Our server
    # always runs the `clay` binary with the `mcp` subcommand (`clay mcp`),
    # however the path is written. Matching the binary basename ALONE is too
    # broad: any *other* server launched through a clay-named binary (e.g. a
    # repo-local `./clay` running some other subcommand) would be approved. So
    # require both the `clay` basename AND the `mcp` subcommand -- the closest we
    # can pin to our own server from the command string alone.
    cmd="$(printf '%s' "$input" | jq -r '.command // empty' 2> /dev/null)"
    # noglob (set -f) is active, so word-splitting the command can't glob.
    # shellcheck disable=SC2086
    set -- $cmd
    bin="${1:-}"       # first whitespace-delimited token (the binary, any path)
    bin="${bin##*/}"   # strip any directory, leaving the binary name
    sub="${2:-}"       # the subcommand; our server always runs `mcp`
    [ "$bin" = "clay" ] && [ "$sub" = "mcp" ] && approve=1
    ;;
  codex)
    # Codex PermissionRequest exposes MCP tools as `mcp__clay__<tool>`.
    tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2> /dev/null)"
    case "$tool" in
      mcp__clay__*) approve=1 ;;
    esac
    ;;
  claude | *)
    # Claude PreToolUse namespaces plugin-bundled MCP servers as `mcp__plugin_clay_clay__<tool>`
    tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2> /dev/null)"
    case "$tool" in
      mcp__plugin_clay_clay__*) approve=1 ;;
    esac
    ;;
esac

[ "$approve" -eq 1 ] || exit 0

case "$agent" in
  cursor)
    printf '%s\n' '{"continue":true,"permission":"allow"}'
    ;;
  codex)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    ;;
  claude | *)
    # claude (PreToolUse) is the default; an unknown agent also lands here, which
    # is safe because we only ever emit an allow after passing the checks above.
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Clay MCP server tools are allowlisted by the Clay plugin"}}'
    ;;
esac
