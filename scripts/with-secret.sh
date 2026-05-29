#!/usr/bin/env bash
#
# with-secret.sh — inject secret(s) from .env into subprocess env, run command.
#
# This is the PRIMARY tool agents should use when they need a secret.
# Values NEVER touch stdout — they are passed as environment variables to the
# subprocess only. The agent sees the subprocess's stdout/stderr, not the secret.
#
# Usage:
#   bash scripts/with-secret.sh KEY [KEY2 ...] -- <command> [args...]
#
# Examples:
#   bash scripts/with-secret.sh GITHUB_PAT -- git push origin ai-dev
#   bash scripts/with-secret.sh AWS_ACCESS_KEY AWS_SECRET -- aws s3 ls
#
# Lookup priority (first match wins):
#   1. ./.env                                 (per-project)
#   2. ~/.config/it-dev/secrets.env           (shared)
#   3. process environment                    (CI/CD)
#
# Exit codes:
#   0 — command ran (its own exit code is returned)
#   1 — MISSING_SECRET (one or more keys not found; prints how_to_obtain)
#   2 — usage error (missing -- separator or no command)
#   3 — file permission / infra error
#
# Bash 3.2 compatible (Git Bash on Windows).

set -euo pipefail

usage() {
  echo "Usage: bash scripts/with-secret.sh KEY [KEY2 ...] -- <command> [args...]" >&2
  echo "" >&2
  echo "Injects secrets as env vars for subprocess; values never appear in stdout." >&2
  exit 2
}

# Parse args: collect KEYs until '--', then everything else is the command.
keys=()
cmd=()
parsing_keys=true
saw_separator=false
for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    parsing_keys=false
    saw_separator=true
    continue
  fi
  if $parsing_keys; then
    keys+=("$arg")
  else
    cmd+=("$arg")
  fi
done

if [[ ${#keys[@]} -eq 0 ]] || ! $saw_separator || [[ ${#cmd[@]} -eq 0 ]]; then
  usage
fi

SHARED_ENV="${HOME}/.config/it-dev/secrets.env"

MANIFEST=".claude/secrets-manifest.yaml"
if [[ -f "$MANIFEST" ]]; then
  custom_shared=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
                  | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
                  | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  if [[ -n "${custom_shared:-}" ]]; then
    SHARED_ENV="${custom_shared/#\~/$HOME}"
  fi
fi

# Look up a single key in priority chain.
# Optional keychain backend (v4.42.0+, closes G-054). Opt-in via manifest
# config `keychain_backend: true`. Platform-conditional: macOS `security`,
# Windows Credential Manager, Linux libsecret (`secret-tool`). Value retrieved
# here is IMMEDIATELY passed to env subprocess — never to this script's stdout.
#
# Why step 0 (before .env): keychain is encrypted-at-rest (stronger than
# plaintext .env). If user opted in AND keychain has the value, prefer it.
# Falls through to .env if keychain unavailable or key absent.
KEYCHAIN_BACKEND="false"
if [[ -f "$MANIFEST" ]]; then
  _kb=$(grep -E "^[[:space:]]*keychain_backend:" "$MANIFEST" 2>/dev/null \
        | head -1 | sed 's/.*keychain_backend:[[:space:]]*//' \
        | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  [[ "$_kb" == "true" ]] && KEYCHAIN_BACKEND="true"
fi

# Keychain service namespace — secrets stored under "it-dev-methodology/<KEY>".
_KEYCHAIN_SERVICE="it-dev-methodology"

_lookup_keychain() {
  local key="$1"
  [[ "$KEYCHAIN_BACKEND" != "true" ]] && return 1
  local value=""
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      # macOS Keychain
      command -v security >/dev/null 2>&1 || return 1
      value=$(security find-generic-password -s "$_KEYCHAIN_SERVICE" -a "$key" -w 2>/dev/null || true)
      ;;
    Linux)
      # libsecret (GNOME keyring / KWallet via Secret Service) — DE-dependent.
      command -v secret-tool >/dev/null 2>&1 || return 1
      value=$(secret-tool lookup service "$_KEYCHAIN_SERVICE" account "$key" 2>/dev/null || true)
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Windows Credential Manager via PowerShell (CredentialManager module
      # not guaranteed; use cmdkey-stored generic credential read via powershell).
      command -v powershell >/dev/null 2>&1 || return 1
      value=$(powershell -NoProfile -Command "
        \$ErrorActionPreference='SilentlyContinue'
        \$c = & cmdkey /list:${_KEYCHAIN_SERVICE}/${key} 2>\$null
        # cmdkey does not return password; fall back to nothing (Windows secure
        # password retrieval requires DPAPI store — out of scope for v4.42.0).
        Write-Output ''
      " 2>/dev/null | tr -d '\r' || true)
      # Windows password retrieval intentionally returns empty — see skill note.
      ;;
    *)
      return 1
      ;;
  esac
  if [[ -n "$value" ]]; then
    echo "$value"
    return 0
  fi
  return 1
}

# WARNING: this function's echo IS the value. It is captured into a variable
# below and IMMEDIATELY passed to env subprocess — never to stdout of this script.
_lookup() {
  local key="$1"
  local value=""

  # Step 0: keychain backend (opt-in, encrypted at-rest).
  if [[ "$KEYCHAIN_BACKEND" == "true" ]]; then
    if value=$(_lookup_keychain "$key"); then
      echo "$value"
      return 0
    fi
  fi

  if [[ -f ".env" ]]; then
    value=$(grep -E "^${key}=" ".env" 2>/dev/null | head -1 \
            | sed -E "s/^${key}=//" \
            | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
    if [[ -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi

  if [[ -f "$SHARED_ENV" ]]; then
    value=$(grep -E "^${key}=" "$SHARED_ENV" 2>/dev/null | head -1 \
            | sed -E "s/^${key}=//" \
            | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
    if [[ -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi

  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"
    return 0
  fi

  return 1
}

_show_how_to_obtain() {
  local key="$1"
  if [[ ! -f "$MANIFEST" ]]; then
    echo "  (no .claude/secrets-manifest.yaml — see methodology docs for setup)" >&2
    return
  fi
  awk -v k="$key" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*how_to_obtain:[[:space:]]*\|/ { capture=1; next }
    capture && /^[[:space:]]{0,4}[a-z_]+:/ { exit }
    capture { print }
  ' "$MANIFEST" >&2
}

env_args=()
missing=()
for key in "${keys[@]}"; do
  if value=$(_lookup "$key"); then
    env_args+=("${key}=${value}")
    # Optional verbose service log (no value disclosure).
    if [[ "${WITH_SECRET_VERBOSE:-}" == "1" && -f "$MANIFEST" ]]; then
      sn=$(awk -v k="$key" '
        $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
        found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
        found && /^[[:space:]]*service_name:[[:space:]]*/ {
          sub(/^[[:space:]]*service_name:[[:space:]]*/, "")
          gsub(/^["'"'"']|["'"'"']$/, "")
          gsub(/[[:space:]]+$/, "")
          print
          exit
        }
      ' "$MANIFEST")
      [[ -n "$sn" ]] && echo "with-secret: injecting $key → $sn" >&2
    fi
  else
    missing+=("$key")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "MISSING_SECRET: ${missing[*]}" >&2
  echo "" >&2
  for key in "${missing[@]}"; do
    echo "How to obtain ${key}:" >&2
    _show_how_to_obtain "$key"
    echo "" >&2
  done
  echo "After setting, no agent will ask for these secrets again in any session." >&2
  exit 1
fi

exec env "${env_args[@]}" "${cmd[@]}"
