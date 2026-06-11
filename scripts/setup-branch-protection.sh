#!/usr/bin/env bash
#
# setup-branch-protection.sh — configure GitHub branch protection for methodology repos.
#
# Closes HIGH-risk «Прямой push в main» (CLAUDE.md § Security).
# Applies: required PR (0 approvals), enforce_admins, no force-push/deletion.
# Code repo: full protection. Doc repo: anti-force-push/deletion only
#   (direct pushes allowed — DEVLOG velocity preserved).
#
# Usage:
#   bash scripts/setup-branch-protection.sh [--verify] [--off] [--dry-run]
#
# Modes:
#   (no flag)   Apply protection to both repos (idempotent PUT).
#   --verify    Check protection status. Exit 0 = protected, 1 = not protected.
#   --off       Remove protection (emergency escape hatch). Requires explicit --yes.
#   --dry-run   Print what would be done without API calls.
#   --yes       Skip interactive confirmation for --off.
#
# Config read from CLAUDE.local.md (current directory):
#   production_branch, integration_branch — protected branch (default: main)
#   origin_url — used to derive owner/repo (default: git remote origin)
#   doc_repo_path — sibling doc repo path (default: ../it-dev-methodology-documentation)
#
# Bash 3.2+ compatible (no ${var,,}, no associative arrays).

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
MODE="apply"
DRY_RUN=false
YES=false
for arg in "$@"; do
  case "$arg" in
    --verify)  MODE="verify" ;;
    --off)     MODE="off" ;;
    --dry-run) DRY_RUN=true ;;
    --yes)     YES=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Read config from CLAUDE.local.md
# ---------------------------------------------------------------------------
CONFIG="CLAUDE.local.md"
_get_field() {
  local field="$1" default="$2"
  if [[ ! -f "$CONFIG" ]]; then echo "$default"; return; fi
  local value
  value=$(awk '/^## Branching/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
    | grep -E "^[[:space:]]*${field}:" | head -1 \
    | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}
_get_remotes_field() {
  local field="$1" default="$2"
  if [[ ! -f "$CONFIG" ]]; then echo "$default"; return; fi
  local value
  value=$(awk '/^## Remotes/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
    | grep -E "^[[:space:]]*${field}:" | head -1 \
    | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

PRODUCTION_BRANCH=$(_get_field "production_branch" "main")
INTEGRATION_BRANCH=$(_get_field "integration_branch" "$PRODUCTION_BRANCH")
PROTECTED_BRANCH="$INTEGRATION_BRANCH"

ORIGIN_URL=$(_get_remotes_field "origin_url" "$(git remote get-url origin 2>/dev/null || true)")
[[ -z "$ORIGIN_URL" ]] && ORIGIN_URL=$(git remote get-url origin 2>/dev/null || true)

DOC_REPO_PATH="$(awk '/^doc_repo_path:/{gsub(/.*doc_repo_path:[[:space:]]*/,""); gsub(/[[:space:]]*#.*/,""); gsub(/\r/,""); print}' "$CONFIG" 2>/dev/null | head -1)"
DOC_REPO_PATH="${DOC_REPO_PATH:-../it-dev-methodology-documentation}"

# ---------------------------------------------------------------------------
# Derive owner/repo from origin URL
# ---------------------------------------------------------------------------
_parse_github_repo() {
  local url="$1"
  case "$url" in
    https://github.com/*)
      local path="${url#https://github.com/}"
      path="${path%.git}"
      echo "$path" ;;
    git@github.com:*)
      local path="${url#git@github.com:}"
      path="${path%.git}"
      echo "$path" ;;
    *)
      echo "" ;;
  esac
}

CODE_REPO=$(_parse_github_repo "$ORIGIN_URL")
if [[ -z "$CODE_REPO" ]]; then
  echo "❌ Cannot parse GitHub owner/repo from origin URL: ${ORIGIN_URL}" >&2
  echo "   Expected: https://github.com/<owner>/<repo> or git@github.com:<owner>/<repo>" >&2
  exit 1
fi

# Doc repo: read origin from its directory if accessible
DOC_REPO=""
if [[ -d "$DOC_REPO_PATH" ]]; then
  DOC_ORIGIN=$(cd "$DOC_REPO_PATH" && git remote get-url origin 2>/dev/null || true)
  DOC_REPO=$(_parse_github_repo "$DOC_ORIGIN")
fi

echo "Repos:"
echo "  code repo : ${CODE_REPO} (branch: ${PROTECTED_BRANCH})"
echo "  doc  repo : ${DOC_REPO:-none/inaccessible} (branch: ${PROTECTED_BRANCH}, anti-force-push only)"
echo ""

# ---------------------------------------------------------------------------
# Pre-flight: gh CLI + account check (closes G-083 pattern)
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI not found. Install: https://cli.github.com/" >&2
  exit 1
fi

OWNER="${CODE_REPO%%/*}"
ACTIVE_ACCOUNT=$(gh api user -q .login 2>/dev/null || echo "")
if [[ "$ACTIVE_ACCOUNT" != "$OWNER" ]]; then
  echo "⚠️  Active gh account: '${ACTIVE_ACCOUNT:-none}', required: '${OWNER}'"
  if gh auth status 2>/dev/null | grep -q "account ${OWNER} "; then
    echo "   Switching..."
    if gh auth switch --user "$OWNER" >/dev/null 2>&1; then
      ACTIVE_ACCOUNT=$(gh api user -q .login 2>/dev/null || echo "")
      echo "   ✅ Switched to ${ACTIVE_ACCOUNT}"
    fi
  else
    echo "   ❌ Account '${OWNER}' not logged in. Run: gh auth login --user ${OWNER}" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Pre-flight: check repo visibility / plan (protection requires public or paid plan)
# ---------------------------------------------------------------------------
_check_repo_plan() {
  local repo="$1"
  local visibility plan
  visibility=$(gh api "repos/${repo}" -q '.visibility' 2>/dev/null || echo "unknown")
  plan=$(gh api "repos/${repo}" -q '.owner.plan.name' 2>/dev/null || echo "unknown")
  if [[ "$visibility" == "private" && ("$plan" == "free" || "$plan" == "") ]]; then
    echo ""
    echo "⚠️  ${repo} is private on a Free plan."
    echo "   Branch protection API may return 403 on private repos with Free plan."
    echo "   Options: make repo public, upgrade to GitHub Pro/Team, or accept risk."
    echo "   Continuing — will fail gracefully if 403."
    echo ""
  fi
}
_check_repo_plan "$CODE_REPO"

# ---------------------------------------------------------------------------
# Protection payloads (bash 3.2: heredoc, not JSON arrays via associative arrays)
# ---------------------------------------------------------------------------
# Code repo: full protection — required PR, 0 approvals, enforce_admins, no force-push/delete
CODE_PROTECTION_JSON='{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false
}'

