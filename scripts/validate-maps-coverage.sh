#!/usr/bin/env bash
# validate-maps-coverage.sh — Level-4 maps coverage gate (PLAN-H v5.48.0)
#
# Checks that every command, local-only command, and skill is mentioned in the
# living maps (USER-MAP.md, ARTIFACT-MAP.md, SYSTEM-MAP.md).
# Also runs generic diagram-freshness engine against diagram-sources annotations.
#
# Configuration matrix — edit here, no logic changes needed:
USER_MAP_CHECK="commands skills"        # axes checked against USER-MAP
USER_MAP_NO_SCRIPTS="gate"             # gate=ERROR if script-nodes found in USER-MAP mermaid blocks
                                       # command-first invariant: scripts are internal impl, not user-facing
                                       # consumers use "warn" (no commands/ source dir = no baseline)
USER_MAP_MERMAID_COVERAGE="warn"       # warn=WARN if command/skill missing from mermaid blocks (not just file)
                                       # gate=ERROR on miss; "off" disables axis entirely
                                       # consumers use "warn" — no false-positives on partial maps
ARTIFACT_MAP_CHECK="commands"          # axes checked against ARTIFACT-MAP
SYSTEM_MAP_COMMANDS="gate"             # gate=ERROR on miss; warn=WARNING only
SYSTEM_MAP_SCRIPTS="warn"             # scripts only WARN in V1 (PLAN-B escalates)
DIAGRAM_FRESHNESS_SEVERITY="warn"      # warn|error — block deploy on stale diagrams
NODE_READABILITY_SEVERITY="warn"       # warn|error — node missing Зачем/Impact format (v5.57.0)
                                       # CLAUDE.md Maps Standard §3 «Формат node-описания»
                                       # warn=WARN if component node has <1 <br/> separator (no Зачем+Impact)
                                       # affordance-class nodes and deferred-cluster exempt
MAP_STALENESS_SEVERITY="warn"          # warn|error — content-staleness of diagrams (v6.1.0, closes /diagnose root cause)
                                       # Detection-ось: компонент-файл изменён в git ПОЗЖЕ карты, которая его описывает →
                                       # рукописные стрелки/labels диаграммы могли отстать от логики. Источник маппинга
                                       # компонент→карты — колонка «Связанные артефакты» в LIVING-ARTIFACTS.md (не label-parse).
                                       # Commit-based сравнение (не file-mtime): same-commit ⇒ синхронный PR-couple ⇒ НЕ stale.
                                       # warn=WARN (не блок) — это подсказка «сверь», семантику не проверяет (ADR-015 L3+detect).
                                       # Дополняет presence (coverage) + url-freshness (mermaid-links): третья detection-ось.
#
# Why scripts=warn: /retro 2026-06-11 data covers commands only. Script coverage
# is large and partially internal — escalate after /retro evidence (PLAN-B).
# Why commands-local non-issue for consumers: commands-local/ is empty in consumers.
# Why USER_MAP_NO_SCRIPTS: command-first invariant (CLAUDE.md) requires USER-MAP shows
#   only commands/skills/affordance — not scripts. Scripts are internal impl. Consumers
#   get "warn" because they rarely have commands/ dir (graceful; closes G-116).
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

# ── Generic diagram-freshness engine (PLAN-H v5.48.0) ────────────────────────
#
# Scans living-scope .md files for <!-- diagram-sources: ... --> annotations
# and verifies diagram content matches declared data sources.
#
# Annotation enum (closed — new type requires new /plan):
#   table:<Section>      — pipe-table rows from section present in diagram
#   list:<Section>       — top-level bullet bold-names from section present in diagram
#   max-version:<Section>— max vX.Y from section > version-marker in diagram → WARN
#   axes                 — covered by FS-axes (living maps); engine skips
#   none                 — static diagram; engine skips
#
# Living scope: DOC_ROOT root + docs/architecture/ + docs/product/
# Excluded: _tmp_* templates/ .claude/ docs/plans/ node_modules

_freshness_sev() {
  if [ "$DIAGRAM_FRESHNESS_SEVERITY" = "error" ]; then
    printf 'ERROR'
  else
    printf 'WARN'
  fi
}

_freshness_finding() {
  local file="$1"
  local msg="$2"
  local sev
  sev="$(_freshness_sev)"
  if [ "$sev" = "ERROR" ]; then
    ERRORS=$((ERRORS+1))
    printf '[ERROR] diagram-freshness: %s — %s\n' "$(basename "$file")" "$msg"
  else
    WARNINGS=$((WARNINGS+1))
    printf '[WARN]  diagram-freshness: %s — %s\n' "$(basename "$file")" "$msg"
  fi
}

