"""
SessionStart hook — auto-detects current model and writes session-model.json.

Reads 'model' field from SessionStart payload (not guaranteed: may be absent after
/clear, resume, compact). Falls back to transcript_path scan. Marks stale if absent.

Output: .claude/state/session-model.json
Schema: {model, tier, source, stale, detected_at, session_id}

Commands read this file in Pre-flight as a model-tier hint (stale=false → skip
asking user; stale=true → treat as hint only, confirm with user as before).

Tier normalization: substring-match on model string (version-resilient — new
model names like opus-4.9 / sonnet-5.0 still match; only update TIER_MAP when
Anthropic introduces a new family name).

Always exits 0 — non-blocking side-effect hook.
"""
import json
import os
import sys
from datetime import datetime, timezone

STATE_PATH = os.path.join(".claude", "state", "session-model.json")

# Substring-match tier mapping (version-resilient).
# Order: longer/more-specific fragments first to avoid false matches.
# Update only when Anthropic introduces a new model FAMILY name.
TIER_MAP = [
    ("fable", "Capable"),   # Fable 5 = top-tier
    ("opus", "Capable"),
    ("sonnet", "Default"),
    ("haiku", "Fast"),
]


def detect_tier(model_str):
    """Map model identifier to methodology tier via substring match."""
    if not model_str:
        return "Unknown"
    lower = model_str.lower()
    for fragment, tier in TIER_MAP:
        if fragment in lower:
            return tier
    return "Unknown"


def scan_transcript(transcript_path):
    """Fallback: scan last 50 lines of transcript JSONL for a model field.

    The transcript is a JSONL file — each line is one Claude Code event.
    Scans in reverse so we find the most recent model reference first.
    Returns model string or None.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    try:
        with open(transcript_path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()[-50:]
        for line in reversed(lines):
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                # Try common transcript event schemas
                m = (entry.get("model")
                     or (entry.get("message") or {}).get("model")
                     or (entry.get("response") or {}).get("model"))
                if m and isinstance(m, str):
                    return m
            except Exception:
                continue
    except Exception:
        pass
    return None


def main():
    try:
        raw = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    session_id = data.get("session_id", "")
    transcript_path = data.get("transcript_path")

    # Primary: model field from SessionStart payload
    model = data.get("model")
    source = "startup"
    stale = False

    if not model:
        # Fallback 1: scan transcript for last known model
        model = scan_transcript(transcript_path)
        if model:
            source = "transcript"
        else:
            # Fallback 2: mark stale — commands will ask user as before
            stale = True
            source = "absent"

    tier = detect_tier(model)

    state = {
        "model": model,
        "tier": tier,
        "source": source,
        "stale": stale,
        "detected_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "session_id": session_id,
    }

    try:
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        with open(STATE_PATH, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
