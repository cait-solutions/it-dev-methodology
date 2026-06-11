#!/usr/bin/env bash
# validate-maps-coverage.sh — Level-4 maps coverage gate (PLAN-A v5.47.0)
#
# Checks that every command, local-only command, and skill is mentioned in the
# living maps (USER-MAP.md, ARTIFACT-MAP.md, SYSTEM-MAP.md).
#
# Configuration matrix — edit here, no logic changes needed:
USER_MAP_CHECK="commands skills"        # axes checked against USER-MAP
ARTIFACT_MAP_CHECK="commands"          # axes checked against ARTIFACT-MAP
SYSTEM_MAP_COMMANDS="gate"             # gate=ERROR on miss; warn=WARNING only
SYSTEM_MAP_SCRIPTS="warn"             # scripts only WARN in V1 (PLAN-B escalates)
#
# Why scripts=warn: /retro 2026-06-11 data covers commands only. Script coverage
# is large and partially internal — escalate after /retro evidence (PLAN-B).
# Why commands-local non-issue for consumers: commands-local/ is empty in consumers.
#
# Modes:
#   gate (default): missing on gate axes → exit 1 with list; maps absent = ERROR
#   --report:       all WARN/counts, exit 0; maps absent → WARN-SKIP (consumer ok)
#   --print-doc-root: print resolved doc root and exit (used by deploy-push.sh gate)
#
# Worktree-safe: resolves relative doc_repo_path from git-common-dir if needed.

set -e

MODE="gate"
PRINT_DOC_ROOT=0

for arg in "$@"; do
  case "$arg" in
    --report)        MODE="report" ;;
    --print-doc-root) PRINT_DOC_ROOT=1 ;;
    --doc-root=*)    DOC_ROOT_ARG="${arg#--doc-root=}" ;;
    --root=*)        DOC_ROOT_ARG="${arg#--root=}" ;;
  esac
done

# ── Resolve doc root ──────────────────────────────────────────────────────────

_resolve_doc_root() {
  # 1. Explicit --doc-root / --root argument
  if [ -n "${DOC_ROOT_ARG:-}" ]; then
    printf '%s' "$DOC_ROOT_ARG"
    return
  fi

  # 2. doc_repo_path from CLAUDE.local.md (takes priority over local docs/ check —
  #    two-repo projects have doc_repo_path pointing to sibling repo, not local .)
  local local_md="CLAUDE.local.md"
  if [ ! -f "$local_md" ]; then
    # Worktree: try from git-common-dir
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null || true)"
    if [ -n "$common" ]; then
      local wt_root
      wt_root="$(cd "$(dirname "$common")" && pwd)"
      if [ -f "$wt_root/CLAUDE.local.md" ]; then
        local_md="$wt_root/CLAUDE.local.md"
      fi
    fi
  fi

  if [ -f "$local_md" ]; then
    # Parse doc_repo_path: from line "doc_repo_path: <value>"
    local val
    val="$(grep -m1 'doc_repo_path:' "$local_md" | sed 's/.*doc_repo_path:[[:space:]]*//' | tr -d '\r' | sed 's/#.*//' | tr -d ' ')"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      # Try relative to cwd first
      if [ -d "$val" ]; then
        printf '%s' "$val"
        return
      fi
      # Try relative to git-common-dir/../ (worktree)
      local common2
      common2="$(git rev-parse --git-common-dir 2>/dev/null || true)"
      if [ -n "$common2" ]; then
        local wt_root2
        wt_root2="$(cd "$(dirname "$common2")" && pwd)"
        local resolved="$wt_root2/$val"
        if [ -d "$resolved" ]; then
          printf '%s' "$resolved"
          return
        fi
      fi
    fi
  fi

  # 3. Local docs/ folder (single-repo consumer without CLAUDE.local.md)
  if [ -d "docs/product" ] || [ -d "docs/architecture" ]; then
    printf '%s' "."
    return
  fi

  printf ''
}

DOC_ROOT="$(_resolve_doc_root)"

if [ "$PRINT_DOC_ROOT" -eq 1 ]; then
  printf '%s\n' "$DOC_ROOT"
  exit 0
fi

# ── Locate map files ──────────────────────────────────────────────────────────

_find_map() {
  local name="$1"  # USER-MAP, ARTIFACT-MAP, SYSTEM-MAP
  local dr="${DOC_ROOT}"

  if [ -n "$dr" ]; then
    for cand in \
      "$dr/docs/product/${name}.md" \
      "$dr/docs/architecture/${name}.md" \
      "$dr/${name}.md"; do
      if [ -f "$cand" ]; then printf '%s' "$cand"; return; fi
    done
  fi

  # fallback: local
  for cand in \
    "docs/product/${name}.md" \
    "docs/architecture/${name}.md" \
    "${name}.md"; do
    if [ -f "$cand" ]; then printf '%s' "$cand"; return; fi
  done

  printf ''
}

