"""
UserPromptSubmit hook — reminds the agent to fetch library docs before editing.

Wired in .claude/settings.json under "hooks.UserPromptSubmit". Output is
prepended to the user's prompt as additional context (Claude sees this but
the user does not see it as their own message).

How to use this template:
1. Copy to .claude/hooks/docs_reminder.py (drop the .template).
2. Fill in LIBS with the libraries your project actively uses.
3. Optional: tighten the trigger — currently fires on every prompt.
   For projects that don't always touch library code, gate by file paths
   or by regex over the prompt text.
"""
import json
import sys

# Fill in with this project's library docs.
# Example:
#   LIBS = {
#       "python-telegram-bot 21.x": "https://docs.python-telegram-bot.org/en/stable/",
#       "qdrant-client":            "https://python-client.qdrant.tech/",
#   }
LIBS: dict[str, str] = {}

if not LIBS:
    sys.exit(0)

lines = ["📚 Docs check — before editing library code, fetch the relevant doc:"]
for name, url in LIBS.items():
    lines.append(f"  • {name}: {url}")
lines.append("Use WebFetch on the relevant URL before writing or editing code that uses these libraries.")

print("\n".join(lines))
