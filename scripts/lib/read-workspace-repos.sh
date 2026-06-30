#!/usr/bin/env bash
#
# lib/read-workspace-repos.sh — single source of truth for enumerating
# workspace repos from a .code-workspace file. Source-able (no execution on its own).
#
#   usage:  . scripts/lib/read-workspace-repos.sh
#           read_workspace_repos [config_file]   → emits "abs_path<TAB>agent_branch"
#                                                   per repo on stdout, one per line.
#
# Reads:
#   CLAUDE.local.md ## Consumers   → workspace_file (path to .code-workspace)
#   <each repo>/CLAUDE.local.md ## Branching → agent_branch (default: ai-dev)
#
# Skips the methodology source repo (it-dev-methodology) — pulled via sync, not here.
# Read-only: never fetches, never mutates. Callers do their own git work.
#
# Extracted from consumer-pull.sh (the .code-workspace parser lived only there).
# consumer-pull.sh migrates onto this lib via PLAN-D (lib consolidation pass) —
# until then it keeps its inline copy; this lib is the designated home going forward.
#
# bash 3.2 compatible. Returns via stdout only (no globals leaked except functions).

# Resolve a "## <section>" "<key>:" yaml-ish field from a CLAUDE.local.md-style file.
# Local copy (not sourcing read-local-config.sh) to stay self-contained until PLAN-D
# lands a shared field reader; falls back gracefully if that lib appears later.
_rwr_get_field() {
  local file="$1" section="$2" field="$3" default="$4"
  if [[ ! -f "$file" ]]; then echo "$default"; return; fi
  local value
  value=$(awk "/^## ${section}/{f=1; next} /^## /{f=0} f{print}" "$file" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r')
  echo "${value:-$default}"
}

# Resolve a python interpreter (Windows has only `py`; Linux/mac have python3).
# Mirrors consumer-pull.sh resolver (closes G-097 recurrence).
_rwr_python_bin() {
  local _cmd
  for _cmd in py python3 python; do
    if command -v "$_cmd" >/dev/null 2>&1; then echo "$_cmd"; return 0; fi
  done
  return 1
}

# read_workspace_repos [config_file]
#   config_file defaults to <repo-root>/CLAUDE.local.md (repo-root = lib's grandparent).
# Emits one line per non-methodology repo:  <abs_path>\t<agent_branch>
# Exit 1 (with diagnostic on stderr) if workspace cannot be resolved/parsed.
read_workspace_repos() {
  local self_dir repo_root config
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$self_dir/../.." && pwd)"
  config="${1:-${repo_root}/CLAUDE.local.md}"

  local ws_rel ws_file
  ws_rel=$(_rwr_get_field "$config" "Consumers" "workspace_file" "")
  if [[ -n "$ws_rel" ]]; then
    ws_file="$(cd "$repo_root" && cd "$(dirname "$ws_rel")" 2>/dev/null && pwd)/$(basename "$ws_rel")"
  else
    ws_file=$(ls "$repo_root"/../*.code-workspace 2>/dev/null | head -1 || true)
  fi

  if [[ -z "$ws_file" || ! -f "$ws_file" ]]; then
    echo "read_workspace_repos: .code-workspace not found (set workspace_file in CLAUDE.local.md ## Consumers)" >&2
    return 1
  fi

  local py
  py=$(_rwr_python_bin) || {
    echo "read_workspace_repos: no python found (tried py, python3, python)" >&2
    return 1
  }

  local repos_raw
  repos_raw=$("$py" -c "
import json, sys, pathlib
ws = pathlib.Path(sys.argv[1])
ws_dir = ws.parent
try:
    data = json.loads(ws.read_text(encoding='utf-8'))
except Exception as e:
    print('ERROR:' + str(e), file=sys.stderr); sys.exit(1)
for f in data.get('folders', []):
    print((ws_dir / f['path']).resolve())
" "$ws_file" 2>&1 | tr -d '\r') || {
    echo "read_workspace_repos: failed to parse workspace: $repos_raw" >&2
    return 1
  }

  local methodology_name="it-dev-methodology"
  local repo_path repo_name branch
  while IFS= read -r repo_path; do
    [[ -z "$repo_path" ]] && continue
    [[ ! -d "$repo_path/.git" ]] && continue
    repo_name="$(basename "$repo_path")"
    [[ "$repo_name" == "$methodology_name" ]] && continue
    branch=$(_rwr_get_field "${repo_path}/CLAUDE.local.md" "Branching" "agent_branch" "ai-dev")
    printf '%s\t%s\n' "$repo_path" "$branch"
  done <<< "$repos_raw"
}