# Doc repo: minimal — only anti-force-push/deletion (direct pushes still allowed)
DOC_PROTECTION_JSON='{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false
}'

# ---------------------------------------------------------------------------
# _apply_protection <repo> <branch> <json> <label>
# ---------------------------------------------------------------------------
_apply_protection() {
  local repo="$1" branch="$2" json="$3" label="$4"
  local endpoint="repos/${repo}/branches/${branch}/protection"
  echo "▶ ${label}: applying protection on ${repo}:${branch}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] PUT ${endpoint}"
    echo "  payload: ${json}"
    return 0
  fi
  local http_code response
  response=$(gh api --method PUT "$endpoint" --input - <<< "$json" 2>&1) && http_code=0 || http_code=$?
  if [[ $http_code -eq 0 ]]; then
    echo "  ✅ Protection applied"
  else
    echo "  ❌ Failed (exit ${http_code}): ${response}" | head -5
    if echo "$response" | grep -qi "403\|requires upgrade"; then
      echo "  ℹ️  403 — likely Free plan + private repo. See pre-flight warning above."
    fi
    return 1
  fi
}

# ---------------------------------------------------------------------------
# _verify_protection <repo> <branch> <label>
# Returns: 0 = protected, 1 = not protected / error
# ---------------------------------------------------------------------------
_verify_protection() {
  local repo="$1" branch="$2" label="$3"
  local endpoint="repos/${repo}/branches/${branch}/protection"
  local response http_code
  response=$(gh api "$endpoint" 2>&1) && http_code=0 || http_code=$?
  if [[ $http_code -eq 0 ]]; then
    local enforce_admins allow_force_pushes
    enforce_admins=$(echo "$response" | grep -o '"enforce_admins":{[^}]*}' | grep -o '"enabled":[a-z]*' | head -1 | grep -o '[a-z]*$')
    allow_force_pushes=$(echo "$response" | grep -o '"allow_force_pushes":{[^}]*}' | grep -o '"enabled":[a-z]*' | head -1 | grep -o '[a-z]*$')
    echo "  ✅ ${label}: protected (enforce_admins=${enforce_admins:-?}, allow_force_pushes=${allow_force_pushes:-?})"
    return 0
  else
    if echo "$response" | grep -qi "404\|Branch not protected"; then
      echo "  ⚠️  ${label}: NOT protected"
    else
      echo "  ❓ ${label}: verify failed (exit ${http_code}): ${response}" | head -3
    fi
    return 1
  fi
}

