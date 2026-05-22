#!/usr/bin/env bash
#
# migrate-to-documentation.sh — one-time migration of project artifacts from
# a code repo to its documentation sister repo.
#
# Usage:
#   bash /path/to/it-dev-methodology/scripts/migrate-to-documentation.sh \
#        <source-code-repo> <doc-repo>
#
# What it does:
#   1. Scans known project-artifact paths in <source-code-repo>.
#   2. Previews what will be copied to <doc-repo> and deleted from <source>.
#   3. On confirmation: copies files preserving directory structure.
#   4. On second confirmation: deletes originals from <source-code-repo>.
#
# Artifact taxonomy (what migrates vs what stays):
#   MIGRATE (to doc repo):  DEVLOG.md, PRODUCT*.md, VISION*.md, IDEAS.md,
#                           ROADMAP.md, HYPOTHESES.md, RISKS.md,
#                           OPEN-QUESTIONS.md, AGENT-GAPS.md, BEHAVIOR.md,
#                           docs/product/, docs/adr/, docs/vision/,
#                           docs/architecture/, docs/sync-vision-reports/,
#                           docs/data-map.md, docs/glossary.md, docs/BEHAVIOR.md,
#                           inbox/, services-registry.yaml
#   STAY in code repo:      CLAUDE.md, CLAUDE.local.md, CLAUDE_LONG.md,
#                           .claude/, rules/, README.md, VERSION, scripts/, etc.
#   SKIP (ask for both):    any path present in both repos (conflict)
#
# NOTE: Does not touch .claude/ (state restored by new-project-init.sh + sync).
#       CLAUDE.local.md stays in code repo (workspace-specific config).
#       Run new-project-init.sh + sync-methodology.sh in doc repo beforehand
#       to bootstrap its .claude/.

set -euo pipefail

SOURCE_DIR="${1:?Usage: $0 <source-code-repo> <doc-repo>}"
DOC_DIR="${2:?Usage: $0 <source-code-repo> <doc-repo>}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source repo not found: $SOURCE_DIR"
  exit 1
fi
if [[ ! -d "$DOC_DIR" ]]; then
  echo "ERROR: Documentation repo not found: $DOC_DIR"
  exit 1
fi

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
DOC_DIR="$(cd "$DOC_DIR" && pwd)"

if [[ "$SOURCE_DIR" == "$DOC_DIR" ]]; then
  echo "ERROR: Source and documentation repo are the same directory."
  exit 1
fi

echo "Source:  $SOURCE_DIR"
echo "Target:  $DOC_DIR"
echo ""

# ---------------------------------------------------------------------------
# Known artifact paths to migrate.
# Mirrors the PRESERVE list from sync-methodology.sh, minus files that belong
# in the code workspace (CLAUDE.md, CLAUDE.local.md, CLAUDE_LONG.md, rules/).
# ---------------------------------------------------------------------------
ARTIFACT_ENTRIES=(
  "DEVLOG.md"
  "PRODUCT.md"
  "PRODUCT_LONG.md"
  "VISION.md"
  "VISION_LONG.md"
  "IDEAS.md"
  "ROADMAP.md"
  "HYPOTHESES.md"
  "RISKS.md"
  "OPEN-QUESTIONS.md"
  "AGENT-GAPS.md"
  "BEHAVIOR.md"
  "services-registry.yaml"
  "docs/product"
  "docs/adr"
  "docs/vision"
  "docs/architecture"
  "docs/sync-vision-reports"
  "docs/data-map.md"
  "docs/glossary.md"
  "docs/BEHAVIOR.md"
  "docs/threat-model.template.md"
  "inbox"
)

# ---------------------------------------------------------------------------
# Scan: expand directories to individual files, detect conflicts.
# ---------------------------------------------------------------------------
TO_COPY=()      # rel paths (files) to copy source→doc
CONFLICTS=()    # rel paths present in both repos
NOT_FOUND=()    # entries not present in source (nothing to do)

expand_entry() {
  local entry="$1"
  local src="$SOURCE_DIR/$entry"
  if [[ -f "$src" ]]; then
    echo "$entry"
  elif [[ -d "$src" ]]; then
    find "$src" -type f | while IFS= read -r f; do
      printf '%s\n' "${f#$SOURCE_DIR/}"
    done
  fi
}

