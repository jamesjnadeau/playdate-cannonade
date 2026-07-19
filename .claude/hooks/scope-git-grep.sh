#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). settings.local.json auto-allows
# `Bash(git *)` and `Bash(grep *)`, but Bash permission rules can't be
# cwd-scoped on their own (only Read/Edit support path-glob scoping) -- this
# hook is the enforcement layer that downgrades those two rules back to a
# prompt when the command's cwd is outside this repo, so the blanket allow
# only actually applies inside it.
set -euo pipefail

REPO="$CLAUDE_PROJECT_DIR"

jq -c --arg repo "$REPO" '
	(.tool_input.command // "") as $c
	| (.cwd // "") as $d
	| ($c | test("^(git|grep|egrep|fgrep)([ \t]|$)")) as $isTarget
	| (($d == $repo) or ($d | startswith($repo + "/"))) as $inRepo
	| if $isTarget and ($inRepo | not) then
		{hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "ask",
			permissionDecisionReason: ("git/grep auto-allow only applies inside " + $repo + " (cwd: " + $d + ")")
		}}
	else empty end
'