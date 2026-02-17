#!/bin/bash
# Claude Code Notifier
# https://github.com/codewithmustafa/claude-code-notifier
#
# Native macOS notifications for Claude Code events:
#   - Permission requests (PermissionRequest hook)
#   - Task completion / idle (Notification hook — idle_prompt)
#   - Questions to user (Notification hook — elicitation_dialog)
# See README.md for setup instructions.

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "Unknown"')

case "$EVENT" in
  PermissionRequest)
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Unknown"')
    TITLE="Claude Code"
    MESSAGE="Permission requested: $TOOL_NAME"
    SOUND="Pop"
    ;;
  Notification)
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
    case "$NOTIFICATION_TYPE" in
      idle_prompt)
        TITLE="Claude Code"
        MESSAGE="Task completed — waiting for your input"
        SOUND="Glass"
        ;;
      elicitation_dialog)
        TITLE="Claude Code"
        MESSAGE="Claude has a question for you"
        SOUND="Ping"
        ;;
      *)
        TITLE="Claude Code"
        MESSAGE=$(echo "$INPUT" | jq -r '.message // "Notification"')
        SOUND="Ping"
        ;;
    esac
    ;;
  *)
    TITLE="Claude Code"
    MESSAGE="Notification from Claude Code"
    SOUND="Ping"
    ;;
esac

/opt/homebrew/bin/terminal-notifier \
  -title "$TITLE" \
  -message "$MESSAGE" \
  -sound "$SOUND" \
  -ignoreDnD

exit 0