USER_MAP="$(_find_map USER-MAP)"
ARTIFACT_MAP="$(_find_map ARTIFACT-MAP)"
SYSTEM_MAP="$(_find_map SYSTEM-MAP)"

# ── Enumerate artifacts ───────────────────────────────────────────────────────

_list_commands() {
  if [ -d "commands" ]; then
    for f in commands/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f" .md)"
      printf '/%s\n' "$base"
    done
  fi
}

_list_commands_local() {
  if [ -d "commands-local" ]; then
    for f in commands-local/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f" .md)"
      printf '/%s\n' "$base"
    done
  fi
}

_list_skills() {
  if [ -d "skills" ]; then
    for d in skills/*/; do
      [ -d "$d" ] || continue
      base="$(basename "$d")"
      printf '%s\n' "$base"
    done
  fi
}

_list_scripts() {
  if [ -d "scripts" ]; then
    for f in scripts/*.sh scripts/*.py; do
      [ -f "$f" ] || continue
      printf '%s\n' "$(basename "$f")"
    done
  fi
}

# ── Grep helpers (POSIX-boundary, CRLF-safe) ──────────────────────────────────

_grep_command_in_file() {
  local cmd="$1"   # e.g. /plan
  local file="$2"
  # Strip leading slash for matching flexibility; match /name with word boundaries
  local name="${cmd#/}"
  # POSIX: (^|non-alnum)/name($|non-alnum) — use extended grep
  tr -d '\r' < "$file" | grep -E "(^|[^a-zA-Z0-9_-])/${name}([^a-zA-Z0-9_-]|\$)" > /dev/null 2>&1
}

_grep_skill_in_file() {
  local skill="$1"
  local file="$2"
  tr -d '\r' < "$file" | grep -E "(^|[^a-z0-9-])${skill}([^a-z0-9-]|\$)" > /dev/null 2>&1
}

_grep_script_in_file() {
  local script="$1"
  local file="$2"
  tr -d '\r' < "$file" | grep -F "${script}" > /dev/null 2>&1
}

# ── ROADMAP axis ──────────────────────────────────────────────────────────────

_check_roadmap_axis() {
  local dr="${DOC_ROOT}"
  local roadmap=""

  for cand in \
    "$dr/ROADMAP.md" \
    "ROADMAP.md"; do
    if [ -f "$cand" ]; then roadmap="$cand"; break; fi
  done

  if [ -z "$roadmap" ]; then
    printf '[WARN] ROADMAP-axis: ROADMAP.md не найден — пропуск\n'
    return 0
  fi

  # Check mermaid block exists in ## Визуальный roadmap section
  if ! tr -d '\r' < "$roadmap" | grep -q '```mermaid'; then
    printf '[WARN] ROADMAP-axis: нет mermaid-блока в ROADMAP.md\n'
    return 0
  fi

  # Extract Now entries (## Now section lines starting with -)
  local now_entries=""
  now_entries="$(tr -d '\r' < "$roadmap" | awk '/^## Now/{found=1; next} found && /^## /{found=0} found && /^[-*]/{print}' | head -20)"

  # Extract last 10 Done entries
  local done_entries=""
  done_entries="$(tr -d '\r' < "$roadmap" | awk '/^## Done/{found=1; next} found && /^## /{found=0} found && /^[-*]/{print}' | tail -10)"

  local missing_count=0
  local missing_list=""

  # For each Now/Done entry, extract a short identifier (version or task name)
  # and check if it appears in the mermaid block
  local mermaid_content=""
  mermaid_content="$(tr -d '\r' < "$roadmap" | awk '/```mermaid/{found=1; next} found && /```/{found=0} found{print}')"

  local combined_entries="$now_entries
$done_entries"

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Extract task identifier: version like v5.X or bracketed name like [task-name]
    local ident=""
    # Try vX.Y.Z pattern
    ident="$(printf '%s' "$line" | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    if [ -z "$ident" ]; then
      # Try first bracketed word
      ident="$(printf '%s' "$line" | grep -oE '\[([^]]+)\]' | head -1 | tr -d '[]')"
    fi
    if [ -z "$ident" ]; then
      # Use first 3 significant words
      ident="$(printf '%s' "$line" | sed 's/^[-* ]*//' | cut -c1-30)"
    fi
    [ -z "$ident" ] && continue

    # Check in mermaid block (simple substring match for roadmap items)
    if ! printf '%s' "$mermaid_content" | grep -qF "$ident"; then
      missing_count=$((missing_count + 1))
      missing_list="${missing_list}  - ROADMAP entry not in mermaid: ${ident}\n"
    fi
  done << EOF
$combined_entries
EOF

  if [ "$missing_count" -gt 0 ]; then
    printf '[WARN] ROADMAP-axis: %d Now/Done записей не упомянуты в mermaid-блоке\n' "$missing_count"
    printf '%b' "$missing_list"
  else
    printf '[OK]   ROADMAP-axis: все Now/Done записи упомянуты в mermaid-блоке\n'
  fi
  return 0
}