# Extract max vX.Y(.Z) from text
_max_version_from_text() {
  local text="$1"
  printf '%s' "$text" | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | \
    sort -t. -k1,1V -k2,2n -k3,3n 2>/dev/null | tail -1
}

# Compare two versions: returns 0 if v1 > v2, 1 otherwise
_version_gt() {
  local v1="${1#v}" v2="${2#v}"
  local winner
  winner="$(printf '%s\n%s' "$v1" "$v2" | sort -t. -k1,1V -k2,2n -k3,3n 2>/dev/null | tail -1)"
  [ "$winner" = "$v1" ] && [ "$v1" != "$v2" ]
}

# Parse a section from a file — returns lines of the section
_parse_section_lines() {
  local file="$1"
  local section="$2"
  tr -d '\r' < "$file" | awk -v sec="$section" \
    'BEGIN{found=0}
     /^## /{if(found){exit} if($0 ~ "## " sec "($| )"){found=1; next}}
     found{print}'
}

# Extract identifiers from section — dual-format: pipe-table + top-level bullets
# Returns one identifier per line (full string, no truncation)
_extract_idents_table() {
  local section_text="$1"
  # Pipe-table: lines starting with |, skip header (|---|) and empty first-cell
  printf '%s' "$section_text" | grep '^|' | grep -v '^|[-: |]*$' | \
    awk -F'|' '{
      cell=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
      if(length(cell)>0 && cell !~ /^[-: ]+$/) print cell
    }'
}

_extract_idents_bullets() {
  local section_text="$1"
  # Top-level bullets: lines starting with "- " or "* ", extract **bold** name
  printf '%s' "$section_text" | grep -E '^[-*] ' | \
    grep -oE '\*\*[^*]+\*\*' | sed 's/\*\*//g'
}

_extract_version_max_from_section() {
  local section_text="$1"
  _max_version_from_text "$section_text"
}

# Check one mermaid block against diagram-sources annotation
# $1=file $2=annotation_value $3=mermaid_content $4=block_num
_check_one_block() {
  local file="$1"
  local annotation="$2"
  local mermaid_content="$3"
  local block_num="$4"
  local block_label="block#${block_num}"

  # Split annotation by comma
  local sources
  sources="$(printf '%s' "$annotation" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

  local findings=0

  while IFS= read -r source; do
    [ -z "$source" ] && continue

    local stype sval
    stype="$(printf '%s' "$source" | cut -d: -f1)"
    sval="$(printf '%s' "$source" | cut -d: -f2-)"

    case "$stype" in
      axes|none)
        # Skip — covered by FS-axes or static
        continue
        ;;
      table|list|max-version)
        # Find section
        local sec_lines
        sec_lines="$(_parse_section_lines "$file" "$sval")"
        if [ -z "$sec_lines" ]; then
          _freshness_finding "$file" "${block_label}: секция '${sval}' из diagram-sources не найдена"
          findings=$((findings+1))
          continue
        fi

        if [ "$stype" = "max-version" ]; then
          # Extract max version from section (both table and bullet formats)
          local max_v
          max_v="$(_extract_version_max_from_section "$sec_lines")"
          if [ -z "$max_v" ]; then
            # Parser no-op self-check: section non-empty but 0 versions extracted
            _freshness_finding "$file" "${block_label}: parser no-op — секция '${sval}' непуста, но версии не извлечены"
            findings=$((findings+1))
            continue
          fi
          # Find version-marker in mermaid block: "до vX.Y" pattern
          local marker_v
          marker_v="$(printf '%s' "$mermaid_content" | grep -oE 'до v[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
          if [ -z "$marker_v" ]; then
            _freshness_finding "$file" "${block_label}: version-маркер 'до vX.Y' не найден в диаграмме (max в секции '${sval}': ${max_v})"
            findings=$((findings+1))
            continue
          fi
          if _version_gt "$max_v" "$marker_v"; then
            _freshness_finding "$file" "${block_label}: диаграмма отстала — маркер ${marker_v}, max в секции '${sval}': ${max_v}"
            findings=$((findings+1))
          fi

        elif [ "$stype" = "table" ]; then
          local idents
          idents="$(_extract_idents_table "$sec_lines")"
          if [ -z "$idents" ]; then
            # Self-check: section has pipe-table lines but 0 idents extracted?
            local has_table
            has_table="$(printf '%s' "$sec_lines" | grep -c '^|' || true)"
            if [ "$has_table" -gt 0 ]; then
              _freshness_finding "$file" "${block_label}: parser no-op — секция '${sval}' содержит таблицу, но идентификаторы не извлечены"
              findings=$((findings+1))
            fi
            continue
          fi
          local miss=0
          while IFS= read -r ident; do
            [ -z "$ident" ] && continue
            if ! printf '%s' "$mermaid_content" | grep -qF "$ident"; then
              miss=$((miss+1))
              if [ "$miss" -le 5 ]; then
                _freshness_finding "$file" "${block_label}: '${ident}' (из секции '${sval}') не найден в диаграмме"
                findings=$((findings+1))
              fi
            fi
          done << IDENTS_EOF
