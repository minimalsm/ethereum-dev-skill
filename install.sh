#!/bin/bash

# Ethereum Dev Skill Installer
# Installs the skill to ~/.claude/skills/ (personal) or .claude/skills/ (project)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="ethereum-dev"

# Parse arguments
PROJECT_LEVEL=false
CUSTOM_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_LEVEL=true
            shift
            ;;
        --path)
            CUSTOM_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --project    Install to .claude/skills/ (project-level)"
            echo "  --path PATH  Install to custom path"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Determine installation path
if [[ -n "$CUSTOM_PATH" ]]; then
    INSTALL_DIR="$CUSTOM_PATH"
elif [[ "$PROJECT_LEVEL" == true ]]; then
    INSTALL_DIR=".claude/skills/$SKILL_NAME"
else
    INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME"
fi

echo "Installing Ethereum Dev Skill..."
echo "Target: $INSTALL_DIR"

# Create directory
mkdir -p "$INSTALL_DIR"

# Copy skill files
cp -r "$SCRIPT_DIR/skill/"* "$INSTALL_DIR/"

echo ""
echo "Installation complete!"
echo ""
echo "The skill is now available in Claude Code."
echo "Try asking: 'How do I set up viem to read from a contract?'"
