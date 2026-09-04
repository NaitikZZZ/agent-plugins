---
name: clay-feedback
description: Clay feedback — send a bug report or product feedback to the Clay team via the `clay feedback` CLI, optionally including this session's transcript.
allowed-tools: Bash(clay *), Bash(ls *), Bash(pwd), Bash(sed *), Bash(head *), Bash(rm *), Write, AskUserQuestion
---

# Clay Feedback

Send feedback or a bug report to the Clay team using `clay feedback`. It reads the message from **stdin** and automatically attaches environment details. To include this conversation's transcript, you attach it explicitly with `--transcript-file` — the CLI does not look for it on its own.

The transcript is the **current conversation**, so confirm with the user before sending (the CLI does no confirmation of its own).

## Steps

1. **Determine type.** Default to `feedback`. Choose `bug` **only** when something that previously worked (or is established existing behavior) has **regressed** — it used to work and now doesn't. Choose `feedback` for everything else: missing behavior, feature requests, UX suggestions, confusing flows, "I expected X but Clay doesn't do that," errors that look like product gaps rather than regressions, and general product ideas. Missing behavior is feedback (closer to a feature request), not a bug. If unclear whether this is a regression, prefer `feedback`; only ask the user when they clearly mean either a regression or a request for new/missing behavior and you still can't tell which.

2. **Get feedback text.** Use the argument if provided (e.g. `/clay-feedback would love CSV export from the enrichment table`). Otherwise ask the user what feedback or bug report they'd like to send.

3. **Find this session's transcript — you attach it, the CLI won't.** You are responsible for locating the current conversation's transcript file and passing its path to `--transcript-file` in step 5. Use whatever your runtime exposes:
   - **Claude Code:** the newest `.jsonl` under the project dir whose name is the working directory with `/` and `.` replaced by `-` (checking the normal home and the Cowork mount):

     ```bash
     proj="$(pwd | sed 's#[/.]#-#g')"
     ls -t "$HOME"/.claude/projects/"$proj"/*.jsonl "$HOME"/mnt/.claude/projects/"$proj"/*.jsonl 2>/dev/null | head -1
     ```

   - **Other runtimes (Codex, Cursor, …):** locate the current session transcript the way your client stores it.

   If you can't determine a transcript path, proceed without one — the report still sends.

4. **Confirm.** Use your ask-user tool (`AskUserQuestion`; `askUser` inside the Clay app). List what the report will include:

   > This report will include:
   >
   > - Type: {bug or feedback}
   > - Your feedback: {feedback text}
   > - This conversation's transcript _(only if step 3 found one)_
   > - Environment info (auto-collected)
   >
   > Send this feedback?
   - If step 3 found a transcript, offer "Send with transcript" / "Send without transcript" / "Cancel". The transcript is the full conversation, so let the user opt out (e.g. privacy-sensitive) by sending without it.
   - If step 3 found none, drop the transcript line and offer just "Send" / "Cancel".

5. **If confirmed**, send the message on stdin. The CLI reads the feedback from stdin. Do **not** pass it inline in the shell command (no heredoc, no `echo`): the feedback is arbitrary user text, and a here-doc delimiter or quote appearing in it would truncate or mis-parse the message — or let pasted text run as shell. Instead, write the text to a temp file with your file-writing tool (which never goes through the shell), then redirect that file into the command. Substitute the path from step 3 directly — each Bash call is a fresh shell, so a variable set in step 3 won't survive here. Always pass `--type bug` or `--type feedback` from step 1. Include `--transcript-file` only if the user chose to send the transcript:
   - Write the feedback text verbatim to a temp file, e.g. `/tmp/clay-feedback.txt`.
   - Then run:

   ```bash
   clay feedback --type <bug|feedback> --transcript-file <path from step 3> < /tmp/clay-feedback.txt
   rm -f /tmp/clay-feedback.txt
   ```

   To send without the transcript, omit `--transcript-file` entirely but still pass `--type`.

6. **Interpret the JSON output** (printed on success, exit 0):

   ```json
   { "ok": true, "includedTranscript": true, "environment": { ... } }
   ```

   `transcriptError` appears only when you passed `--transcript-file` but it couldn't be attached (missing, unreadable, or too large).
   - If `includedTranscript` is `false` and `transcriptError` is set, the report was **still sent** — only the transcript was skipped. Tell the user; double-check the path from step 3 before retrying.
   - `validation_error` (exit 2) — the stdin message was empty or nothing was piped. Make sure the temp file has the feedback text and is redirected in (`< /tmp/clay-feedback.txt`).
   - `auth_required` (exit 3) — Clay isn't authenticated. If the `setup` skill is available, run it (or `clay login`) and retry; inside the Clay app the session is managed for you, so report the expiry to the user instead.
   - `rate_limited` (exit 4) — too many reports recently; surface `details.retryAfter` and try again later.

7. Tell the user it was sent, noting whether the transcript was included. If cancelled, do nothing.
