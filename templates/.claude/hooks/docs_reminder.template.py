# --- project-owned fill (preserved on sync) -------------------------------
# Fill with this project's library/source docs. Example:
#   LIBS = {"qdrant-client": "https://python-client.qdrant.tech/"}
LIBS = {}
# --- end project-owned fill -------------------------------------------------

# >>> methodology managed >>>
# DO NOT EDIT inside these markers — overwritten on sync.
# UserPromptSubmit hook — reminds the agent to fetch docs before editing.
import sys

if not LIBS:
    sys.exit(0)

lines = ["📚 Docs check — before editing, fetch the relevant doc:"]
for name, url in LIBS.items():
    lines.append(f"  • {name}: {url}")
lines.append("Use WebFetch on the relevant URL before editing code/content that uses these.")

print("\n".join(lines))
# <<< methodology managed <<<
