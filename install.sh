#!/bin/bash
set -e

# Claude Code Notifier - Installer
# https://github.com/codewithmustafa/claude-code-notifier

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "  Claude Code Notifier"
echo "  ====================="
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}Error: This tool only works on macOS.${NC}"
  exit 1
fi

# Check terminal-notifier
if ! command -v terminal-notifier &> /dev/null; then
  echo -e "${YELLOW}terminal-notifier not found. Installing via Homebrew...${NC}"
  if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: Homebrew is required. Install it from https://brew.sh${NC}"
    exit 1
  fi
  brew install terminal-notifier
fi

# Check jq
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}jq not found. Installing via Homebrew...${NC}"
  brew install jq
fi

# Detect terminal-notifier path
TN_PATH=$(which terminal-notifier)
echo -e "${GREEN}Found terminal-notifier at: $TN_PATH${NC}"

# Detect editor (optional click-to-focus)
ACTIVATE_FLAG=""
FRONTMOST=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || echo "")

if [ -n "$FRONTMOST" ]; then
  FRONTMOST_NAME=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "your editor")
  echo ""
  echo -e "Detected active app: ${GREEN}$FRONTMOST_NAME${NC} ($FRONTMOST)"
  read -p "Enable click-to-focus for $FRONTMOST_NAME? [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ACTIVATE_FLAG="\n  -activate $FRONTMOST"
  fi
fi

# Create hook script
mkdir -p ~/.claude/hooks

cat > ~/.claude/hooks/permission-notification.sh << SCRIPT
#!/bin/bash
# Claude Code Notifier
# https://github.com/codewithmustafa/claude-code-notifier

INPUT=\$(cat)
EVENT=\$(echo "\$INPUT" | jq -r '.hook_event_name // "Unknown"')

case "\$EVENT" in
  PermissionRequest)
    TOOL_NAME=\$(echo "\$INPUT" | jq -r '.tool_name // "Unknown"')
    TITLE="Claude Code"
    MESSAGE="Permission requested: \$TOOL_NAME"
    SOUND="Ping"
    ;;
  Notification)
    NOTIFICATION_TYPE=\$(echo "\$INPUT" | jq -r '.notification_type // "unknown"')
    case "\$NOTIFICATION_TYPE" in
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
        MESSAGE=\$(echo "\$INPUT" | jq -r '.message // "Notification"')
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

${TN_PATH} \\
  -title "\$TITLE" \\
  -message "\$MESSAGE" \\
  -sound "\$SOUND" \\
  -ignoreDnD$(echo -e "$ACTIVATE_FLAG")

exit 0
SCRIPT

chmod +x ~/.claude/hooks/permission-notification.sh
echo -e "${GREEN}Created ~/.claude/hooks/permission-notification.sh${NC}"

# Update settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"

HOOK_CMD="bash ~/.claude/hooks/permission-notification.sh"

if [ -f "$SETTINGS_FILE" ]; then
  # Check if hooks already configured
  HAS_PERMISSION=$(jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" 2>/dev/null && echo "yes" || echo "no")
  HAS_NOTIFICATION=$(jq -e '.hooks.Notification' "$SETTINGS_FILE" 2>/dev/null && echo "yes" || echo "no")

  if [ "$HAS_PERMISSION" = "yes" ] && [ "$HAS_NOTIFICATION" = "yes" ]; then
    echo -e "${YELLOW}Hooks already configured in settings.json. Skipping.${NC}"
  else
    # Merge hooks into existing settings (preserves other hooks)
    jq --arg cmd "$HOOK_CMD" '
      .hooks = (.hooks // {}) +
      {"PermissionRequest": [{"matcher": "*", "hooks": [{"type": "command", "command": $cmd}]}]} +
      {"Notification": [{"matcher": "idle_prompt|elicitation_dialog", "hooks": [{"type": "command", "command": $cmd}]}]}
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo -e "${GREEN}Updated ~/.claude/settings.json with hooks.${NC}"
  fi
else
  # Create new settings file
  mkdir -p ~/.claude
  cat > "$SETTINGS_FILE" << 'JSON'
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/permission-notification.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "idle_prompt|elicitation_dialog",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/permission-notification.sh"
          }
        ]
      }
    ]
  }
}
JSON
  echo -e "${GREEN}Created ~/.claude/settings.json with hooks.${NC}"
fi

# Test
echo ""
echo "Sending test notifications..."
echo ""
echo "  1/2 Permission request notification..."
echo '{"hook_event_name": "PermissionRequest", "tool_name": "Bash"}' | bash ~/.claude/hooks/permission-notification.sh
sleep 1
echo "  2/2 Task completed notification..."
echo '{"hook_event_name": "Notification", "notification_type": "idle_prompt"}' | bash ~/.claude/hooks/permission-notification.sh

echo ""
echo -e "${GREEN}Setup complete!${NC} You'll now receive notifications when Claude Code:"
echo "  - Requests permission (e.g. Bash, Edit, Write)"
echo "  - Completes a task and waits for your input"
echo "  - Asks you a question"
echo ""