# ---------------------------------------------------------------------------
# _remove_protection <repo> <branch> <label>
# ---------------------------------------------------------------------------
_remove_protection() {
  local repo="$1" branch="$2" label="$3"
  local endpoint="repos/${repo}/branches/${branch}/protection"
  echo "▶ ${label}: removing protection on ${repo}:${branch}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] DELETE ${endpoint}"
    return 0
  fi
  local response http_code
  response=$(gh api --method DELETE "$endpoint" 2>&1) && http_code=0 || http_code=$?
  if [[ $http_code -eq 0 ]]; then
    echo "  ✅ Protection removed"
  else
    if echo "$response" | grep -qi "404\|Branch not protected"; then
      echo "  ℹ️  ${label}: already unprotected"
    else
      echo "  ❌ Failed (exit ${http_code}): ${response}" | head -3
      return 1
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
case "$MODE" in

  apply)
    echo "▶ Applying branch protection..."
    echo ""
    _apply_protection "$CODE_REPO" "$PROTECTED_BRANCH" "$CODE_PROTECTION_JSON" "code-repo"
    if [[ -n "$DOC_REPO" ]]; then
      echo ""
      _apply_protection "$DOC_REPO" "$PROTECTED_BRANCH" "$DOC_PROTECTION_JSON" "doc-repo"
    else
      echo "  ℹ️  doc-repo not accessible from ${DOC_REPO_PATH}, skipping"
    fi
    echo ""
    echo "✅ Done. Verify: bash scripts/setup-branch-protection.sh --verify"
    echo ""
    echo "ℹ️  Next steps:"
    echo "   1. Run a test: git push origin main  → should be rejected (GH006)"
    echo "   2. Normal deploy-push.sh still works (creates PR → merge, 0 approvals)"
    echo "   3. Emergency bypass: bash scripts/setup-branch-protection.sh --off --yes"
    ;;

  verify)
    echo "▶ Verifying branch protection..."
    echo ""
    CODE_OK=0
    DOC_OK=0
    _verify_protection "$CODE_REPO" "$PROTECTED_BRANCH" "code-repo" || CODE_OK=1
    if [[ -n "$DOC_REPO" ]]; then
      _verify_protection "$DOC_REPO" "$PROTECTED_BRANCH" "doc-repo" || DOC_OK=1
    else
      echo "  ℹ️  doc-repo not accessible, skipping"
    fi
    echo ""
    if [[ $CODE_OK -eq 0 ]]; then
      echo "✅ Protection active"
      exit 0
    else
      echo "⚠️  Protection not fully active — run: bash scripts/setup-branch-protection.sh"
      exit 1
    fi
    ;;

  off)
    echo "⚠️  EMERGENCY: removing branch protection from main"
    echo "   This re-opens the HIGH-risk 'Прямой push в main'."
    echo "   Re-apply when done: bash scripts/setup-branch-protection.sh"
    echo ""
    if [[ "$YES" != "true" ]]; then
      printf "   Confirm removal (yes/no): "
      read -r confirm
      if [[ "$confirm" != "yes" ]]; then
        echo "   Aborted."
        exit 0
      fi
    fi
    _remove_protection "$CODE_REPO" "$PROTECTED_BRANCH" "code-repo"
    if [[ -n "$DOC_REPO" ]]; then
      echo ""
      _remove_protection "$DOC_REPO" "$PROTECTED_BRANCH" "doc-repo"
    fi
    echo ""
    echo "✅ Protection removed. Re-apply when done."
    ;;
esac
