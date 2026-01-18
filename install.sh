#!/bin/bash
# OpenCode Skills Installer for macOS/Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

echo "OpenCode Skills Installer"
echo "========================="
echo ""

# Create config directories if they don't exist
mkdir -p "$CONFIG_DIR/skill"
mkdir -p "$CONFIG_DIR/command"

# Copy skills
echo "Installing skills..."
if [ -d "$SCRIPT_DIR/skill" ]; then
    cp -r "$SCRIPT_DIR/skill/"* "$CONFIG_DIR/skill/" 2>/dev/null || true
    SKILL_COUNT=$(find "$SCRIPT_DIR/skill" -maxdepth 1 -type d | wc -l)
    SKILL_COUNT=$((SKILL_COUNT - 1))
    echo "  Installed $SKILL_COUNT skills"
else
    echo "  No skills directory found"
fi

# Copy commands
echo "Installing slash commands..."
if [ -d "$SCRIPT_DIR/command" ]; then
    cp -r "$SCRIPT_DIR/command/"* "$CONFIG_DIR/command/" 2>/dev/null || true
    CMD_COUNT=$(find "$SCRIPT_DIR/command" -maxdepth 1 -type f -name "*.md" | wc -l)
    echo "  Installed $CMD_COUNT commands"
else
    echo "  No command directory found"
fi

echo ""
echo "Installation complete!"
echo "Skills installed to: $CONFIG_DIR/skill"
echo "Commands installed to: $CONFIG_DIR/command"
echo ""
echo "Restart OpenCode to use the new skills."
