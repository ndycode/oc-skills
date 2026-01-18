#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
CODEX_DIR="$HOME/.codex/skills"

echo "OC Skills Installer"
echo "==================="
echo ""

mkdir -p "$OPENCODE_DIR/skill"
mkdir -p "$OPENCODE_DIR/command"
mkdir -p "$CODEX_DIR"

echo "Installing OpenCode skills..."
if [ -d "$SCRIPT_DIR/skill" ]; then
    cp -r "$SCRIPT_DIR/skill/"* "$OPENCODE_DIR/skill/" 2>/dev/null || true
    SKILL_COUNT=$(find "$SCRIPT_DIR/skill" -maxdepth 1 -type d | wc -l)
    SKILL_COUNT=$((SKILL_COUNT - 1))
    echo "  Installed $SKILL_COUNT OpenCode skills"
else
    echo "  No OpenCode skills directory found"
fi

echo "Installing slash commands..."
if [ -d "$SCRIPT_DIR/command" ]; then
    cp -r "$SCRIPT_DIR/command/"* "$OPENCODE_DIR/command/" 2>/dev/null || true
    CMD_COUNT=$(find "$SCRIPT_DIR/command" -maxdepth 1 -type f -name "*.md" | wc -l)
    echo "  Installed $CMD_COUNT commands"
else
    echo "  No command directory found"
fi

echo "Installing Codex skills..."
if [ -d "$SCRIPT_DIR/codex-skill" ]; then
    cp -r "$SCRIPT_DIR/codex-skill/"* "$CODEX_DIR/" 2>/dev/null || true
    CODEX_COUNT=$(find "$SCRIPT_DIR/codex-skill" -maxdepth 1 -type d | wc -l)
    CODEX_COUNT=$((CODEX_COUNT - 1))
    echo "  Installed $CODEX_COUNT Codex skills"
else
    echo "  No Codex skills directory found"
fi

echo ""
echo "Installation complete!"
echo "OpenCode skills: $OPENCODE_DIR/skill"
echo "OpenCode commands: $OPENCODE_DIR/command"
echo "Codex skills: $CODEX_DIR"
echo ""
echo "Restart OpenCode/Codex to use the new skills."