$idents
IDENTS_EOF

        elif [ "$stype" = "list" ]; then
          local bidents
          bidents="$(_extract_idents_bullets "$sec_lines")"
          if [ -z "$bidents" ]; then
            local has_bullets
            has_bullets="$(printf '%s' "$sec_lines" | grep -cE '^[-*] ' || true)"
            if [ "$has_bullets" -gt 0 ]; then
              _freshness_finding "$file" "${block_label}: parser no-op — секция '${sval}' содержит буллеты, но **bold**-имена не извлечены"
              findings=$((findings+1))
            fi
            continue
          fi
          local bmiss=0
          while IFS= read -r bident; do
            [ -z "$bident" ] && continue
            if ! printf '%s' "$mermaid_content" | grep -qF "$bident"; then
              bmiss=$((bmiss+1))
              if [ "$bmiss" -le 5 ]; then
                _freshness_finding "$file" "${block_label}: '${bident}' (из секции '${sval}') не найден в диаграмме"
                findings=$((findings+1))
              fi
            fi
          done << BIDENTS_EOF
$bidents
BIDENTS_EOF
        fi
        ;;
      *)
        _freshness_finding "$file" "${block_label}: неизвестный тип источника '${stype}' в diagram-sources"
        findings=$((findings+1))
        ;;
    esac
  done << SOURCES_EOF
$sources
SOURCES_EOF
}

# Scan one .md file for mermaid blocks + annotations
_scan_file_freshness() {
  local file="$1"
  local content
  content="$(tr -d '\r' < "$file")"

  local block_num=0
  local in_block=0
  local mermaid_buf=""
  local annotation=""
  local prev_annotation=""

  while IFS= read -r line; do
    if [ "$in_block" -eq 0 ]; then
      # Look for diagram-sources annotation
      case "$line" in
        *'<!-- diagram-sources:'*)
          prev_annotation="$(printf '%s' "$line" | sed 's/.*diagram-sources:[[:space:]]*//' | sed 's/[[:space:]]*-->.*//')"
          ;;
      esac
      case "$line" in
        '```mermaid'*)
          in_block=1
          block_num=$((block_num+1))
          annotation="$prev_annotation"
          mermaid_buf=""
          prev_annotation=""
          ;;
      esac
    else
      case "$line" in
        '```')
          in_block=0
          # Process this block
          if [ -z "$annotation" ]; then
            _freshness_finding "$file" "block#${block_num}: нет аннотации diagram-sources — добавь <!-- diagram-sources: ... --> перед блоком"
          else
            _check_one_block "$file" "$annotation" "$mermaid_buf" "$block_num"
          fi
          mermaid_buf=""
          annotation=""
          ;;
        *)
          mermaid_buf="${mermaid_buf}
${line}"
          ;;
      esac
    fi
  done << FILE_CONTENT_EOF
$content
FILE_CONTENT_EOF
}

