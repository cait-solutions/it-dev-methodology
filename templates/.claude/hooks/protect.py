"""
PreToolUse hook for Edit/Write — blocks edits to secrets and deploy scripts.

Wired in .claude/settings.json under "hooks.PreToolUse" with matcher "Edit|Write".
Exit code 2 blocks the tool call; stderr is shown to the user.

Whitelist (checked FIRST): template / example files that look like secrets
but are commit-safe (no real values). E.g. `.env.example`, `.env.example.template`,
`secrets-manifest.yaml.template`. Edits to these are permitted.

Extend the regex lists below for project-specific protected files
(e.g. specific credentials, signing keys, production configs).
"""
import sys
import json
import re

# Whitelist — paths matching these are SAFE to edit (templates, examples,
# methodology scripts that MANAGE secrets but don't contain them).
# Checked BEFORE protected patterns. If matched here, allow the write.
#
# Each entry is INTENTIONALLY narrow — no generic `.md$` patterns, no wildcards
# that could match attacker-contributed files like `secrets-FAKE.template.txt`.
# Adding to this list expands attack surface; review carefully.
WHITELIST_PATTERNS = [
    # exact template filenames
    r'(?:^|[\\/])\.env\.example$',
    r'(?:^|[\\/])\.env\.example\.template$',
    r'(?:^|[\\/])\.env\.[a-z0-9_]+\.template$',
    r'(?:^|[\\/])secrets-manifest\.ya?ml\.template$',
    # deployed manifest (declaration file — committed to git, contains NO values)
    r'(?:^|[\\/])\.claude[\\/]secrets-manifest\.ya?ml$',
    # methodology canonical templates describing secrets (.template.md suffix locks it
    # to methodology's own template files, not arbitrary user .md)
    r'templates[\\/].*-secrets?[^/\\]*\.template\.md$',
    r'templates[\\/]secrets[^/\\]*\.template(?:\.[a-z]+)?$',
    # methodology canonical skill content
    r'skills[\\/]secrets-management[\\/]SKILL\.md$',
    r'skills[\\/]secrets[\\/]SKILL\.md$',
    # methodology scripts that manage secrets (defined-name pattern, no wildcards)
    r'(?:^|[\\/])scripts[\\/]with-secret\.sh$',
    r'(?:^|[\\/])scripts[\\/]set-secret\.sh$',
    r'(?:^|[\\/])scripts[\\/]check-secret\.sh$',
    r'(?:^|[\\/])scripts[\\/]validate-secrets\.sh$',
    r'(?:^|[\\/])scripts[\\/]_get-secret-raw\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-scrub\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-show\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-edit\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-update\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-rollback\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-cleanup-backups\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-delete\.sh$',
    r'(?:^|[\\/])scripts[\\/]secrets-sync-consumers\.sh$',
    r'(?:^|[\\/])scripts[\\/]git-credential-from-env\.sh$',
    r'(?:^|[\\/])scripts[\\/]clone-consumer\.sh$',
    # mirror in templates/scripts/ (consumer-distribution copies)
    r'templates[\\/]scripts[\\/](?:with-secret|set-secret|check-secret|validate-secrets|'
    r'git-credential-from-env|_get-secret-raw|secrets-scrub|secrets-show|secrets-edit|'
    r'secrets-update|secrets-rollback|secrets-cleanup-backups|secrets-delete|secrets-sync-consumers|clone-consumer)\.sh$',
    # hooks that enforce secret protection (canonical + synced runtime)
    r'(?:^|[\\/])hooks[\\/]secrets-guard\.py$',
    r'templates[\\/]\.claude[\\/]hooks[\\/]secrets-guard\.py$',
    # methodology /secrets command
    r'(?:^|[\\/])commands[\\/]secrets\.md$',
    # methodology test harness for secrets
    r'(?:^|[\\/])tests[\\/]test-secrets\.sh$',
    r'(?:^|[\\/])tests[\\/].*-secrets?[^/\\]*\.sh$',
    # ADRs and design docs about secrets architecture (content review via /review)
    r'docs[\\/]adr[\\/].*secrets?[^/\\]*\.md$',
    r'docs[\\/].*[\\/].*secrets?[^/\\]*\.md$',
    # NOTE: CLAUDE.md / CLAUDE_LONG.md / PRODUCT.md are NOT whitelisted globally.
    # Edits to them go through protect.py's secret-pattern check; if they
    # legitimately contain secret-name references (key names, NOT values),
    # the pattern check still permits because we match by FILE PATH only.
    # An agent writing a real token value into CLAUDE.md is then caught by
    # secrets-guard.py at commit time.
]

PROTECTED_PATTERNS = [
    r'\.env$',
    r'\.env\.',
    r'_deploy\.(py|sh|js|rb)$',
    r'_update\.(py|sh|js|rb)$',
    r'credentials',
    r'secret',
    r'\.pem$',
    r'\.key$',
    r'service-account.*\.json$',
    r'gcp-.*\.json$',
    r'aws-.*\.json$',
    r'\.kube/config',
]

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

file_path = (data.get("tool_input") or {}).get("file_path", "")

# Allow whitelisted template/example files first
for pattern in WHITELIST_PATTERNS:
    if re.search(pattern, file_path, re.IGNORECASE):
        sys.exit(0)

for pattern in PROTECTED_PATTERNS:
    if re.search(pattern, file_path, re.IGNORECASE):
        sys.stderr.write(f"BLOCKED: protected file matches /{pattern}/: {file_path}\n")
        sys.stderr.write("If this file is a TEMPLATE (no real values), add a regex to WHITELIST_PATTERNS.\n")
        sys.exit(2)
