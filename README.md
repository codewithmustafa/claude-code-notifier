# Claude Code Notifier

Never miss a Claude Code prompt again. Get native macOS notifications with sound when Claude Code asks for permission, completes a task, or has a question — even when you're working in another window or app.

![macOS](https://img.shields.io/badge/macOS-supported-brightgreen)
![Claude Code](https://img.shields.io/badge/Claude%20Code-hooks-blue)
![License](https://img.shields.io/badge/license-MIT-yellow)

## The Problem

When using [Claude Code](https://docs.anthropic.com/en/docs/claude-code), it sometimes needs your permission to run commands, finishes a long task while you're away, or asks you a question. If you're working across multiple windows, projects, or monitors, you can easily miss these prompts — leaving Claude waiting and breaking your flow.

## The Solution

A lightweight hook that sends **native macOS notifications** for key Claude Code events. Click the notification to jump straight back to your editor.

**Features:**
- **Permission requests** — notified when Claude needs approval for Bash, Edit, Write, etc.
- **Task completion** — notified when Claude finishes working and waits for your input
- **Questions** — notified when Claude asks you a question
- Native macOS notification with distinct sounds per event type
- Click-to-focus: tapping the notification activates your editor
- Works even in Do Not Disturb mode
- Global setup — works across all your projects
- Minimal dependencies — just `terminal-notifier` and `jq`

## Prerequisites

- **macOS** (uses Notification Center)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** installed
- **[terminal-notifier](https://github.com/julienXX/terminal-notifier)** — a CLI tool for macOS notifications
- **[jq](https://jqlang.github.io/jq/)** — for parsing JSON input from the hook

## Installation

### Quick Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/codewithmustafa/claude-code-notifier/master/install.sh | bash
```

### Manual Install

#### 1. Install dependencies

```bash
brew install terminal-notifier jq
```

#### 2. Create the notification script

```bash
mkdir -p ~/.claude/hooks

cat > ~/.claude/hooks/permission-notification.sh << 'EOF'
#!/bin/bash
# Claude Code Notifier
# https://github.com/codewithmustafa/claude-code-notifier

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "Unknown"')

case "$EVENT" in
  PermissionRequest)
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Unknown"')
    TITLE="Claude Code"
    MESSAGE="Permission requested: $TOOL_NAME"
    SOUND="Ping"
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
EOF

chmod +x ~/.claude/hooks/permission-notification.sh
```

#### 3. Add the hooks to Claude Code settings

Open `~/.claude/settings.json` and add the `hooks` section:

```json
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
```

> If you already have content in `settings.json`, merge the `hooks` key into your existing config.

#### 4. Test it

```bash
# Permission request notification
echo '{"hook_event_name": "PermissionRequest", "tool_name": "Bash"}' | bash ~/.claude/hooks/permission-notification.sh

# Task completed notification
echo '{"hook_event_name": "Notification", "notification_type": "idle_prompt"}' | bash ~/.claude/hooks/permission-notification.sh

# Question notification
echo '{"hook_event_name": "Notification", "notification_type": "elicitation_dialog"}' | bash ~/.claude/hooks/permission-notification.sh
```

## Notification Types

| Event | When | Notification | Sound |
|-------|------|-------------|-------|
| Permission request | Claude needs approval for a tool | "Permission requested: Bash" | Ping |
| Task completed | Claude finishes and waits for input | "Task completed — waiting for your input" | Glass |
| Question | Claude asks you a question | "Claude has a question for you" | Ping |

## Click-to-Focus (Optional)

You can make the notification activate your editor when clicked. Add the `-activate` flag with your editor's bundle ID:

```bash
/opt/homebrew/bin/terminal-notifier \
  -title "$TITLE" \
  -message "$MESSAGE" \
  -sound "$SOUND" \
  -ignoreDnD \
  -activate <BUNDLE_ID>
```

### Common Editor Bundle IDs

| Editor | Bundle ID |
|--------|-----------|
| **Cursor** | `com.todesktop.230313mzl4w4u92` |
| **VS Code** | `com.microsoft.VSCode` |
| **iTerm2** | `com.googlecode.iterm2` |
| **Terminal.app** | `com.apple.Terminal` |
| **Warp** | `dev.warp.Warp-Stable` |
| **Alacritty** | `org.alacritty` |
| **Kitty** | `net.kovidgoyal.kitty` |
| **Hyper** | `co.zeit.hyper` |
| **WezTerm** | `com.github.wez.wezterm` |
| **Windsurf** | `com.exafunction.windsurf` |

> **Find your editor's bundle ID:**
> ```bash
> osascript -e 'id of app "Your App Name"'
> ```

## Customization

### Change notification sound

Replace `Ping` or `Glass` with any macOS system sound:

```
Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
```

### Filter by tool type

Instead of matching all permission requests (`"*"`), you can target specific tools:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Bash",
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
```

### Show the command in notification

For more detailed notifications showing what Claude wants to run:

```bash
#!/bin/bash
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.file_path // "operation"')

# Truncate long commands
if [ ${#TOOL_INPUT} -gt 80 ]; then
  TOOL_INPUT="${TOOL_INPUT:0:77}..."
fi

/opt/homebrew/bin/terminal-notifier \
  -title "Claude Code: $TOOL_NAME" \
  -message "$TOOL_INPUT" \
  -sound Ping \
  -ignoreDnD

exit 0
```

## Why terminal-notifier?

macOS restricts `display notification` (osascript) to the parent app's notification permissions. Most terminal emulators have notifications disabled by default, so `osascript` notifications silently fail. `terminal-notifier` is a standalone app with its own notification permission, making it reliable regardless of your terminal setup.

## Troubleshooting

### No notification appears

1. **Check terminal-notifier is installed:**
   ```bash
   which terminal-notifier
   ```
   If not found, run `brew install terminal-notifier`.

2. **Check notification permissions:**
   Go to **System Settings > Notifications > terminal-notifier** and make sure notifications are enabled.

3. **Test the script directly:**
   ```bash
   echo '{"hook_event_name": "PermissionRequest", "tool_name": "Test"}' | bash ~/.claude/hooks/permission-notification.sh
   ```

4. **Check terminal-notifier path:**
   The script assumes `/opt/homebrew/bin/terminal-notifier` (Apple Silicon). For Intel Macs, the path is `/usr/local/bin/terminal-notifier`. Update the script accordingly.

### Notification appears but no sound

- Check that your Mac's volume is not muted.
- Verify the sound name is valid (see [Customization](#change-notification-sound)).
- Check **System Settings > Notifications > terminal-notifier** and ensure "Play sound for notifications" is on.

### Click-to-focus not working

- Verify the bundle ID is correct:
  ```bash
  osascript -e 'id of app "Cursor"'
  ```
- Some apps may require the notification to be clicked within a few seconds.

## How It Works

Claude Code supports [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell commands that run in response to specific events. This tool uses two hooks:

- **`PermissionRequest`** fires whenever Claude Code shows a permission dialog
- **`Notification`** fires when Claude Code needs your attention (task done, question asked)

Both hooks call the same script, which reads the JSON input, determines the event type, and sends an appropriate macOS notification via `terminal-notifier`.

```
Claude Code event fires
        ↓
PermissionRequest or Notification hook
        ↓
permission-notification.sh reads JSON
        ↓
Determines event type & builds message
        ↓
terminal-notifier sends macOS notification
        ↓
You click → editor activates
```

## License

MIT
