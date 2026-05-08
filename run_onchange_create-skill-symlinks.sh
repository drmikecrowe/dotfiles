#!/usr/bin/env bash
# Recreate ~/.claude/commands/skills/ symlinks pointing to ~/.agents/skills/*/SKILL.md
# Runs whenever ~/.agents/skills/ contents change (chezmoi onchange).
set -euo pipefail

SKILLS_DIR="$HOME/.agents/skills"
CMDS_DIR="$HOME/.claude/commands/skills"

mkdir -p "$CMDS_DIR"

# Remove stale symlinks (skills removed from ~/.agents/skills)
for link in "$CMDS_DIR"/*.md; do
    [[ -L "$link" ]] || continue
    target=$(readlink "$link")
    [[ -e "$target" ]] || rm -f "$link"
done

# Create/update symlinks for all current skills
for skill_dir in "$SKILLS_DIR"/*/; do
    name=$(basename "$skill_dir")
    src="$skill_dir/SKILL.md"
    dst="$CMDS_DIR/$name.md"
    [[ -f "$src" ]] || continue
    ln -sf "$src" "$dst"
done

echo "skill symlinks updated: $CMDS_DIR"
