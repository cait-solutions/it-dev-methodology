#!/usr/bin/env bash
# validate-mermaid-syntax.sh — PLAN-C v5.49.0
# Structural anti-pattern checks for every ```mermaid block in .md files.
# V1: WARN-only (exit 0 always). --strict → exit 1 on findings.
# Checks: SUBGRAPH-EDGE, DUP-NODE, UNDEF-CLASS, CYRILLIC-ID, TRANSLIT-LABEL
# Scope: graph/flowchart blocks only (skip sequence/gantt/etc — too varied)
# Bash 3.2+ compatible (no associative arrays, no ${var,,})

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
TRANSLIT_WORDS="Stanet|Zapuskaet|Sozdaet|Chitaet|Pishet|Obnovlyaet|dobavlen|udalen|Poluchaet|Schitaet|Vypolnyaet|Nahodit|Hranit|Soderzhit"
EXCLUDE_PATTERNS="_tmp_*|node_modules|\.git"

# ---------------------------------------------------------------------------
ROOT="."
STRICT=0
FILE_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --*) echo "[WARN] Unknown option: $1"; shift ;;
    *) FILE_ARGS=("${FILE_ARGS[@]}" "$1"); shift ;;
  esac
done

ERRORS=0
WARNINGS=0

_sev_finding() {
  local severity="$1"
  local msg="$2"
  if [ "$severity" = "ERROR" ]; then
    ERRORS=$((ERRORS+1))
    echo "[ERROR] $msg"
  else
    WARNINGS=$((WARNINGS+1))
    echo "[WARN]  $msg"
  fi
}

# Extract mermaid blocks from a file. Each block: print lines between ``` markers.
# Only process graph/flowchart blocks (V1 scope).
_check_file_syntax() {
  local file="$1"
  local in_block=0
  local block_num=0
  local block_type=""
  local block_lines=""

  while IFS= read -r line; do
    if [ "$in_block" = "0" ]; then
      case "$line" in
        '```mermaid'|'``` mermaid')
          in_block=1
          block_num=$((block_num+1))
          block_type=""
          block_lines=""
          ;;
      esac
    else
      case "$line" in
        '```')
          in_block=0
          # Only analyze graph/flowchart blocks
          case "$block_type" in
            graph*|flowchart*)
              _analyze_block "$file" "$block_num" "$block_lines"
              ;;
            "")
              # block_type not set yet (empty block)
              ;;
          esac
          block_lines=""
          block_type=""
          ;;
        *)
          # First non-empty line sets block_type
          if [ -z "$block_type" ]; then
            block_type="$line"
          fi
          block_lines="$block_lines
$line"
          ;;
      esac
    fi
  done < "$file"
}