# Determine living scope files to scan
_check_diagram_freshness() {
  local dr="${DOC_ROOT}"
  local scanned=0
  local skip_patterns="_tmp_ templates/ .claude/ docs/plans/ node_modules"

  # Build file list from living scope: doc_root + docs/architecture/ + docs/product/
  local scope_dirs=""
  if [ -n "$dr" ] && [ -d "$dr" ]; then
    scope_dirs="$dr"
    [ -d "$dr/docs/architecture" ] && scope_dirs="$scope_dirs $dr/docs/architecture"
    [ -d "$dr/docs/product" ]       && scope_dirs="$scope_dirs $dr/docs/product"
  else
    [ -d "docs/architecture" ] && scope_dirs="docs/architecture"
    [ -d "docs/product" ]       && scope_dirs="$scope_dirs docs/product"
    scope_dirs="${scope_dirs:-.}"
  fi

  for scope_dir in $scope_dirs; do
    for f in "$scope_dir"/*.md; do
      [ -f "$f" ] || continue
      # Skip excluded patterns
      local skip=0
      for pat in $skip_patterns; do
        case "$f" in *"$pat"*) skip=1; break ;; esac
      done
      [ "$skip" -eq 1 ] && continue
      # Only process files that actually contain mermaid blocks
      if grep -q '```mermaid' "$f" 2>/dev/null; then
        _scan_file_freshness "$f"
        scanned=$((scanned+1))
      fi
    done
  done

  if [ "$scanned" -eq 0 ]; then
    printf '[INFO]  diagram-freshness: нет .md файлов с mermaid-блоками в living-scope\n'
  else
    printf '[INFO]  diagram-freshness: проверено %d файлов с mermaid-блоками\n' "$scanned"
  fi
}

# ── Node readability check (v5.57.0, closes G-121) ───────────────────────────
#
# Checks that component nodes in mermaid blocks follow the 3-line format:
#   NodeID["Name<br/>Зачем: ...<br/>Без него: ..."]
#
# Detection strategy: ASCII-anchor only (cp1252-safe on Windows/Git Bash).
# A component node definition is a line matching:   ID["..."] or ID['...']
# A node is considered "readable" if its label contains at least 2 <br/> separators
# (meaning: Name + line2 + line3).
# Exempt: affordance-class nodes (:::affordance), deferred-subgraph lines,
#         nodes whose label is ≤ 40 chars (Legend, short anchor labels).
#
# This check scans .md files in the same living-scope as diagram-freshness.
# NODE_READABILITY_SEVERITY="warn" — does not block deploy, advisory only.

_node_readability_sev() {
  if [ "$NODE_READABILITY_SEVERITY" = "error" ]; then
    printf 'ERROR'
  else
    printf 'WARN'
  fi
}

_check_node_readability_file() {
  local file="$1"
  local content
  content="$(tr -d '\r' < "$file")"
  local in_block=0
  local findings=0

  while IFS= read -r line; do
    case "$line" in
      '```mermaid'*) in_block=1; continue ;;
      '```')         in_block=0; continue ;;
    esac
    [ "$in_block" -eq 0 ] && continue

    # Skip affordance nodes, deferred-cluster, and subgraph declarations.
    # subgraph headers are container labels, not component nodes — they carry no
    # Зачем/Impact obligation (closes G-121b subgraph false-positive).
    case "$line" in
      *':::affordance'*|*'subgraph Deferred'*|*'classDef deferred'*|*'classDef affordance'*)
        continue ;;
      *'subgraph '*) continue ;;
    esac

    # Skip EDGE lines (closes node-readability false-positive class, G-121b).
    # An edge line carries an arrow operator or an edge-label pipe; on such a line
    # the bracket-label belongs to an edge-label or an inline target, not the node
    # whose format we audit. Node-format is enforced where the node is FIRST
    # defined standalone. Auditing edges flagged edge-LABELS as node descriptions,
    # which trains the owner to ignore the validator.
    case "$line" in
      *'--'*|*'=='*|*'.->'*|*'~~~'*) continue ;;
      *'|'*'['*) continue ;;
    esac

    # Match component node definitions: NodeID["label"] or NodeID['label']
    # Pattern: word-chars, then [" or [' (node label open)
    case "$line" in
      *'["'*|*"['"'"'")
        # Extract label between outer quotes (approximate: take content after first [")
        label="$(printf '%s' "$line" | sed 's/.*\[["'"'"']//' | sed 's/["'"'"']\].*//')"
        # Skip if label is short (≤ 40 chars) — likely Legend/anchor
        len="${#label}"
        [ "$len" -le 40 ] && continue
        # Skip if label contains only ASCII-path (no space after first word) — heuristic
        # Count <br/> occurrences — need at least 2 for 3-line format
        br_count="$(printf '%s' "$label" | grep -o '<br/>' | wc -l | tr -d ' ')"
        if [ "${br_count:-0}" -lt 2 ]; then
          sev="$(_node_readability_sev)"
          node_id="$(printf '%s' "$line" | sed 's/[[:space:]]*//' | cut -c1-30)"
          printf '[%s]  node-readability: %s — нода "%s..." без формата Зачем/Impact (<br/> count=%s, нужно ≥2). См. CLAUDE.md §3 «Формат node-описания»\n' \
            "$sev" "$(basename "$file")" "$node_id" "${br_count:-0}"
          findings=$((findings+1))
        fi
        ;;
    esac
  done << NR_EOF
$content
NR_EOF

  # Return the finding count so the caller folds it into ERRORS/WARNINGS totals.
  # Без этого Summary рапортует ноль warnings при десятках напечатанных WARN
  # (counter disconnect, closes G-121b). Cap at 255 (shell return-code ceiling).
  [ "$findings" -gt 255 ] && findings=255
  return "$findings"
}

