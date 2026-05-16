#!/usr/bin/env bash
# new-project-init.sh
# Bootstrap a new project with methodology artifacts.
# Usage: ./new-project-init.sh <project-name> [target-dir]

set -euo pipefail

PROJECT_NAME="${1:?Usage: $0 <project-name> [target-dir]}"
TARGET_DIR="${2:-.}"
METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$METHODOLOGY_DIR/templates"

echo "Initializing project: $PROJECT_NAME"
echo "Target directory: $TARGET_DIR"

mkdir -p "$TARGET_DIR"

copy_template() {
  local template="$1"
  local dest="$2"
  if [[ -f "$TARGET_DIR/$dest" ]]; then
    echo "  SKIP  $dest (already exists)"
  else
    sed "s/{{Project Name}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/$template" > "$TARGET_DIR/$dest"
    echo "  CREATE $dest"
  fi
}

copy_template "PRODUCT.template.md"    "PRODUCT.md"
copy_template "VISION.template.md"     "VISION.md"
copy_template "SYSTEM-MAP.template.md" "SYSTEM-MAP.md"
copy_template "CLAUDE.template.md"     "CLAUDE.md"

if [[ ! -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" init
  echo "  INIT  git repository"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Fill in PRODUCT.md — define the problem and goals"
echo "  2. Fill in SYSTEM-MAP.md — map your components"
echo "  3. Fill in CLAUDE.md — set conventions for AI-assisted development"
echo "  4. Run: /plan to start your first feature"
