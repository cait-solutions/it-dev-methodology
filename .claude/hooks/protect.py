# AUTO-GENERATED from methodology-platform v2.5.0
# Synced: 2026-05-16
# DO NOT EDIT — changes will be overwritten on next sync
# Modify via PR to https://github.com/cait-solutions/it-dev-methodology
# Emergency override: edit locally + open PR within 48h

"""
PreToolUse hook for Edit/Write — blocks edits to secrets and deploy scripts.

Wired in .claude/settings.json under "hooks.PreToolUse" with matcher "Edit|Write".
Exit code 2 blocks the tool call; stderr is shown to the user.

Extend the regex list below for project-specific protected files
(e.g. specific credentials, signing keys, production configs).
"""
import sys
import json
import re

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

for pattern in PROTECTED_PATTERNS:
    if re.search(pattern, file_path, re.IGNORECASE):
        sys.stderr.write(f"BLOCKED: protected file matches /{pattern}/: {file_path}\n")
        sys.exit(2)
