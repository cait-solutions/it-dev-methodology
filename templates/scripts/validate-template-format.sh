#!/usr/bin/env bash
#
# validate-template-format.sh — check that key format patterns in templates/*.template.md
# conform to the current methodology standard.
#
# Usage:
#   bash scripts/validate-template-format.sh [--root DIR]
#
# Exit codes:
#   0  all checks pass
#   1  one or more format violations found
#
# What it checks:
#   1. SYSTEM-MAP template has Agent TL;DR + Граф секция
#   2. USER-MAP template has Refresh Policy
#   3. ARTIFACT-MAP template has Refresh Policy
#   4. No stale mermaid link format (markdown-link style) in map templates
#   5. commands/*.md have no unresolved {{placeholders}}
#
# Bash 3.2+ compatible (no associative arrays, no ${var,,})

set -uo pipefail

ROOT="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

TEMPLATES_DIR="$ROOT/templates"
VIOLATIONS=0

warn() {
  echo "  WARNING: $1" >&2
  VIOLATIONS=$((VIOLATIONS + 1))
}

ok() {
  echo "  ok: $1"
}

_has_section() {
  grep -q "$1" "$2" 2>/dev/null
}

_count_pattern() {
  # Bash 3.2 safe grep count — avoid multiline output on Windows
  local file="$1" pat="$2"
  grep -c "$pat" "$file" 2>/dev/null | tr -d '[:space:]'
}

echo "validate-template-format: checking $TEMPLATES_DIR"
echo ""

# ---- Check 1: SYSTEM-MAP required sections ----
echo "Check 1: SYSTEM-MAP.template.md sections"
file="$TEMPLATES_DIR/SYSTEM-MAP.template.md"
if [ ! -f "$file" ]; then
  warn "SYSTEM-MAP.template.md not found"
else
  _has_section "Agent TL;DR" "$file" && ok "SYSTEM-MAP has Agent TL;DR" || warn "SYSTEM-MAP.template.md missing Agent TL;DR"
  _has_section "Граф системы\|## Граф\|## System" "$file" && ok "SYSTEM-MAP has graph section" || warn "SYSTEM-MAP.template.md missing graph section"
fi

echo ""

# ---- Check 2: USER-MAP required sections ----
echo "Check 2: USER-MAP.template.md sections"
file="$TEMPLATES_DIR/USER-MAP.template.md"
if [ ! -f "$file" ]; then
  warn "USER-MAP.template.md not found"
else
  _has_section "Refresh Policy" "$file" && ok "USER-MAP has Refresh Policy" || warn "USER-MAP.template.md missing Refresh Policy"
fi

echo ""

# ---- Check 3: ARTIFACT-MAP required sections ----
echo "Check 3: ARTIFACT-MAP.template.md sections"
file="$TEMPLATES_DIR/ARTIFACT-MAP.template.md"
if [ ! -f "$file" ]; then
  warn "ARTIFACT-MAP.template.md not found"
else
  _has_section "Refresh Policy" "$file" && ok "ARTIFACT-MAP has Refresh Policy" || warn "ARTIFACT-MAP.template.md missing Refresh Policy"
fi

echo ""

# ---- Check 4: No stale mermaid link format ----
echo "Check 4: No stale mermaid link format in map templates"
for tpl_name in SYSTEM-MAP USER-MAP ARTIFACT-MAP; do
  file="$TEMPLATES_DIR/${tpl_name}.template.md"
  [ -f "$file" ] || continue
  # Bad patterns: > 🔗 [text](url)  OR  [Открыть в Mermaid Live](http...)
  if grep -q "\[Открыть.*Mermaid.*\](http" "$file" 2>/dev/null; then
    warn "$tpl_name.template.md has stale markdown-link mermaid format — should be bare URL"
  elif grep -q "> 🔗 \[" "$file" 2>/dev/null; then
    warn "$tpl_name.template.md has stale '> 🔗 [' mermaid format — should be bare URL"
  else
    ok "$tpl_name.template.md no stale mermaid link format"
  fi
done

echo ""

# ---- Check 5: commands/*.md no unresolved {{placeholders}} ----
echo "Check 5: commands/*.md no unresolved {{placeholders}}"
COMMANDS_DIR="$ROOT/commands"
found_violations=0
if [ -d "$COMMANDS_DIR" ]; then
  for cmd in "$COMMANDS_DIR"/*.md; do
    [ -f "$cmd" ] || continue
    if grep -q "{{[A-Z_]*}}" "$cmd" 2>/dev/null; then
      count=$(_count_pattern "$cmd" "{{[A-Z_]*}}")
      warn "$(basename $cmd) has $count unresolved {{placeholder}}(s)"
      found_violations=$((found_violations + 1))
    fi
  done
  if [ "$found_violations" -eq 0 ]; then
    ok "commands/*.md — no unresolved placeholders"
  fi
fi

echo ""

# ---- Summary ----
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "PASS: validate-template-format: all checks passed (0 violations)"
  exit 0
else
  echo "FAIL: validate-template-format: $VIOLATIONS violation(s) found" >&2
  exit 1
fi
