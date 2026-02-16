# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Notifier is a macOS-only shell utility that sends native macOS notifications for Claude Code events. It uses two hooks:

- **`PermissionRequest`** — notifies when Claude Code requests permission to use a tool (Bash, Edit, Write, etc.)
- **`Notification`** (`idle_prompt`, `elicitation_dialog`) — notifies when Claude completes a task and waits for input, or asks the user a question

It uses `terminal-notifier` for reliable notifications that work regardless of terminal app notification settings.

## Architecture

Two shell scripts, no build system:

- **`install.sh`** — Interactive installer that detects dependencies (`terminal-notifier`, `jq`), auto-installs them via Homebrew, detects the frontmost app for click-to-focus, generates the hook script at `~/.claude/hooks/permission-notification.sh`, and merges both hook configs into `~/.claude/settings.json`.

- **`permission-notification.sh`** — The hook script template (also serves as a reference). Reads JSON from stdin, determines the event type via `hook_event_name`, and fires an appropriate notification via `terminal-notifier`. The installer generates a customized version of this at `~/.claude/hooks/`.

## Flow

```
Claude Code event → Hook fires → permission-notification.sh reads JSON from stdin → jq extracts event type & details → terminal-notifier sends macOS notification
```

### Supported Events

| Hook | Matcher | Notification |
|---|---|---|
| `PermissionRequest` | `*` | "Permission requested: {tool_name}" (sound: Ping) |
| `Notification` | `idle_prompt` | "Task completed — waiting for your input" (sound: Glass) |
| `Notification` | `elicitation_dialog` | "Claude has a question for you" (sound: Ping) |

## Key Details

- **macOS only** — depends on Notification Center, `osascript`, and `terminal-notifier`
- **terminal-notifier path** — Apple Silicon: `/opt/homebrew/bin/terminal-notifier`, Intel: `/usr/local/bin/terminal-notifier`. The installer detects this automatically.
- **Settings merge** — `install.sh` uses `jq` to non-destructively merge hooks into existing `~/.claude/settings.json` (preserves other settings/hooks)
- **Click-to-focus** — Optional `-activate <BUNDLE_ID>` flag on `terminal-notifier`. The installer detects the frontmost app and prompts the user.
- **Hook input format** — JSON on stdin with `hook_event_name` field to determine event type. `PermissionRequest` events include `tool_name`, `Notification` events include `notification_type` and `message`.
- Scripts must always `exit 0` to avoid blocking Claude Code

## Testing

No test framework. Manual testing:

```bash
# Test permission request notification
echo '{"hook_event_name": "PermissionRequest", "tool_name": "Bash"}' | bash permission-notification.sh

# Test task completed notification
echo '{"hook_event_name": "Notification", "notification_type": "idle_prompt"}' | bash permission-notification.sh

# Test question notification
echo '{"hook_event_name": "Notification", "notification_type": "elicitation_dialog"}' | bash permission-notification.sh
```

## Dependencies

All installed via Homebrew — no package manager files in the repo:
- `terminal-notifier` — standalone macOS notification app (bypasses terminal notification restrictions)
- `jq` — JSON parsing from stdin
