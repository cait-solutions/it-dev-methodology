#!/bin/bash
# scope-view.sh — generate an on-demand Mermaid view of DEFERRED / OUT-OF-SCOPE / uncovered scope.
#
# Aggregates the project's deferred-scope text sources into ONE Mermaid diagram and
# prints a mermaid.live URL. The diagram is DERIVED & DISPOSABLE — it is never written
# to a file, so it cannot drift from the text sources (single source of truth = the files).
#
# Sources parsed (each optional — graceful skip if absent):
#   PRODUCT-GAPS.md                     entries with `Статус: open` / `in-roadmap`
#   AGENT-GAPS.md                       entries with `Статус: open`
#   ROADMAP.md                          sections: Considered, On hold, Arch review
#   .claude/state/triggers.json         recommendations[] with status `proposed` / `proposed-deferred`
#
# Usage:
#   bash scripts/scope-view.sh [--root DIR] [--all] [--print-only]
#     --root DIR     directory holding the gap files (default: . then auto-probe two-repo doc dir)
#     --all          include ALL items (default: only High severity / open — anti node-explosion)
#     --print-only   print the Mermaid code instead of a mermaid.live URL (offline / no-Python)
#
# Exit 0 = produced a view (or "nothing deferred"); Exit 2 = usage error.
# Bash 3.2+ compatible; Python 3.10+ used for parsing + URL (same idiom as validate-mermaid-links.sh).
#
# Closes P-002 (visibility-gap: deferred scope had no visual surface).

set -e

ROOT=""
SHOW_ALL=0
PRINT_ONLY=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)       ROOT="$2"; shift 2 ;;
        --all)        SHOW_ALL=1; shift ;;
        --print-only) PRINT_ONLY=1; shift ;;
        -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

# --- Resolve where the gap files live -------------------------------------------------
# Single-repo (consumer): files are local (root = ".").
# Two-repo (methodology-platform): docs live in ../it-dev-methodology-documentation and the
# code-repo may hold a STALE pre-split copy — so probe the doc-repo FIRST, "." last, to
# avoid a stale local file shadowing the canonical one (CLAUDE.md: doc files live in doc-repo).
# Best practice: the /scope-out command reads doc_repo_path from CLAUDE.local.md and passes
# --root explicitly; this probe is only a fallback when --root is omitted.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$ROOT" ]; then
    for cand in "../it-dev-methodology-documentation" "$SCRIPT_DIR/../../it-dev-methodology-documentation" "."; do
        if [ -f "$cand/PRODUCT-GAPS.md" ] || [ -f "$cand/ROADMAP.md" ]; then
            ROOT="$cand"; break
        fi
    done
    [ -z "$ROOT" ] && ROOT="."
fi

# triggers.json is always in the code repo (current cwd), not the doc repo.
TRIGGERS=".claude/state/triggers.json"
[ -f "$TRIGGERS" ] || TRIGGERS="$ROOT/.claude/state/triggers.json"

PYTHON=""
for _cmd in py python3 python; do
    command -v "$_cmd" >/dev/null 2>&1 && PYTHON="$_cmd" && break
done
if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found (tried: py, python3, python)" >&2
    exit 2
fi

TMPPY="$(mktemp)"
TMPMMD="$(mktemp)"
trap 'rm -f "$TMPPY" "$TMPMMD"' EXIT

cat > "$TMPPY" << 'PYEOF'
import sys, os, re, json

# Windows console defaults to cp1252 → emoji in labels break print(). Force UTF-8.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

root = sys.argv[1]
triggers_path = sys.argv[2]
show_all = sys.argv[3] == "1"