for entry in "${ARTIFACT_ENTRIES[@]}"; do
  src_path="$SOURCE_DIR/$entry"
  if [[ ! -e "$src_path" ]]; then
    NOT_FOUND+=("$entry")
    continue
  fi

  # Expand directory → individual files
  files=()
  if [[ -f "$src_path" ]]; then
    files=("$entry")
  elif [[ -d "$src_path" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done < <(find "$src_path" -type f | sed "s|^$SOURCE_DIR/||")
  fi

  for rel in "${files[@]}"; do
    doc_path="$DOC_DIR/$rel"
    if [[ -f "$doc_path" ]]; then
      CONFLICTS+=("$rel")
    else
      TO_COPY+=("$rel")
    fi
  done
done

# ---------------------------------------------------------------------------
# Preview
# ---------------------------------------------------------------------------
echo "=== Migration preview ==================================="
echo ""

if [[ ${#TO_COPY[@]} -eq 0 && ${#CONFLICTS[@]} -eq 0 ]]; then
  echo "Nothing to migrate — no matching artifacts found in source repo."
  echo ""
  echo "Not found (will skip):"
  for e in "${NOT_FOUND[@]}"; do echo "  - $e"; done
  exit 0
fi

if [[ ${#TO_COPY[@]} -gt 0 ]]; then
  echo "Will COPY to doc repo (${#TO_COPY[@]} files):"
  for f in "${TO_COPY[@]}"; do echo "  + $f"; done
  echo ""
fi

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  echo "CONFLICTS — file exists in both repos (${#CONFLICTS[@]} files):"
  for f in "${CONFLICTS[@]}"; do echo "  ! $f"; done
  echo ""
  echo "Conflicts will be SKIPPED. Delete manually from source after resolving."
  echo ""
fi

if [[ ${#NOT_FOUND[@]} -gt 0 ]]; then
  echo "Not found in source (${#NOT_FOUND[@]} entries — will skip):"
  for e in "${NOT_FOUND[@]}"; do echo "  - $e"; done
  echo ""
fi

echo "========================================================="
echo ""

if [[ ${#TO_COPY[@]} -eq 0 ]]; then
  echo "Nothing to copy (all files conflict or not found). Exiting."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Confirm copy
# ---------------------------------------------------------------------------
printf "Step 1/2 — Copy %d files to doc repo? [y/N] " "${#TO_COPY[@]}"
read -r ans
ans_lower="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
if [[ "$ans_lower" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "→ Copying..."
COPIED=()
COPY_FAILED=()

for rel in "${TO_COPY[@]}"; do
  src="$SOURCE_DIR/$rel"
  dest="$DOC_DIR/$rel"
  dest_dir="$(dirname "$dest")"
  if mkdir -p "$dest_dir" && cp "$src" "$dest"; then
    COPIED+=("$rel")
    echo "  ✓ $rel"
  else
    COPY_FAILED+=("$rel")
    echo "  ✗ $rel (copy failed)"
  fi
done

echo ""
echo "Copied: ${#COPIED[@]} files."

if [[ ${#COPY_FAILED[@]} -gt 0 ]]; then
  echo "Failed: ${#COPY_FAILED[@]} files — these will NOT be deleted from source."
  echo "Fix the errors above and re-run the script."
  echo ""
fi

if [[ ${#COPIED[@]} -eq 0 ]]; then
  echo "Nothing was copied successfully. Exiting without deleting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Confirm delete from source
# ---------------------------------------------------------------------------
echo "========================================================="
echo ""
echo "Will DELETE from source repo (${#COPIED[@]} files):"
for f in "${COPIED[@]}"; do echo "  - $f"; done
echo ""

printf "Step 2/2 — Delete originals from source repo? [y/N] "
read -r ans2
ans2_lower="$(printf '%s' "$ans2" | tr '[:upper:]' '[:lower:]')"
if [[ "$ans2_lower" != "y" ]]; then
  echo "Skipped deletion. Files were copied but originals remain in source."
  echo "Delete manually or re-run and confirm deletion."
  exit 0
fi

echo ""
echo "→ Deleting originals..."
DELETED=()
DELETE_FAILED=()

for rel in "${COPIED[@]}"; do
  src="$SOURCE_DIR/$rel"
  if rm -f "$src"; then
    DELETED+=("$rel")
    echo "  ✓ $rel"
  else
    DELETE_FAILED+=("$rel")
    echo "  ✗ $rel (delete failed)"
  fi
done

# Remove empty parent directories created by the artifacts.
for rel in "${COPIED[@]}"; do
  dir="$(dirname "$SOURCE_DIR/$rel")"
  while [[ "$dir" != "$SOURCE_DIR" ]]; do
    if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
      rmdir "$dir" 2>/dev/null || true
    fi
    dir="$(dirname "$dir")"
  done
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Done ================================================="
echo "  Copied:  ${#COPIED[@]} files → doc repo"
echo "  Deleted: ${#DELETED[@]} files ← source repo"
[[ ${#COPY_FAILED[@]} -gt 0 ]] && echo "  Copy failed: ${#COPY_FAILED[@]}"
[[ ${#DELETE_FAILED[@]} -gt 0 ]] && echo "  Delete failed: ${#DELETE_FAILED[@]}"
[[ ${#CONFLICTS[@]} -gt 0 ]] && echo "  Conflicts skipped: ${#CONFLICTS[@]}"
echo "========================================================="
echo ""
echo "Next steps:"
echo "  1. Review doc repo: git -C \"$DOC_DIR\" status"
echo "  2. Commit migrated artifacts: git -C \"$DOC_DIR\" add -A && git commit -m 'chore: migrate artifacts from code repo'"
echo "  3. Update source .gitignore to exclude migrated paths (if not already)."
echo "  4. In source repo: git add -A && git commit -m 'chore: remove migrated artifacts (now in doc repo)'"