_analyze_block() {
  local file="$1"
  local block_num="$2"
  local block_content="$3"
  local ctx="$file block#$block_num"

  # --- Collect subgraph names ---
  local subgraph_ids
  subgraph_ids=$(echo "$block_content" | awk '
    /^[[:space:]]*subgraph[[:space:]]/ {
      line = $0
      # Remove leading spaces
      sub(/^[[:space:]]*subgraph[[:space:]]+/, "", line)
      # Extract id: up to [ or end
      if (index(line, "[") > 0) {
        id = substr(line, 1, index(line, "[")-1)
      } else {
        id = line
      }
      # Trim trailing spaces
      gsub(/[[:space:]]+$/, "", id)
      if (id != "") print id
    }
  ')

  # --- Collect declared node ids ---
  local node_ids
  node_ids=$(echo "$block_content" | awk '
    # Match lines like: ID[...] ID(...) ID{...} ID((...)}) ID>...]
    # Node declaration: word at start of meaningful content followed by [, (, {, >
    /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*[\[\(\{>]/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      match(line, /^[A-Za-z0-9_]+/)
      if (RLENGTH > 0) print substr(line, RSTART, RLENGTH)
    }
  ' | sort -u)

  # --- CHECK 1: SUBGRAPH-EDGE ---
  # Subgraph name used as arrow endpoint and NOT declared as a node
  if [ -n "$subgraph_ids" ]; then
    while IFS= read -r sg_id; do
      [ -z "$sg_id" ] && continue
      # Check if sg_id appears in an edge line (-->, -.->, ==>, ---, --o, --x, ===)
      local edge_hit
      edge_hit=$(echo "$block_content" | grep -E -- '(-->|-.->|==>|---|--o|--x|===)' | grep -F "$sg_id" | grep -v "subgraph")
      if [ -n "$edge_hit" ]; then
        # Check if sg_id is also declared as a standalone node
        local is_node
        is_node=$(echo "$node_ids" | grep -xF "$sg_id")
        if [ -z "$is_node" ]; then
          _sev_finding "WARN" "SUBGRAPH-EDGE: $ctx — subgraph '$sg_id' used as arrow endpoint without node declaration (G-085)"
        fi
      fi
    done <<EOF
$subgraph_ids
EOF
  fi

  # --- CHECK 2: DUP-NODE ---
  # Node id declared twice with different labels
  local dup_ids
  dup_ids=$(echo "$block_content" | awk '
    /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*[\[\(\{>]/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      match(line, /^[A-Za-z0-9_]+/)
      if (RLENGTH > 0) {
        id = substr(line, RSTART, RLENGTH)
        count[id]++
      }
    }
    END {
      for (id in count) {
        if (count[id] > 1) print id
      }
    }
  ')
  if [ -n "$dup_ids" ]; then
    while IFS= read -r dup_id; do
      [ -z "$dup_id" ] && continue
      _sev_finding "WARN" "DUP-NODE: $ctx — node id '$dup_id' declared multiple times (last label wins silently, G-029)"
    done <<EOF
$dup_ids
EOF
  fi

  # --- CHECK 3: UNDEF-CLASS ---
  # :::className used but classDef className absent
  local used_classes
  used_classes=$(echo "$block_content" | grep -oE ':::([A-Za-z][A-Za-z0-9_]*)' | sed 's/::://' | sort -u)
  if [ -n "$used_classes" ]; then
    while IFS= read -r cls; do
      [ -z "$cls" ] && continue
      local def_found
      def_found=$(echo "$block_content" | grep -E "classDef[[:space:]]+$cls([[:space:]]|$)")
      if [ -z "$def_found" ]; then
        _sev_finding "WARN" "UNDEF-CLASS: $ctx — :::$cls used but classDef $cls not found in block"
      fi
    done <<EOF
$used_classes
EOF
  fi

  # --- CHECK 4: CYRILLIC-ID ---
  # Cyrillic characters in node-id (not in label/string)
  # Node ids are before [, (, {, > on declaration lines
  local cyrillic_ids
  cyrillic_ids=$(echo "$block_content" | awk '
    /^[[:space:]]*[[:alnum:]_]+[[:space:]]*[\[\(\{>]/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      match(line, /^[A-Za-z0-9_\x80-\xff]+/)
      if (RLENGTH > 0) {
        id = substr(line, RSTART, RLENGTH)
        # Check for cyrillic bytes (UTF-8 range \xD0-\xD1 for Russian)
        if (id ~ /[\xD0-\xD1]/) print id
      }
    }
  ')
  if [ -n "$cyrillic_ids" ]; then
    while IFS= read -r cyr_id; do
      [ -z "$cyr_id" ] && continue
      _sev_finding "WARN" "CYRILLIC-ID: $ctx — node id '$cyr_id' contains Cyrillic characters (G-005)"
    done <<EOF
$cyrillic_ids
EOF
  fi

  # --- CHECK 5: TRANSLIT-LABEL (heuristic) ---
  # Label text contains known transliteration words
  local translit_hits
  translit_hits=$(echo "$block_content" | grep -oE "\"[^\"]*($TRANSLIT_WORDS)[^\"]*\"" | head -5)
  if [ -z "$translit_hits" ]; then
    # Also check unquoted labels (between [ ] brackets)
    translit_hits=$(echo "$block_content" | grep -oE "\[([^\]]*($TRANSLIT_WORDS)[^\]]*)\]" | head -5)
  fi
  if [ -n "$translit_hits" ]; then
    _sev_finding "WARN" "TRANSLIT-LABEL: $ctx — label contains transliterated Cyrillic (CLAUDE.md Maps Standard: use real Cyrillic)"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== validate-mermaid-syntax.sh ==="

_process_file() {
  local mdfile="$1"
  [ -f "$mdfile" ] || return
  grep -q '```mermaid' "$mdfile" || return
  file_count=$((file_count+1))
  _check_file_syntax "$mdfile"
}

file_count=0

if [ ${#FILE_ARGS[@]} -gt 0 ]; then
  # Explicit file list — iterate via array (space-safe)
  for f in "${FILE_ARGS[@]}"; do
    _process_file "$f"
  done
else
  # Find all .md files excluding patterns — tmpfile for space-safe iteration (bash 3.2)
  _tmplist=$(mktemp)
  find "$ROOT" -name "*.md" | grep -vE "($EXCLUDE_PATTERNS)" | sort > "$_tmplist"
  while IFS= read -r mdfile; do
    _process_file "$mdfile"
  done < "$_tmplist"
  rm -f "$_tmplist"
fi

echo "[INFO]  syntax: checked $file_count file(s) with mermaid blocks"
echo ""
echo "=== Summary: $ERRORS error(s), $WARNINGS warning(s) ==="

if [ "$STRICT" = "1" ] && [ "$WARNINGS" -gt 0 ]; then
  exit 1
fi
exit 0