def read(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except (FileNotFoundError, OSError):
        return None

# --- Parse gap-register entries (PRODUCT-GAPS / AGENT-GAPS) ---------------------------
# Entries are separated by `---` lines; each has `Gap-ID:`, `Статус:`, `Severity:` fields.
# We parse only machine-reliable fields via regex; unparseable entries are skipped.
def parse_gaps(text, kind):
    out = []
    if not text:
        return out
    # split into blocks on standalone --- separators
    blocks = re.split(r'\n-{3,}\n', text)
    for b in blocks:
        m_id = re.search(r'Gap-ID:\s*([A-Z]-\d+)', b)
        if not m_id:
            continue
        gid = m_id.group(1)
        m_status = re.search(r'Статус:\s*([a-zA-Z\-]+)', b)
        status = m_status.group(1).lower() if m_status else "open"
        # only open / in-roadmap are "deferred and live"; resolved/wont-fix/addressed excluded
        if status not in ("open", "in-roadmap"):
            continue
        m_sev = re.search(r'Severity:\s*(🔴|🟡|🟢)', b)
        sev = m_sev.group(1) if m_sev else ""
        m_what = re.search(r'(?:Что не покрывает|Что пропустил):\s*(.+)', b)
        what = (m_what.group(1).strip() if m_what else "")[:70]
        out.append({"id": gid, "status": status, "sev": sev, "what": what, "kind": kind})
    return out

# --- Parse ROADMAP sections (free prose → parse by ## / ### headers, not content) ------
def parse_roadmap(text):
    out = []
    if not text:
        return out
    want = ("Considered", "On hold", "Arch review")
    current = None
    for line in text.splitlines():
        h = re.match(r'^##+\s+(.+?)\s*$', line)
        if h:
            title = h.group(1).strip()
            current = title if any(title.lower().startswith(w.lower()) for w in want) else None
            continue
        if current:
            item = re.match(r'^\s*[-*]\s+\*\*(.+?)\*\*', line)  # bold lead = roadmap item title
            if item:
                out.append({"section": current, "title": item.group(1).strip()[:60]})
    return out

# --- Parse triggers.json recommendations[] -------------------------------------------
def parse_recs(path):
    out = []
    text = read(path)
    if not text:
        return out
    try:
        data = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return out  # graceful: malformed JSON → skip
    recs = (data.get("global", {})
                .get("last_architecture_audit", {})
                .get("recommendations", []))
    for r in recs:
        st = str(r.get("status", "")).lower()
        if st in ("proposed", "proposed-deferred", "proposed-speculative"):
            out.append({"id": r.get("id", "R-?"),
                        "summary": str(r.get("summary", ""))[:55],
                        "status": st})
    return out

product_gaps = parse_gaps(read(os.path.join(root, "PRODUCT-GAPS.md")), "product")
agent_gaps   = parse_gaps(read(os.path.join(root, "AGENT-GAPS.md")), "agent")
roadmap      = parse_roadmap(read(os.path.join(root, "ROADMAP.md")))
recs         = parse_recs(triggers_path)

# --- Default filter (anti node-explosion): High severity + open only ------------------
dropped = 0
if not show_all:
    before = len(product_gaps)
    product_gaps = [g for g in product_gaps if g["sev"] == "🔴" or g["status"] == "in-roadmap"]
    dropped += before - len(product_gaps)
    # agent-gaps: keep only open (already filtered); cap to keep overview discipline
    before = len(agent_gaps)
    agent_gaps = agent_gaps[:8]
    dropped += before - len(agent_gaps)

total = len(product_gaps) + len(agent_gaps) + len(roadmap) + len(recs)

def esc(s):
    return s.replace('"', "'").replace("|", "·").replace("\n", " ")

lines = []
lines.append("graph LR")
lines.append("    classDef hi fill:#7f1d1d,stroke:#ef4444,color:#fee2e2")
lines.append("    classDef med fill:#78350f,stroke:#f59e0b,color:#fef3c7")
lines.append("    classDef road fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe")
lines.append("    classDef rec fill:#3b0764,stroke:#a855f7,color:#f3e8ff")
lines.append("    classDef hub fill:#0f172a,stroke:#64748b,color:#e2e8f0")

scope_label = "все" if show_all else "High + in-roadmap"
lines.append('    HUB["🔭 Отложенный scope<br/>фильтр: %s · всего %d"]:::hub' % (scope_label, total))

if product_gaps:
    lines.append('    subgraph PG["📄 Product gaps (не покрыто)"]')
    for g in product_gaps:
        cls = "hi" if g["sev"] == "🔴" else "med"
        lbl = "%s %s<br/>%s" % (g["sev"], g["id"], esc(g["what"]))
        lines.append('        PG_%s["%s"]:::%s' % (g["id"].replace("-", "_"), lbl, cls))
    lines.append("    end")
    lines.append("    HUB --> PG")

if agent_gaps:
    lines.append('    subgraph AG["📋 Agent gaps (open)"]')
    for g in agent_gaps:
        lbl = "%s<br/>%s" % (g["id"], esc(g["what"]))
        lines.append('        AG_%s["%s"]:::med' % (g["id"].replace("-", "_"), lbl))
    lines.append("    end")
    lines.append("    HUB --> AG")

if roadmap:
    lines.append('    subgraph RM["🗺 ROADMAP (отложено)"]')
    for i, r in enumerate(roadmap):
        lbl = "%s<br/>%s" % (r["section"], esc(r["title"]))
        lines.append('        RM_%d["%s"]:::road' % (i, lbl))
    lines.append("    end")
    lines.append("    HUB --> RM")

if recs:
    lines.append('    subgraph RC["🏛 Audit recs (proposed-deferred)"]')
    for r in recs:
        lbl = "%s<br/>%s" % (r["id"], esc(r["summary"]))
        lines.append('        RC_%s["%s"]:::rec' % (r["id"].replace("-", "_"), lbl))
    lines.append("    end")
    lines.append("    HUB --> RC")

if total == 0:
    lines.append('    EMPTY["✅ Нет отложенного scope<br/>(или источники пусты)"]:::hub')
    lines.append("    HUB --> EMPTY")

mermaid = "\n".join(lines)

# meta line for the shell (counts + dropped) on stderr-channel via marker
sys.stderr.write("SCOPE_META total=%d dropped=%d all=%s\n" % (total, dropped, show_all))
print(mermaid)
PYEOF

# Run parser → Mermaid code (stdout = diagram; stderr = SCOPE_META line, harmless)
if ! "$PYTHON" "$TMPPY" "$ROOT" "$TRIGGERS" "$SHOW_ALL" > "$TMPMMD"; then
    echo "ERROR: scope-view parser failed" >&2
    exit 2
fi

if [ "$PRINT_ONLY" = "1" ]; then
    echo '```mermaid'
    cat "$TMPMMD"
    echo '```'
    exit 0
fi

# Wrap into a ```mermaid fence and hand to mermaid-link.py for the pako URL
WRAP="$(mktemp)"
trap 'rm -f "$TMPPY" "$TMPMMD" "$WRAP"' EXIT
{
    echo '```mermaid'
    cat "$TMPMMD"
    echo '```'
} > "$WRAP"

if [ -f "$SCRIPT_DIR/mermaid-link.py" ]; then
    "$PYTHON" "$SCRIPT_DIR/mermaid-link.py" "$WRAP"
else
    echo "⚠️ mermaid-link.py not found — printing Mermaid code instead:" >&2
    echo '```mermaid'
    cat "$TMPMMD"
    echo '```'
fi