# ── Main check ────────────────────────────────────────────────────────────────

ERRORS=0
WARNINGS=0
MISSING_LIST=""

_report_missing() {
  local severity="$1"
  local axis="$2"
  local name="$3"
  local mapfile="$4"

  if [ "$severity" = "ERROR" ]; then
    ERRORS=$((ERRORS + 1))
    printf '[ERROR] %s не найден в %s (%s)\n' "$name" "$axis" "$(basename "$mapfile")"
    MISSING_LIST="${MISSING_LIST}${name} (${axis})\n"
  else
    WARNINGS=$((WARNINGS + 1))
    printf '[WARN]  %s не найден в %s (%s)\n' "$name" "$axis" "$(basename "$mapfile")"
  fi
}

_check_axis() {
  local items="$1"       # newline-separated list
  local mapfile="$2"
  local axis_name="$3"
  local severity="$4"    # ERROR or WARN
  local kind="$5"        # command, skill, script

  if [ -z "$mapfile" ] || [ ! -f "$mapfile" ]; then
    if [ "$MODE" = "gate" ]; then
      printf '[ERROR] %s не найден — gate требует карту\n' "$axis_name"
      ERRORS=$((ERRORS + 1))
    else
      printf '[WARN]  %s не найден — пропуск (consumer без карты)\n' "$axis_name"
    fi
    return
  fi

  local checked=0
  local missed=0

  while IFS= read -r item; do
    [ -z "$item" ] && continue
    checked=$((checked + 1))
    local found=0
    case "$kind" in
      command) _grep_command_in_file "$item" "$mapfile" && found=1 || true ;;
      skill)   _grep_skill_in_file   "$item" "$mapfile" && found=1 || true ;;
      script)  _grep_script_in_file  "$item" "$mapfile" && found=1 || true ;;
    esac
    if [ "$found" -eq 0 ]; then
      missed=$((missed + 1))
      _report_missing "$severity" "$axis_name" "$item" "$mapfile"
    fi
  done << ITEMS_EOF
$items
ITEMS_EOF

  printf '[INFO]  %s: %d checked, %d missing\n' "$axis_name" "$checked" "$missed"
}

echo "=== validate-maps-coverage.sh (mode: ${MODE}) ==="
echo ""

COMMANDS="$(_list_commands)"
COMMANDS_LOCAL="$(_list_commands_local)"
SKILLS="$(_list_skills)"
SCRIPTS="$(_list_scripts)"

ALL_COMMANDS="${COMMANDS}
${COMMANDS_LOCAL}"

# USER-MAP checks
if printf '%s' "$USER_MAP_CHECK" | grep -q 'commands'; then
  _check_axis "$ALL_COMMANDS" "$USER_MAP" "USER-MAP/commands" "ERROR" "command"
fi
if printf '%s' "$USER_MAP_CHECK" | grep -q 'skills'; then
  _check_axis "$SKILLS" "$USER_MAP" "USER-MAP/skills" "ERROR" "skill"
fi

# ARTIFACT-MAP checks
if printf '%s' "$ARTIFACT_MAP_CHECK" | grep -q 'commands'; then
  _check_axis "$ALL_COMMANDS" "$ARTIFACT_MAP" "ARTIFACT-MAP/commands" "ERROR" "command"
fi

# SYSTEM-MAP checks
SYSTEM_SEV_CMD="ERROR"
[ "$SYSTEM_MAP_COMMANDS" = "warn" ] && SYSTEM_SEV_CMD="WARN"
_check_axis "$ALL_COMMANDS" "$SYSTEM_MAP" "SYSTEM-MAP/commands" "$SYSTEM_SEV_CMD" "command"

SYSTEM_SEV_SCR="WARN"
[ "$SYSTEM_MAP_SCRIPTS" = "gate" ] && SYSTEM_SEV_SCR="ERROR"
_check_axis "$SCRIPTS" "$SYSTEM_MAP" "SYSTEM-MAP/scripts" "$SYSTEM_SEV_SCR" "script"

# ROADMAP axis
_check_roadmap_axis

echo ""
echo "=== Summary: ${ERRORS} error(s), ${WARNINGS} warning(s) ==="

if [ "$ERRORS" -gt 0 ] && [ "$MODE" = "gate" ]; then
  echo ""
  echo "BLOCKED: добавь недостающие строки в карты и повтори деплой."
  printf '%b' "$MISSING_LIST"
  exit 1
fi

exit 0