_check_node_readability() {
  local dr="${DOC_ROOT}"
  local skip_patterns="_tmp_ templates/ .claude/ docs/plans/ node_modules"

  local scope_dirs=""
  if [ -n "$dr" ] && [ -d "$dr" ]; then
    scope_dirs="$dr"
    [ -d "$dr/docs/architecture" ] && scope_dirs="$scope_dirs $dr/docs/architecture"
    [ -d "$dr/docs/product" ]       && scope_dirs="$scope_dirs $dr/docs/product"
  else
    [ -d "docs/architecture" ] && scope_dirs="docs/architecture"
    [ -d "docs/product" ]       && scope_dirs="$scope_dirs docs/product"
    scope_dirs="${scope_dirs:-.}"
  fi

  for scope_dir in $scope_dirs; do
    for f in "$scope_dir"/*.md; do
      [ -f "$f" ] || continue
      local skip=0 nr_n=0
      for pat in $skip_patterns; do
        case "$f" in *"$pat"*) skip=1; break ;; esac
      done
      [ "$skip" -eq 1 ] && continue
      grep -q '```mermaid' "$f" 2>/dev/null || continue
      # `|| nr_n=$?` keeps the non-zero finding-count return from tripping set -e;
      # on zero findings the `&&` arm sets nr_n=0.
      _check_node_readability_file "$f" && nr_n=0 || nr_n=$?
      if [ "$nr_n" -gt 0 ]; then
        if [ "$(_node_readability_sev)" = "ERROR" ]; then
          ERRORS=$((ERRORS + nr_n))
        else
          WARNINGS=$((WARNINGS + nr_n))
        fi
      fi
    done
  done
  return 0
}

# ── Map content-staleness check (v6.1.0, closes /diagnose root cause) ────────
#
# Detection-ось: living-карта могла содержательно отстать от логики компонента.
# Когда файл-компонент (script/command/hook/mechanism) изменён в git ПОЗЖЕ карты,
# которая его описывает — рукописные стрелки/labels диаграммы могли устареть, но
# presence-coverage (нода есть) и url-freshness (URL свеж) этого НЕ ловят.
#
# Маппинг компонент→карты берётся из LIVING-ARTIFACTS.md колонки «Связанные
# артефакты»: каждая не-map LAR-строка декларирует какие карты её описывают
# (напр. validate-maps-coverage.sh → USER-MAP · ARTIFACT-MAP · SYSTEM-MAP).
# Это явный человеческий маппинг (PR-coupled в /code Шаг 5), не хрупкий label-parse.
#
# Сравнение COMMIT-based, не file-mtime: если компонент и карта в ОДНОМ последнем
# коммите → синхронный PR-couple → НЕ stale (устраняет ложные WARN, урок G-121b).
# Stale = последний коммит компонента СТРОГО новее последнего коммита карты.
#
# Graceful: git недоступен (zip-снимок consumer) / файл удалён / LAR отсутствует
# → skip + видимый INFO-счётчик (не silent miss, FMEA D-mitigation).
#
# Two-repo: git log выполняется в репо КАЖДОГО файла через `git -C <dir>` — карты в
# doc-repo, компоненты в code-repo. cwd-git был бы слеп к doc-repo (execution-context).

_map_staleness_sev() {
  if [ "$MAP_STALENESS_SEVERITY" = "error" ]; then printf 'ERROR'; else printf 'WARN'; fi
}

# git commit timestamp (epoch) последнего коммита, тронувшего файл; пусто если git нет / файл untracked
_git_last_commit_ts() {
  local f="$1"
  local dir base
  dir="$(dirname "$f")"
  base="$(basename "$f")"
  [ -d "$dir" ] || return 0
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$dir" log -1 --format=%ct -- "$base" 2>/dev/null
}

# git commit hash последнего коммита, тронувшего файл (для same-commit детекта)
_git_last_commit_hash() {
  local f="$1"
  local dir base
  dir="$(dirname "$f")"
  base="$(basename "$f")"
  [ -d "$dir" ] || return 0
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$dir" log -1 --format=%H -- "$base" 2>/dev/null
}

# Единый источник множества living-maps (closes G-123: ROADMAP выпадал из хардкода «3 карты»).
# ⛔ Добавляя новую living-map — добавь имя СЮДА и резолв в _resolve_map_path. Множество явное,
# не «3 по памяти». 4-я карта ROADMAP — Temporal/Priorities viewpoint (LAR тип: map), лежит в
# КОРНЕ doc-repo (не docs/product), потому резолвится отдельно.
LIVING_MAPS="USER-MAP SYSTEM-MAP ARTIFACT-MAP ROADMAP"

# Резолв пути карты по её имени из LAR-ячейки.
# USER/SYSTEM/ARTIFACT-MAP — через _find_map ($USER_MAP/$SYSTEM_MAP/$ARTIFACT_MAP).
# ROADMAP — в корне DOC_ROOT (или local), отдельный резолв.
_resolve_map_path() {
  case "$1" in
    *USER-MAP*)     printf '%s' "$USER_MAP" ;;
    *SYSTEM-MAP*)   printf '%s' "$SYSTEM_MAP" ;;
    *ARTIFACT-MAP*) printf '%s' "$ARTIFACT_MAP" ;;
    *ROADMAP*)
      if [ -n "${DOC_ROOT:-}" ] && [ -f "$DOC_ROOT/ROADMAP.md" ]; then
        printf '%s' "$DOC_ROOT/ROADMAP.md"
      elif [ -f "ROADMAP.md" ]; then
        printf '%s' "ROADMAP.md"
      else
        printf ''
      fi
      ;;
    *)              printf '' ;;
  esac
}

# Резолв пути компонента из LAR первой ячейки (напр. `scripts/validate-maps-coverage.sh`)
# Снимает backtick-обёртку. Проверяет существование относительно cwd (code-repo).
_resolve_component_path() {
  local raw="$1"
  local p
  p="$(printf '%s' "$raw" | tr -d '`' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
  [ -f "$p" ] && printf '%s' "$p" || printf ''
}

_check_map_staleness() {
  local dr="${DOC_ROOT}"
  local lar=""
  # Найти LIVING-ARTIFACTS.md (doc-repo приоритет, потом local)
  for cand in \
    "$dr/docs/architecture/LIVING-ARTIFACTS.md" \
    "docs/architecture/LIVING-ARTIFACTS.md"; do
    if [ -n "$cand" ] && [ -f "$cand" ]; then lar="$cand"; break; fi
  done

  if [ -z "$lar" ]; then
    printf '[INFO]  map-staleness: LIVING-ARTIFACTS.md не найден — ось пропущена (нет маппинга компонент→карты)\n'
    return 0
  fi

  # git вообще доступен? (zip-снимок consumer → нет)
  if ! git -C "$(dirname "$lar")" rev-parse --git-dir >/dev/null 2>&1; then
    printf '[INFO]  map-staleness: git недоступен в репо карт — ось пропущена (graceful)\n'
    return 0
  fi

  local sev checked stale skipped
  sev="$(_map_staleness_sev)"
  checked=0; stale=0; skipped=0

  # Парсим pipe-таблицу LAR: первая ячейка = файл-артефакт, последняя = «Связанные артефакты».
  # Интересуют строки где первая ячейка — путь к script/command/hook (содержит / и расширение),
  # а последняя ячейка упоминает *-MAP. Карты-строки (тип map) пропускаем — у них «связанные» = др. карты.
  while IFS= read -r row; do
    case "$row" in
      '|'*'|'*) : ;;          # это table-row
      *) continue ;;
    esac
    # skip header / separator
    case "$row" in
      *'Артефакт'*'Тип'*) continue ;;
      *'---'*) continue ;;
    esac

    local first last
    first="$(printf '%s' "$row" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    last="$(printf '%s' "$row" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Связанные артефакты упоминают карту?
    case "$last" in
      *MAP*) : ;;
      *) continue ;;
    esac

    local comp
    comp="$(_resolve_component_path "$first")"
    [ -z "$comp" ] && continue          # первая ячейка не разрешается в существующий файл (карта/доки/несуществующий)

    local comp_ts comp_hash
    comp_ts="$(_git_last_commit_ts "$comp")"
    comp_hash="$(_git_last_commit_hash "$comp")"
    [ -z "$comp_ts" ] && { skipped=$((skipped+1)); continue; }   # untracked / git miss

    # По каждой living-map, упомянутой в «Связанные артефакты» (источник — $LIVING_MAPS)
    local map_name
    for map_name in $LIVING_MAPS; do
      case "$last" in
        *"$map_name"*) : ;;
        *) continue ;;
      esac
      local mapf
      mapf="$(_resolve_map_path "$map_name")"
      [ -z "$mapf" ] && continue
      [ -f "$mapf" ] || continue

      local map_ts map_hash
      map_ts="$(_git_last_commit_ts "$mapf")"
      map_hash="$(_git_last_commit_hash "$mapf")"
      [ -z "$map_ts" ] && continue
      checked=$((checked+1))

      # Same commit → синхронный PR-couple → не stale
      [ -n "$comp_hash" ] && [ "$comp_hash" = "$map_hash" ] && continue

      # Компонент строго новее карты → stale
      if [ "$comp_ts" -gt "$map_ts" ] 2>/dev/null; then
        stale=$((stale+1))
        if [ "$sev" = "ERROR" ]; then
          ERRORS=$((ERRORS+1))
          printf '[ERROR] map-staleness: %s изменён позже чем %s — сверь стрелки/labels (диаграмма могла отстать от логики)\n' \
            "$comp" "$(basename "$mapf")"
          MISSING_LIST="${MISSING_LIST}map-staleness:${comp} → $(basename "$mapf")\n"
        else
          WARNINGS=$((WARNINGS+1))
          printf '[WARN]  map-staleness: %s изменён позже чем %s — сверь стрелки/labels (диаграмма могла отстать от логики)\n' \
            "$comp" "$(basename "$mapf")"
        fi
      fi
    done
  done < "$lar"

  printf '[INFO]  map-staleness: %d пар проверено, %d stale, %d пропущено (untracked/git-miss)\n' \
    "$checked" "$stale" "$skipped"
}

# ── Negative-gate: no script-nodes in USER-MAP mermaid blocks (G-116) ────────
#
# Scans ONLY content inside ```mermaid ... ``` fences (not markdown tables/text).
# Pattern: node label contains ".sh" or ".py" (script filename in a mermaid node def).
# Mermaid node definition patterns: ID["label"] ID(label) ID{label} ID[label]
# We look for .sh/.py inside node label strings — not in edge labels (|".."|).
# False-positive guard: affordance nodes may reference "bash scripts/..." in label
#   but that is intentional for text-section pointers only; the negative check catches
#   actual script-node IDs being defined (e.g. Init["🚀 new-project-init.sh"]).
# Safe-list: none needed — affordance nodes with scripts in label should use /command
#   references instead (that's the whole point of this rule).

_check_user_map_no_scripts() {
  local mapfile="$1"
  local severity="$2"   # ERROR or WARN

  if [ -z "$mapfile" ] || [ ! -f "$mapfile" ]; then
    return
  fi

  local in_block=0
  local block_num=0
  local findings=0
  local file_content
  file_content="$(tr -d '\r' < "$mapfile")"

  while IFS= read -r line; do
    case "$line" in
      '```mermaid'*)
        in_block=1
        block_num=$((block_num+1))
        continue
        ;;
      '```')
        if [ "$in_block" -eq 1 ]; then
          in_block=0
        fi
        continue
        ;;
    esac

    [ "$in_block" -eq 0 ] && continue

    # Inside mermaid block: look for node label definitions containing .sh or .py
    # Only flag node definition lines: NodeId["label with .sh"] — not edge-only lines
    # where .sh is only inside |"edge label"| pipe-labels.
    # Heuristic: strip edge labels first, then check if .sh/.py remains.

    case "$line" in
      *'.sh'*|*'.py'*)
        # Strip edge labels (|".."|) from line — scripts in edge labels are not node defs
        stripped="$(printf '%s' "$line" | sed 's/|"[^"]*"//g' | sed "s/|'[^']*'//g")"
        case "$stripped" in
          *'.sh'*|*'.py'*)
            findings=$((findings+1))
            script_ref="$(printf '%s' "$line" | grep -oE '[a-zA-Z0-9_.-]+\.(sh|py)' | head -1)"
            if [ "$severity" = "ERROR" ]; then
              ERRORS=$((ERRORS+1))
              printf '[ERROR] USER-MAP script-node: "%s" в mermaid-блоке #%d — ' \
                "$script_ref" "$block_num"
              printf 'нарушение command-first инварианта. Заменить на /command или affordance-узел.\n'
              MISSING_LIST="${MISSING_LIST}script-node:${script_ref} (USER-MAP mermaid)\n"
            else
              WARNINGS=$((WARNINGS+1))
              printf '[WARN]  USER-MAP script-node: "%s" в mermaid-блоке #%d — ' \
                "$script_ref" "$block_num"
              printf 'command-first инвариант: заменить на /command или affordance-узел.\n'
            fi
            ;;
        esac
        ;;
    esac
  done << _MAP_CONTENT_EOF
$file_content
_MAP_CONTENT_EOF

  printf '[INFO]  USER-MAP/no-scripts: %d script-node(s) found in mermaid blocks\n' "$findings"
}

# mermaid-coverage axis: positive check — each command/skill must appear inside
# a ```mermaid``` fence in USER-MAP (not just anywhere in file).
# Blob support: "/push-merge · /push-only · /pull" counts as covering all three.
# Edge-label stripping: |"/push"| in arrow labels does NOT count as node coverage.
_check_command_in_mermaid() {
  local items="$1"     # newline-separated list of command/skill names
  local mapfile="$2"
  local severity="$3"  # WARN or ERROR

  if [ -z "$mapfile" ] || [ ! -f "$mapfile" ]; then
    return
  fi

  # Extract only content inside ```mermaid``` fences
  local mermaid_content=""
  local in_block=0
  local file_content
  file_content="$(tr -d '\r' < "$mapfile")"

  while IFS= read -r line; do
    case "$line" in
      '```mermaid'*)
        in_block=1
        continue
        ;;
      '```')
        if [ "$in_block" -eq 1 ]; then
          in_block=0
        fi
        continue
        ;;
    esac
    if [ "$in_block" -eq 1 ]; then
      # Strip edge-label segments |"..."| before storing — they must not count
      stripped="$(printf '%s' "$line" | sed 's/|"[^"]*"//g' | sed "s/|'[^']*'//g")"
      mermaid_content="${mermaid_content}
${stripped}"
    fi
  done << _MERMAID_EXTRACT_EOF
$file_content
_MERMAID_EXTRACT_EOF

  local checked=0
  local missed=0

  while IFS= read -r item; do
    [ -z "$item" ] && continue
    checked=$((checked + 1))
    # Search for the item name in extracted mermaid content
    # Item may appear as: /plan  "plan"  plan  or inside blob "· /plan ·"
    local bare_name
    bare_name="$(printf '%s' "$item" | sed 's|^/||')"
    local found=0
    # Commands have leading / in item (e.g. /plan); skills do not (e.g. define-positioning)
    # Search accordingly: commands → must appear as /name, skills → name without slash
    case "$item" in
      /*)
        printf '%s' "$mermaid_content" | grep -qF "/$bare_name" && found=1 || true
        ;;
      *)
        printf '%s' "$mermaid_content" | grep -qF "$bare_name" && found=1 || true
        ;;
    esac
    if [ "$found" -eq 0 ]; then
      missed=$((missed + 1))
      local display_name="$item"
      if [ "$severity" = "ERROR" ]; then
        ERRORS=$((ERRORS + 1))
        printf '[ERROR] mermaid-coverage: %s отсутствует в mermaid-блоках USER-MAP\n' "$display_name"
        MISSING_LIST="${MISSING_LIST}mermaid:${display_name} (USER-MAP)\n"
      else
        WARNINGS=$((WARNINGS + 1))
        printf '[WARN]  mermaid-coverage: %s отсутствует в mermaid-блоках USER-MAP\n' "$display_name"
      fi
    fi
  done << _ITEMS_EOF
$items
_ITEMS_EOF

  printf '[INFO]  mermaid-coverage: %d checked, %d missing from mermaid blocks\n' "$checked" "$missed"
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

# USER-MAP negative-gate: no script-nodes in mermaid blocks (G-116, command-first invariant)
if [ -n "$USER_MAP" ]; then
  NOSCRIPT_SEV="WARN"
  [ "$USER_MAP_NO_SCRIPTS" = "gate" ] && [ -d "commands" ] && NOSCRIPT_SEV="ERROR"
  _check_user_map_no_scripts "$USER_MAP" "$NOSCRIPT_SEV"
fi

# USER-MAP positive mermaid-coverage: commands/skills must appear inside mermaid fences (G-119)
if [ -n "$USER_MAP" ] && [ "$USER_MAP_MERMAID_COVERAGE" != "off" ]; then
  MERMAID_SEV="WARN"
  [ "$USER_MAP_MERMAID_COVERAGE" = "gate" ] && [ -d "commands" ] && MERMAID_SEV="ERROR"
  _check_command_in_mermaid "$ALL_COMMANDS" "$USER_MAP" "$MERMAID_SEV"
  if printf '%s' "$USER_MAP_CHECK" | grep -q 'skills'; then
    _check_command_in_mermaid "$SKILLS" "$USER_MAP" "$MERMAID_SEV"
  fi
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

# Diagram freshness (PLAN-H)
_check_diagram_freshness

# Node readability (v5.57.0, G-121)
_check_node_readability

# Map content-staleness (v6.1.0, closes /diagnose root cause — diagram-content drift)
_check_map_staleness

echo ""
echo "=== Summary: ${ERRORS} error(s), ${WARNINGS} warning(s) ==="

if [ "$ERRORS" -gt 0 ] && [ "$MODE" = "gate" ]; then
  echo ""
  echo "BLOCKED: добавь недостающие строки в карты и повтори деплой."
  printf '%b' "$MISSING_LIST"
  exit 1
fi

exit 0
