---
name: clay-feedback
description: Clay feedback — send a bug report or product feedback to the Clay team via the `clay feedback` CLI.
allowed-tools: Bash(clay *), Bash(rm *), Write, AskUserQuestion
---

# Clay Feedback

Send feedback or a bug report to the Clay team using `clay feedback`. It reads the message from **stdin** and automatically attaches environment details.

The CLI does no confirmation of its own, so confirm with the user before sending.

## Steps

1. **Determine type.** Default to `feedback`. Choose `bug` **only** when something that previously worked (or is established existing behavior) has **regressed** — it used to work and now doesn't. Choose `feedback` for everything else: missing behavior, feature requests, UX suggestions, confusing flows, "I expected X but Clay doesn't do that," errors that look like product gaps rather than regressions, and general product ideas. Missing behavior is feedback (closer to a feature request), not a bug. If unclear whether this is a regression, prefer `feedback`; only ask the user when they clearly mean either a regression or a request for new/missing behavior and you still can't tell which.

2. **Get feedback text.** Use the argument if provided (e.g. `/clay-feedback would love CSV export from the enrichment table`). Otherwise ask the user what feedback or bug report they'd like to send.

3. **Confirm.** Use your ask-user tool (`AskUserQuestion`; `askUser` inside the Clay app). List what the report will include, and offer "Send" / "Cancel":

   > This report will include:
   >
   > - Type: {bug or feedback}
   > - Your feedback: {feedback text}
   > - Environment info (auto-collected)
   >
   > Send this feedback?

4. **If confirmed**, send the message on stdin. The CLI reads the feedback from stdin. Do **not** pass it inline in the shell command (no heredoc, no `echo`): the feedback is arbitrary user text, and a here-doc delimiter or quote appearing in it would truncate or mis-parse the message — or let pasted text run as shell. Instead, write the text to a temp file with your file-writing tool (which never goes through the shell), then redirect that file into the command. Always pass `--type bug` or `--type feedback` from step 1.
   - Write the feedback text verbatim to a temp file, e.g. `/tmp/clay-feedback.txt`.
   - Then run:

   ```bash
   clay feedback --type <bug|feedback> < /tmp/clay-feedback.txt
   rm -f /tmp/clay-feedback.txt
   ```
