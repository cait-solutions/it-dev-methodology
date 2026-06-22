"""
TEMPORARY probe hook — dumps full hook payload to .claude/state/probe.log.
Purpose: verify SessionStart/UserPromptSubmit payload fields before building model-detect.

Checklist (verify in probe.log after one session):
  - model_present: is 'model' key in SessionStart payload?
  - model_value: format (e.g. "claude-sonnet-4-6" or "claude-opus-4-8[1m]"?)
  - model_after_clear: model absent after /clear? (stale-flag needed)
  - effort_present: is 'effort' or 'effort.level' in payload? (bonus signal)
  - prompt_raw: in UserPromptSubmit — literal user text or expanded skill content?

REMOVE from settings.json after verification session. Not for permanent deployment.

Always exits 0 — non-blocking.
"""
import json
import os
import sys
from datetime import datetime, timezone

LOG_PATH = os.path.join(".claude", "state", "probe.log")


def main():
    try:
        raw = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    except Exception:
        raw = ""

    entry = {
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "raw_len": len(raw),
    }

    try:
        data = json.loads(raw) if raw.strip() else {}
        entry["keys"] = sorted(data.keys())
        # Fields of interest
        entry["model"] = data.get("model")
        entry["effort"] = data.get("effort")
        entry["thinking"] = data.get("thinking")
        entry["session_id"] = data.get("session_id")
        entry["transcript_path"] = data.get("transcript_path")
        entry["hook_event_name"] = data.get("hook_event_name")
        # UserPromptSubmit specific
        entry["prompt"] = data.get("prompt", "")[:200]
        # Full payload for unknown fields
        entry["full"] = data
    except Exception as e:
        entry["parse_error"] = str(e)
        entry["raw_excerpt"] = raw[:300]

    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
