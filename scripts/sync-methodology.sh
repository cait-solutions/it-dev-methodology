#!/usr/bin/env bash
#
# sync-methodology.sh — update an existing project's .claude/commands/ (and hooks/agents)
# from this methodology-platform checkout. Run from anywhere; the script locates the
# methodology root via its own path.
#
# Usage:
#   /path/to/methodology-platform/scripts/sync-methodology.sh <target-project-dir>
#
# Self-apply (methodology-platform itself):
#   bash scripts/sync-methodology.sh .
#   Restores .claude/ + checks all artifacts after a fresh clone.
#
# What it does:
#   1. Detects local modifications (commands without AUTO-GENERATED banner) and prompts.
#   2. Overwrites .claude/commands/*.md with banner-prefixed copies from methodology.
#   3. Copies new agent skeletons (existing per-project content is preserved).
#   4. Copies hooks (overwrites — they are universal infrastructure).
#   5. Updates .claude/.version.
#   6. OVERWRITE canonical: CLAUDE.md (with migration to CLAUDE.local.md), docs/adr/_TEMPLATE.md.
#   7. MERGE: triggers.json (new template fields added; existing values preserved).
#   8. PRESERVE (add-only): all project-owned artifacts (PRODUCT.md, VISION.md, etc.).
#
# Artifact taxonomy:
#   OVERWRITE (methodology-owned): commands/, hooks/, model-tiers.md, CLAUDE.md, adr/_TEMPLATE.md
#   MERGE (special):               triggers.json (add new keys), settings.json (wire missing hooks)
#   MANAGED-BLOCK:                 docs_reminder.py — methodology владеет секцией между
#                                  '# >>> methodology managed >>>' markers; fill вне сохраняется.
#                                  Fail-safe: dest без markers → НЕ перезаписывается (warn).
#   PRESERVE (project-owned):      everything else — CLAUDE.local.md, PRODUCT.md, VISION.md, etc.

set -euo pipefail

# Parse args: optional flags (for /push-consumers manifest-commit and auto-update-watchdog).
# Usage: sync-methodology.sh <target-project-dir> [--print-changed] [--auto-commit]
# --print-changed: after sync, prints machine-readable manifest prefixed "CHANGED:".
#   Used by /push-consumers to commit ONLY sync-written files (prevents a17ecc1 class).
# --auto-commit: after sync, auto-commits non-gitignored tracked sync output.
#   Used by auto-update-watchdog (SessionStart) so sync is atomic: apply+commit in one step.
#   Closes P-003: sync applies but doesn't commit → orphaned dirty tree blocks push-consumers.
#   Graceful: skips silently on git error (merge in progress, detached HEAD, nothing to commit).
PRINT_CHANGED=false
AUTO_COMMIT=false
_args=()
for _a in "$@"; do
  case "$_a" in
    --print-changed) PRINT_CHANGED=true ;;
    --auto-commit)   AUTO_COMMIT=true ;;
    *) _args+=("$_a") ;;
  esac
done
set -- "${_args[@]+"${_args[@]}"}"

TARGET_DIR="${1:?Usage: $0 <target-project-dir> [--print-changed]}"
METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Accumulates relative paths (relative to TARGET_DIR) of every file written by sync.
# Populated by _track_changed helper; consumed at end when PRINT_CHANGED=true.
SYNC_CHANGED_FILES=()

_track_changed() {
  # Record a path relative to TARGET_DIR for the manifest.
  # Usage: _track_changed "relative/path/to/file"
  SYNC_CHANGED_FILES+=("$1")
}
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

# Detect self-apply (methodology-platform syncing itself after fresh clone).
IS_SELF_APPLY=false
_target_abs="$(cd "$TARGET_DIR" && pwd)"
_method_abs="$(cd "$METHODOLOGY_DIR" && pwd)"
if [[ "$_target_abs" == "$_method_abs" ]]; then
  IS_SELF_APPLY=true
fi

# Read commands_profile from consumer's CLAUDE.local.md (Branching yaml block).
# commands_profile: full → deliver commands-local/ to this consumer (same as self-apply).
# Use case: doc-repos or designated consumers that need the full maintainer command set.
COMMANDS_PROFILE=""
if [[ -f "$TARGET_DIR/CLAUDE.local.md" ]]; then
  COMMANDS_PROFILE="$(awk '
    /^```yaml/ { in_block=1; next }
    /^```/     { in_block=0; next }
    in_block && /commands_profile:/ {
      val=$0; sub(/^[^:]*:[[:space:]]*/,"",val)
      sub(/[[:space:]]*#.*/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val)
      print val; exit
    }
  ' "$TARGET_DIR/CLAUDE.local.md" 2>/dev/null || true)"
fi
# INCLUDE_LOCAL_CMDS: true when self-apply OR consumer opted into full profile.
INCLUDE_LOCAL_CMDS=false
if [[ "$IS_SELF_APPLY" == "true" ]] || [[ "$COMMANDS_PROFILE" == "full" ]]; then
  INCLUDE_LOCAL_CMDS=true
fi

# ---------------------------------------------------------------------------
# Auto-pull: keep methodology up to date before syncing.
# Skipped for self-apply (methodology IS the source).
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]]; then
  if git -C "$METHODOLOGY_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    if git -C "$METHODOLOGY_DIR" remote get-url origin > /dev/null 2>&1; then
      if [[ -z "$(git -C "$METHODOLOGY_DIR" status --porcelain 2>/dev/null)" ]]; then
        echo "→ Pulling latest methodology from origin/main..."
        if git -C "$METHODOLOGY_DIR" pull --ff-only --quiet origin main 2>/dev/null; then
          VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
          echo "  ✓ Updated to v$VERSION"
        else
          echo "  ⚠️  Auto-pull failed — syncing from local $VERSION"
        fi
      else
        echo "  ⚠️  Methodology repo has local changes — using local $VERSION"
      fi
      echo ""
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Remote URL check: auto-correct origin if CLAUDE.local.md ## Remotes specifies origin_url.
# Helps agents that used a wrong URL after cloning or manual setup.
# ---------------------------------------------------------------------------
if [[ -f "$TARGET_DIR/CLAUDE.local.md" ]]; then
  # Parse origin_url: strip key prefix AND any trailing inline comment ( # ... ) — a
  # filled value that kept the template's comment must not poison the URL (independent
  # clobber path, closes G-???). tr -d '\r' for CRLF.
  _config_url="$( (grep "^origin_url:" "$TARGET_DIR/CLAUDE.local.md" 2>/dev/null || true) | head -1 | sed -e 's/^origin_url:[[:space:]]*//' -e 's/[[:space:]]*#.*$//' -e 's/[[:space:]]*$//' | tr -d '\r')"
  # PLACEHOLDER GUARD (L4 — by construction): an unfilled template value
  # (https://github.com/<owner>/<repo>.git) must NEVER overwrite a real remote.
  # A real git URL can never contain both '<' and '>', so this rejects ALL <...>
  # placeholders, not a brittle literal match. Empty → also skip.
  case "$_config_url" in
    ""|*"<"*">"*)
      _config_url="" ;;
  esac
  if [[ -n "$_config_url" ]] && git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    _current_url="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$_current_url" && "$_current_url" != "$_config_url" ]]; then
      echo "→ Remote URL mismatch detected:"
      echo "  CLAUDE.local.md: $_config_url"
      echo "  Current origin:  $_current_url"
      git -C "$TARGET_DIR" remote set-url origin "$_config_url"
      echo "  ✓ Remote corrected"
      echo ""
    fi
  fi
fi

if [[ ! -d "$TARGET_DIR/.claude" ]]; then
  if [[ "$IS_SELF_APPLY" == "true" ]]; then
    mkdir -p "$TARGET_DIR/.claude/"{commands,agents,rules,state,hooks}
    echo "  (created .claude/ — self-apply on fresh clone)"
  else
    echo "ERROR: $TARGET_DIR/.claude not found."
    echo "       Run new-project-init.sh first to bootstrap the project."
    exit 1
  fi
fi
# commands/ may be absent after fresh clone (gitignored) — create it
if [[ ! -d "$TARGET_DIR/.claude/commands" ]]; then
  mkdir -p "$TARGET_DIR/.claude/commands"
  echo "  (created .claude/commands/ — absent after clone, restoring via sync)"
else
  mkdir -p "$TARGET_DIR/.claude/commands"
fi

echo "Methodology: $VERSION"
echo "Target:      $TARGET_DIR"
echo ""

# ---------------------------------------------------------------------------
# Detect local modifications (commands missing the banner).
# These would be silently overwritten — warn user.
# ---------------------------------------------------------------------------
LOCAL_MODS=()
for f in "$TARGET_DIR"/.claude/commands/*.md; do
  [[ -f "$f" ]] || continue
  # Conflict-markered file = CORRUPTION, not a legit local edit → must be overwritten
  # (self-heal). Без этого banner на line-1 прячется за `<<<<<<< HEAD`, head-1 check
  # ниже классифицирует файл как local-mod → non-interactive sync ПРЕСЕРВИТ порчу →
  # команда остаётся непарсящейся («Unknown command»), plain re-sync не лечит.
  # Ключим на угловые/pipe-маркеры (ровно 7 + пробел/EOL) — bare ======= НЕ трогаем
  # (Markdown setext false-positive), консистентно с secrets-guard.py.
  if grep -qE '^(<{7}|>{7}|\|{7})([[:space:]]|$)' "$f" 2>/dev/null; then
    continue   # вне LOCAL_MODS → попадёт в обычный overwrite-путь → чистая регенерация
  fi
  if ! grep -q "AUTO-GENERATED from methodology-platform" "$f" 2>/dev/null; then
    LOCAL_MODS+=("$(basename "$f")")
  fi
done

if [[ ${#LOCAL_MODS[@]} -gt 0 ]]; then
  echo "⚠️  These commands lack the AUTO-GENERATED banner (manually edited or new):"
  for m in "${LOCAL_MODS[@]}"; do
    echo "    - $m"
  done
  echo ""
  echo "    Sync will OVERWRITE them. If you edited locally, open a PR upstream first:"
  echo "    https://github.com/cait-solutions/it-dev-methodology"
  echo ""
  # Non-interactive guard (closes G-084): auto-update-watchdog hook вызывает sync
  # без TTY → `read` получает EOF → пустой ans → exit 1 → хук пишет ложный
  # last_auto_pull.status="failed" (sync на деле не падал, просто не было кому
  # ответить на prompt). Detect non-TTY и решаем без блокировки:
  #   - SYNC_AUTO_YES=1 → авто-overwrite (явное согласие через env)
  #   - иначе → preserve locally-modified (НЕ overwrite) + продолжить (exit 0)
  # Никогда exit 1 из-за отсутствия TTY.
  if [[ ! -t 0 ]]; then
    if [[ "${SYNC_AUTO_YES:-}" == "1" ]]; then
      echo "    ℹ️  Non-interactive + SYNC_AUTO_YES=1 → overwriting locally-modified files."
    else
      echo "    ℹ️  Non-interactive (no TTY) → PRESERVING locally-modified files (not overwritten)."
      echo "       Для overwrite запусти вручную в терминале или с SYNC_AUTO_YES=1."
      # Исключить locally-modified из перезаписи: пометить чтобы banner-injection их пропустил.
      # (Файлы остаются как есть; sync продолжает с остальными — не ложный сбой.)
      SKIP_LOCAL_MODS=1
    fi
  else
    printf "Continue and overwrite? [y/N] "
    read -r ans
    ans_lower="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
    if [[ "$ans_lower" != "y" ]]; then
      echo "Aborted."
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Banner injection — picks comment syntax by file extension.
# ---------------------------------------------------------------------------
inject_md_banner() {
  local src="$1"
  local dest="$2"
  {
    cat <<EOF
<!-- AUTO-GENERATED from methodology-platform $VERSION -->
<!-- Synced: $SYNCED_AT -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->

EOF
    cat "$src"
  } > "$dest"
}

# inject_cmd_banner: command files get YAML frontmatter on line 1 (required by
# Claude Code VSCode extension for command discovery / autocomplete). Banner
# goes AFTER frontmatter. Description is auto-extracted from the H1 heading.
inject_cmd_banner() {
  local src="$1"
  local dest="$2"
  local title
  title="$(grep -m1 '^# ' "$src" | sed 's|^# /[^ ]* — ||; s|^# ||')"
  [[ -z "$title" ]] && title="$(basename "$src" .md)"
  title="${title//\"/}"
  {
    cat <<EOF
---
description: "$title"
---
<!-- AUTO-GENERATED from methodology-platform $VERSION -->
<!-- Synced: $SYNCED_AT -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->

EOF
    cat "$src"
  } > "$dest"
}

inject_py_banner() {
  local src="$1"
  local dest="$2"
  {
    cat <<EOF
# AUTO-GENERATED from methodology-platform $VERSION
# Synced: $SYNCED_AT
# DO NOT EDIT — changes will be overwritten on next sync
# Modify via PR to https://github.com/cait-solutions/it-dev-methodology
# Emergency override: edit locally + open PR within 48h

EOF
    cat "$src"
  } > "$dest"
}

# ---------------------------------------------------------------------------
# MANAGED-BLOCK режим (4-й в taxonomy наряду с OVERWRITE/MERGE/PRESERVE).
#
# Методология владеет ТОЛЬКО содержимым между markers; всё вне сохраняется.
# Fail-safe: если dest существует БЕЗ markers — НЕ перезаписывать (warn).
# Если dest отсутствует — записать целиком из template (markers уже в template).
#
# Marker-синтаксис (Python): строки-комментарии
#   # >>> methodology managed >>>
#   ... (methodology-owned)
#   # <<< methodology managed <<<
# Всё вне пары markers — project-owned fill, сохраняется дословно.
#
# Bash 3.2: awk-извлечение, без bash-4 features, без PCRE.
# ---------------------------------------------------------------------------
MB_OPEN='# >>> methodology managed >>>'
MB_CLOSE='# <<< methodology managed <<<'

# _mb_has_markers FILE → exit 0 если обе marker-строки присутствуют.
_mb_has_markers() {
  grep -qF "$MB_OPEN" "$1" 2>/dev/null && grep -qF "$MB_CLOSE" "$1" 2>/dev/null
}

# sync_managed_block SRC DEST DEST_REL
#   SRC      — template (содержит markers + methodology-owned секцию)
#   DEST     — целевой файл у консьюмера
#   DEST_REL — путь для _track_changed / логов
sync_managed_block() {
  local src="$1" dest="$2" dest_rel="$3"

  if [[ ! -f "$dest" ]]; then
    # Нет файла → первичная установка целиком из template (markers + fill-зона внутри).
    cp "$src" "$dest"
    _track_changed "$dest_rel"
    echo "  ✓ $dest_rel (managed-block — created)"
    return
  fi

  if ! _mb_has_markers "$dest"; then
    # FAIL-SAFE: файл есть, но markers нет → НЕ перезаписывать. Возможен
    # заполненный консьюмером fill — clobber потеряет его. Warn + skip.
    echo "  ⚠️  $dest_rel (managed-block — markers ОТСУТСТВУЮТ → preserved, NOT overwritten)"
    echo "      → файл заполнен до managed-block эпохи. Запусти /sync-audit (Gap 18)"
    echo "        чтобы безопасно добавить markers и получать обновления managed-секции."
    return
  fi

  # Markers есть → заменить ТОЛЬКО methodology-секцию из template, fill вне сохранить.
  # Стратегия: взять project-owned части dest (before-open + after-close),
  # methodology-секцию (open..close включительно) — из template.
  local tmp
  tmp="$(mktemp)"
  # part before MB_OPEN (project-owned head):
  awk -v o="$MB_OPEN" 'index($0,o){exit} {print}' "$dest" > "${tmp}.before"
  # part after MB_CLOSE (project-owned tail):
  awk -v c="$MB_CLOSE" 'f{print} index($0,c){f=1}' "$dest" > "${tmp}.after"
  # methodology section from TEMPLATE (open..close inclusive):
  awk -v o="$MB_OPEN" -v c="$MB_CLOSE" 'index($0,o){f=1} f{print} index($0,c){f=0}' "$src" > "${tmp}.method"
  cat "${tmp}.before" "${tmp}.method" "${tmp}.after" > "$dest"
  rm -f "$tmp" "${tmp}.before" "${tmp}.after" "${tmp}.method"
  _track_changed "$dest_rel"
  echo "  ↻ $dest_rel (managed-block — methodology section refreshed, fill preserved)"
}

# inject_skill_banner: copy SKILL.md with banner metadata injected into YAML frontmatter.
# YAML frontmatter MUST stay on line 1 (Agent Skills spec). Banner goes into metadata: block.
# Replaces {{SYNCED_AT}} placeholder in the metadata block.
inject_skill_banner() {
  local src="$1"
  local dest="$2"
  # Replace {{SYNCED_AT}} placeholder with actual date; sed is Bash 3.2 safe.
  sed "s/{{SYNCED_AT}}/$SYNCED_AT/g" "$src" > "$dest"
}

# sync_skills: copy skills/ directory to target .claude/skills/ with banner injection.
# Skipped for self-apply (methodology IS the source).
# Only copies skills/ if the directory exists in methodology.
sync_skills() {
  local target="$1"
  if [[ ! -d "$METHODOLOGY_DIR/skills" ]]; then
    return 0
  fi
  if compgen -G "$METHODOLOGY_DIR/skills/*" > /dev/null 2>&1; then
    echo "→ skills/"
    mkdir -p "$target/.claude/skills"
    for skill_dir in "$METHODOLOGY_DIR/skills"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name="$(basename "$skill_dir")"
      dest_dir="$target/.claude/skills/$skill_name"
      mkdir -p "$dest_dir"
      if [[ -f "$skill_dir/SKILL.md" ]]; then
        inject_skill_banner "$skill_dir/SKILL.md" "$dest_dir/SKILL.md"
        _track_changed ".claude/skills/$skill_name/SKILL.md"
        echo "  ✓ $skill_name/SKILL.md"
      fi
      # Copy any additional files in skill dir (e.g., examples/, README)
      for extra in "$skill_dir"/*; do
        [[ -f "$extra" ]] || continue
        fname="$(basename "$extra")"
        [[ "$fname" == "SKILL.md" ]] && continue
        cp "$extra" "$dest_dir/$fname"
        _track_changed ".claude/skills/$skill_name/$fname"
        echo "  ✓ $skill_name/$fname"
      done
    done
  fi

  # ── skills-local/ — maintainer-only skills (mirror of commands-local/). ──
  # NOT synced to consumers: the glob above iterates skills/* only — skills-local/
  # is a SEPARATE dir, structurally invisible to consumer sync (L4 closedness).
  # ⛔ Если меняешь итерацию skills/ на recursive (find / **/) — добавь явный
  #    exclude skills-local/ (тот же инвариант что commands-local/, см. NOTE в commands section).
  # Copied to .claude/skills/ ТОЛЬКО при self-apply (методология использует свои
  # maintainer-skills) — точно как commands-local/ self-apply блок. README.md в
  # skills-local/ не является skill-dir (это файл) → glob */ его не подхватит → zero scaffolding.
  if [[ "$IS_SELF_APPLY" == "true" ]] && [[ -d "$METHODOLOGY_DIR/skills-local" ]]; then
    if compgen -G "$METHODOLOGY_DIR/skills-local/*/" > /dev/null 2>&1; then
      echo "→ skills-local/ (self-apply only)"
      mkdir -p "$target/.claude/skills"
      for skill_dir in "$METHODOLOGY_DIR/skills-local"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        dest_dir="$target/.claude/skills/$skill_name"
        mkdir -p "$dest_dir"
        if [[ -f "$skill_dir/SKILL.md" ]]; then
          inject_skill_banner "$skill_dir/SKILL.md" "$dest_dir/SKILL.md"
          _track_changed ".claude/skills/$skill_name/SKILL.md"
          echo "  ✓ $skill_name/SKILL.md (local)"
        fi
        for extra in "$skill_dir"/*; do
          [[ -f "$extra" ]] || continue
          fname="$(basename "$extra")"
          [[ "$fname" == "SKILL.md" ]] && continue
          cp "$extra" "$dest_dir/$fname"
          _track_changed ".claude/skills/$skill_name/$fname"
          echo "  ✓ $skill_name/$fname (local)"
        done
      done
    fi
  fi
}

# sync_claude_canonical: overwrite CLAUDE.md with canonical methodology rules.
# On first run: if CLAUDE.md exists without banner, migrate project content to CLAUDE.local.md.
sync_claude_canonical() {
  local dest="$TARGET_DIR/CLAUDE.md"
  local local_dest="$TARGET_DIR/CLAUDE.local.md"
  local src="$METHODOLOGY_DIR/templates/CLAUDE.template.md"
  local src_local="$METHODOLOGY_DIR/templates/CLAUDE_LOCAL.template.md"
  local pname="$(basename "$TARGET_DIR")"

  if [[ ! -f "$src" ]]; then
    echo "  ! CLAUDE.md (template missing — skipped)"
    return
  fi

  if [[ -f "$dest" ]]; then
    if grep -q "AUTO-GENERATED from methodology-platform" "$dest" 2>/dev/null; then
      # Already canonical format — update in place
      inject_md_banner "$src" "$dest"
      _track_changed "CLAUDE.md"
      echo "  ↻ CLAUDE.md (canonical rules updated)"
    else
      # Old-style project: migrate project content to CLAUDE.local.md first
      if [[ ! -f "$local_dest" ]]; then
        cp "$dest" "$local_dest"
        _track_changed "CLAUDE.local.md"
        echo "  ✓ CLAUDE.local.md (migrated project content from CLAUDE.md)"
        echo "    ⚠️  Review CLAUDE.local.md: keep only project-specific sections"
        echo "        (Stack, Architecture invariants, Security threats, Key files, External links)"
      else
        echo "  - CLAUDE.local.md (exists — preserved)"
      fi
      inject_md_banner "$src" "$dest"
      _track_changed "CLAUDE.md"
      echo "  ↻ CLAUDE.md (canonical rules updated — project content in CLAUDE.local.md)"
    fi
  else
    inject_md_banner "$src" "$dest"
    _track_changed "CLAUDE.md"
    echo "  ✓ CLAUDE.md (created canonical)"
    if [[ -f "$src_local" ]]; then
      sed "s/{{Project Name}}/$pname/g" "$src_local" > "$local_dest"
      _track_changed "CLAUDE.local.md"
      echo "  ✓ CLAUDE.local.md (created from template)"
    fi
  fi
}

# merge_triggers_json: add new fields from template to existing triggers.json.
# Existing values are preserved; only new keys from template are added.
# Interpreter-agnostic (closes G-081): резолвит python3|py|python — на Windows
# доступен только `py`, хардкод python3 → merge молча пропускался (новые поля
# triggers.json не подтягивались). Читает с utf-8-sig — BOM от PowerShell-операций
# больше не ломает json.load.
merge_triggers_json() {
  local existing="$TARGET_DIR/.claude/state/triggers.json"
  local template="$METHODOLOGY_DIR/templates/triggers.json.template"

  mkdir -p "$TARGET_DIR/.claude/state"

  if [[ ! -f "$existing" ]]; then
    cp "$template" "$existing"
    _track_changed ".claude/state/triggers.json"
    echo "  ✓ triggers.json (initialized)"
    return
  fi

  local _py=""
  for _cmd in python3 py python; do
    command -v "$_cmd" >/dev/null 2>&1 && _py="$_cmd" && break
  done

  if [[ -n "$_py" ]]; then
    TJ_EXISTING="$existing" TJ_TEMPLATE="$template" "$_py" - <<'PYEOF' || true
import json, os, sys
# Windows cp1252 stdout не кодирует ↻/— → print крашится (тот же класс что в
# merge_settings_json). Форсим utf-8 stdout до любого print.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
try:
    # utf-8-sig: BOM-tolerant (PowerShell-written triggers.json carries EF BB BF)
    with open(os.environ['TJ_EXISTING'], encoding='utf-8-sig') as f:
        existing = json.load(f)
    with open(os.environ['TJ_TEMPLATE'], encoding='utf-8-sig') as f:
        template = json.load(f)
    def deep_merge(t, e):
        if isinstance(t, dict) and isinstance(e, dict):
            result = dict(t)
            for k, v in e.items():
                result[k] = deep_merge(t.get(k, v), v)
            return result
        return e
    merged = deep_merge(template, existing)
    # encoding='utf-8' (без BOM) на запись — нормализуем файл
    with open(os.environ['TJ_EXISTING'], 'w', encoding='utf-8') as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("  ↻ triggers.json (merged new fields from template)")
except Exception as ex:
    print("  ! triggers.json (merge failed: {} — preserved)".format(ex))
PYEOF
  else
    echo "  - triggers.json (Python не найден: tried python3, py, python — preserved; merge new fields manually)"
  fi
}

# merge_settings_json: дозалить ОТСУТСТВУЮЩИЕ hook-вызовы из settings.template.json
# в существующий consumer .claude/settings.json.
#
# WHY (closes mechanism #2 «settings→нет wiring → тихий fail», erp 2026-06-06):
# settings.json синхронизировался как add-only-if-missing (check_artifact) — у живых
# консьюмеров файл уже существует → новое hook-wiring из template НИКОГДА не доезжало
# → методология добавляла hook-файл + wiring в template, consumer получал только ФАЙЛ,
# а его settings.json оставался со старым wiring → hook молча мёртв. Это ПРЯМОЕ
# направление (template→consumer drift); check_hook_health (auto-update-watchdog) ловит
# обратное (settings→missing file). Теперь settings.json = MERGE, как triggers.json.
#
# Merge HOOKS-AWARE, НЕ generic deep_merge: hooks-блок — это массивы matcher-групп;
# concat массивов дублировал бы хуки. Стратегия: presence-check по имени hook-файла
# (run-hook.sh X.py ИЛИ .claude/hooks/X.py) per-event. Отсутствует в consumer → добавить.
# permissions и существующие matcher-группы НЕ трогаются (consumer-кастомизации сохранны).
# Намеренно удалённый консьюмером hook вернётся (accepted risk: methodology-хуки =
# обязательная инфраструктура, settings = MERGE-special в taxonomy).
merge_settings_json() {
  local existing="$TARGET_DIR/.claude/settings.json"
  local template="$METHODOLOGY_DIR/templates/settings.template.json"

  mkdir -p "$TARGET_DIR/.claude"

  if [[ ! -f "$existing" ]]; then
    cp "$template" "$existing"
    echo "  ✓ settings.json (initialized with hooks wiring)"
    return
  fi

  if [[ ! -f "$template" ]]; then
    echo "  - settings.json (template missing — preserved)"
    return
  fi

  local _py=""
  for _cmd in python3 py python; do
    command -v "$_cmd" >/dev/null 2>&1 && _py="$_cmd" && break
  done

  if [[ -n "$_py" ]]; then
    SJ_EXISTING="$existing" SJ_TEMPLATE="$template" "$_py" - <<'PYEOF' || true
import json, os, re, sys
# Windows cp1252 stdout не кодирует ↻/✓/— → print крашится, exception ловится в
# except как «merge failed» (ложно: merge мог УСПЕТЬ записать, упал только print).
# Форсим utf-8 stdout. Py3.7+ reconfigure; guard на случай не-reconfigurable стрима.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

def hook_name(command):
    """Имя hook-файла из command-строки: run-hook.sh X.py, и прямой .claude/hooks/X.(py|sh).
    Dual-pattern + direct .sh — тот же что в hook-consistency check (G-075/G-081/G-087).
    .sh нужен для прямых вызовов без run-hook.sh (напр. hook-liveness.sh — L4 детектор,
    который НЕ может идти через run-hook.sh by design). None если не hook."""
    if not isinstance(command, str):
        return None
    m = re.search(r'run-hook\.sh\s+([A-Za-z0-9._-]+)', command)
    if m:
        return m.group(1)
    m = re.search(r'\.claude/hooks/([A-Za-z0-9._-]+\.(?:py|sh))', command)
    if m:
        return m.group(1)
    return None

def event_hook_names(event_groups):
    """Множество имён hook-файлов уже присутствующих в consumer-событии."""
    names = set()
    if not isinstance(event_groups, list):
        return names
    for group in event_groups:
        if not isinstance(group, dict):
            continue
        for h in group.get('hooks', []):
            n = hook_name(h.get('command') if isinstance(h, dict) else None)
            if n:
                names.add(n)
    return names

try:
    # utf-8-sig: BOM-tolerant (PowerShell-written settings.json carries EF BB BF)
    with open(os.environ['SJ_EXISTING'], encoding='utf-8-sig') as f:
        existing = json.load(f)
    with open(os.environ['SJ_TEMPLATE'], encoding='utf-8-sig') as f:
        template = json.load(f)

    t_hooks = template.get('hooks', {})
    if not isinstance(t_hooks, dict):
        raise ValueError("template.hooks не объект")

    # Гарантировать наличие hooks-блока в consumer (старый формат без него — edge).
    e_hooks = existing.setdefault('hooks', {})
    if not isinstance(e_hooks, dict):
        raise ValueError("consumer settings.hooks не объект — не трогаю")

    added = []
    for event, t_groups in t_hooks.items():
        if not isinstance(t_groups, list):
            continue
        e_groups = e_hooks.setdefault(event, [])
        if not isinstance(e_groups, list):
            continue
        present = event_hook_names(e_groups)
        # Собрать недостающие hook-команды из template для этого события.
        for t_group in t_groups:
            if not isinstance(t_group, dict):
                continue
            missing_hooks = []
            for h in t_group.get('hooks', []):
                n = hook_name(h.get('command') if isinstance(h, dict) else None)
                if n and n not in present:
                    missing_hooks.append(h)
                    present.add(n)  # анти-дубль в пределах одного прогона
                    added.append("{}:{}".format(event, n))
            if missing_hooks:
                # Найти existing-группу с тем же matcher → дописать туда; иначе новая группа.
                t_matcher = t_group.get('matcher')
                target = None
                for g in e_groups:
                    if isinstance(g, dict) and g.get('matcher') == t_matcher:
                        target = g
                        break
                if target is None:
                    new_group = {}
                    if t_matcher is not None:
                        new_group['matcher'] = t_matcher
                    new_group['hooks'] = list(missing_hooks)
                    e_groups.append(new_group)
                else:
                    target.setdefault('hooks', []).extend(missing_hooks)

    if added:
        # encoding='utf-8' (без BOM) на запись — нормализуем файл
        with open(os.environ['SJ_EXISTING'], 'w', encoding='utf-8') as f:
            json.dump(existing, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print("  ↻ settings.json (wired {} hook(s): {})".format(len(added), ", ".join(added)))
    else:
        print("  - settings.json (hooks wiring актуально — нет изменений)")
except Exception as ex:
    print("  ! settings.json (merge failed: {} — preserved)".format(ex))
PYEOF
  else
    echo "  - settings.json (Python не найден: tried python3, py, python — preserved; wire hooks manually)"
  fi
}

# run_migrations: apply pending format/rudiment migrations on the consumer tree
# after files are synced. Closes the "migrations delivered but never run consumer-side"
# class (IDEAS 2026-06-20): sync copied migrations/ but only maintainer /push-consumers
# ran _runner.sh. Now every consumer sync (init + auto-update-watchdog self-sync) applies them.
#
# a17ecc1-safe commit-bridge (per /opinion council 7/7): _runner.sh emits MIGRATED:<path>
# for each HEALED auto-migration → we _track_changed those exact paths → existing
# _auto_commit_sync commits them via EXPLICIT pathspec. NO git-status snapshot-delta
# (that would re-introduce index-overcapture — the council's ❌ verdict).
#
# CONSUMER-ONLY (IS_SELF_APPLY=false): on self-apply this would auto-modify methodology-owned
# artifacts without /review → violates VISION Граница 7 (методология не модифицирует себя
# автоматически). Methodology maintains its own artifacts via /code, not migration self-apply.
#
# Visible, NOT swallowed (`|| true` rejected by council): HEALED/REPORT/runner-exit shown.
# report-mode migrations are NOT auto-applied (runner skips apply) — they surface for a human.
run_migrations() {
  local target="$1"
  local runner="$METHODOLOGY_DIR/scripts/migrations/_runner.sh"
  [[ -f "$runner" ]] || return 0   # старый clone без migrations/ — graceful skip
  echo "→ migrations/"
  local _out _rc
  _out="$(bash "$runner" "$target" 2>&1)"; _rc=$?
  # Видимый вывод (HEALED применено / REPORT требует человека / итог). MIGRATED: — внутренний.
  printf '%s\n' "$_out" | grep -E '^(HEALED|REPORT|MIGRATIONS_DONE)' | sed 's/^/  /' || true
  # Собрать MIGRATED:<path> в манифест → existing _auto_commit_sync закоммитит explicit pathspec.
  while IFS= read -r _line; do
    case "$_line" in
      MIGRATED:*) _track_changed "${_line#MIGRATED:}" ;;
    esac
  done <<EOF
$_out
EOF
  # _runner всегда exit 0 (idempotent contract); ненулевой = инфра-сбой → видимо, не блок sync.
  [[ "$_rc" -ne 0 ]] && echo "  ⚠️  migrations runner exit $_rc — см. вывод выше (sync продолжен)"
  return 0
}

# check_artifact: add file from template if missing; never overwrite.
check_artifact() {
  local dest_rel="$1"
  local src_rel="$2"
  local dest="$TARGET_DIR/$dest_rel"
  local src="$METHODOLOGY_DIR/$src_rel"
  if [[ -f "$dest" ]]; then
    echo "  - $dest_rel (exists — preserved)"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    _track_changed "$dest_rel"
    echo "  ✓ $dest_rel (added from template)"
  else
    echo "  ! $dest_rel (template missing — skipped)"
  fi
}

# check_artifact_subst: same as check_artifact but substitutes {{Project Name}}.
check_artifact_subst() {
  local dest_rel="$1"
  local src_rel="$2"
  local project_name="$3"
  local dest="$TARGET_DIR/$dest_rel"
  local src="$METHODOLOGY_DIR/$src_rel"
  if [[ -f "$dest" ]]; then
    echo "  - $dest_rel (exists — preserved)"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    sed "s/{{Project Name}}/$project_name/g" "$src" > "$dest"
    _track_changed "$dest_rel"
    echo "  ✓ $dest_rel (added from template)"
  else
    echo "  ! $dest_rel (template missing — skipped)"
  fi
}

# ---------------------------------------------------------------------------
# Commands — always overwrite (canonical source is methodology).
#
# NOTE: Glob 'commands/*.md' намеренно НЕ матчит 'commands-local/*.md' —
# папка commands-local/ содержит methodology-only команды (например /pull-consumers)
# которые НЕ должны попадать к консьюмерам. Если меняешь итерацию на recursive
# (find / **/*.md) — добавь явное исключение commands-local/.
# ---------------------------------------------------------------------------
echo "→ commands/"
CHANGED_CMDS=()
for cmd in "$METHODOLOGY_DIR"/commands/*.md; do
  [[ -f "$cmd" ]] || continue
  name="$(basename "$cmd")"
  # G-084: в non-TTY без SYNC_AUTO_YES — не перезаписывать locally-modified файлы.
  if [[ "${SKIP_LOCAL_MODS:-}" == "1" ]]; then
    for _lm in "${LOCAL_MODS[@]}"; do
      if [[ "$_lm" == "$name" ]]; then
        echo "  ~ $name (preserved — locally-modified, non-interactive)"
        continue 2
      fi
    done
  fi
  dest="$TARGET_DIR/.claude/commands/$name"
  old_body=""
  [[ -f "$dest" ]] && old_body="$(tail -n +10 "$dest" 2>/dev/null || true)"
  inject_cmd_banner "$cmd" "$dest"
  _track_changed ".claude/commands/$name"
  new_body="$(tail -n +10 "$dest" 2>/dev/null || true)"
  if [[ "$old_body" != "$new_body" ]]; then
    old_lines=$(echo "$old_body" | wc -l)
    new_lines=$(echo "$new_body" | wc -l)
    delta=$((new_lines - old_lines))
    [[ $delta -gt 0 ]] && delta_str="+${delta}" || delta_str="${delta}"
    echo "  ✓ $name  [${delta_str} строк — изменено содержимое]"
    CHANGED_CMDS+=("$name")
  else
    echo "  ✓ $name"
  fi
done
if [[ ${#CHANGED_CMDS[@]} -gt 0 ]]; then
  echo ""
  echo "  Реальные изменения в содержимом (${#CHANGED_CMDS[@]}):"
  for c in "${CHANGED_CMDS[@]}"; do echo "    • $c"; done
fi

# ---------------------------------------------------------------------------
# Commands-local — ТОЛЬКО при self-apply (methodology-platform = sama консьюмер).
# Consumer projects НЕ получают local commands (это design — см. NOTE выше).
# Без этого блока /pull-consumers и другие maintainer-only команды unusable
# даже в самой methodology-platform (closes G-051).
# ---------------------------------------------------------------------------
if [[ "$INCLUDE_LOCAL_CMDS" == "true" ]] && [[ -d "$METHODOLOGY_DIR/commands-local" ]]; then
  if compgen -G "$METHODOLOGY_DIR/commands-local/*.md" > /dev/null 2>&1; then
    _local_label="self-apply only"
    [[ "$COMMANDS_PROFILE" == "full" ]] && _local_label="commands_profile: full"
    echo "→ commands-local/ ($_local_label)"
    for cmd in "$METHODOLOGY_DIR"/commands-local/*.md; do
      [[ -f "$cmd" ]] || continue
      name="$(basename "$cmd")"
      dest="$TARGET_DIR/.claude/commands/$name"
      inject_cmd_banner "$cmd" "$dest"
      _track_changed ".claude/commands/$name"
      echo "  ✓ $name"
    done
  fi
fi

# Delete commands that no longer exist in methodology (renamed/removed upstream).
# При self-apply также проверяем commands-local/ — иначе следующий sync удалит файл который только что скопировали.
for existing in "$TARGET_DIR"/.claude/commands/*.md; do
  [[ -f "$existing" ]] || continue
  name="$(basename "$existing")"
  exists_canonical=false
  [[ -f "$METHODOLOGY_DIR/commands/$name" ]] && exists_canonical=true
  if [[ "$INCLUDE_LOCAL_CMDS" == "true" ]] && [[ -f "$METHODOLOGY_DIR/commands-local/$name" ]]; then
    exists_canonical=true
  fi
  if [[ "$exists_canonical" == "false" ]]; then
    echo "  ✗ $name (removed upstream — deleting)"
    rm "$existing"
  fi
done

# ---------------------------------------------------------------------------
# Agent skeletons — only copy if missing in target. Per-project bodies are preserved.
# ---------------------------------------------------------------------------
if compgen -G "$METHODOLOGY_DIR/templates/.claude/agents/*.template.md" >/dev/null; then
  echo "→ agents/"
  mkdir -p "$TARGET_DIR/.claude/agents"
  for agent in "$METHODOLOGY_DIR"/templates/.claude/agents/*.template.md; do
    name="$(basename "$agent" .template.md).md"
    dest="$TARGET_DIR/.claude/agents/$name"
    if [[ -f "$dest" ]]; then
      echo "  - $name (preserved — agent body is per-project)"
    else
      cp "$agent" "$dest"
      echo "  ✓ $name (new)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Hooks — universal infrastructure. Strips .template from filename so wiring
# in settings.json resolves.
# Dispatch order: MANAGED-BLOCK (4th taxonomy mode) → extension-based OVERWRITE.
# ---------------------------------------------------------------------------
if [[ -d "$METHODOLOGY_DIR/templates/.claude/hooks" ]] && compgen -G "$METHODOLOGY_DIR/templates/.claude/hooks/*" >/dev/null; then
  echo "→ hooks/"
  mkdir -p "$TARGET_DIR/.claude/hooks"
  # Managed-block хуки: methodology владеет только секцией между markers,
  # per-project fill (напр. docs_reminder LIBS) сохраняется. (4-й режим taxonomy)
  MANAGED_BLOCK_HOOKS="docs_reminder.py"
  for hook in "$METHODOLOGY_DIR"/templates/.claude/hooks/*; do
    [[ -f "$hook" ]] || continue
    name="$(basename "$hook")"
    dest_name="${name/.template/}"
    dest="$TARGET_DIR/.claude/hooks/$dest_name"
    # managed-block ветка (по dest_name):
    case " $MANAGED_BLOCK_HOOKS " in
      *" $dest_name "*)
        sync_managed_block "$hook" "$dest" ".claude/hooks/$dest_name"
        continue ;;
    esac
    case "$name" in
      *.py) inject_py_banner "$hook" "$dest" ;;
      *.md) inject_md_banner "$hook" "$dest" ;;
      *.sh) cp "$hook" "$dest"; chmod +x "$dest" 2>/dev/null || true ;;
      *)    cp "$hook" "$dest" ;;
    esac
    _track_changed ".claude/hooks/$dest_name"
    echo "  ✓ $dest_name"
  done

  # Hook-consistency check (closes G-075 + G-081): каждый hook упомянутый в
  # settings.json ДОЛЖЕН реально присутствовать в .claude/hooks/, И интерпретатор
  # которым он запускается должен быть доступен. Иначе hook падает молча →
  # auto-update/security-хуки мертвы, consumer застревает без предупреждения.
  settings_json="$TARGET_DIR/.claude/settings.json"
  if [[ -f "$settings_json" ]]; then
    # извлечь имена hook-файлов: прямой вызов (.claude/hooks/X — .py И .sh, ловит
    # run-hook.sh + hook-liveness.sh), и через wrapper (run-hook.sh X.py). Зеркало
    # canon auto-update-watchdog.template.py:211-215 — менять синхронно (closes G-087).
    missing_hooks=""
    while IFS= read -r hookfile; do
      [[ -z "$hookfile" ]] && continue
      [[ -f "$TARGET_DIR/.claude/hooks/$hookfile" ]] || missing_hooks="$missing_hooks $hookfile"
    done < <( {
      grep -oE '\.claude/hooks/[A-Za-z0-9_-]+\.(py|sh)' "$settings_json" 2>/dev/null | sed 's#.claude/hooks/##'
      grep -oE 'run-hook\.sh [A-Za-z0-9_-]+\.py' "$settings_json" 2>/dev/null | sed 's#run-hook\.sh ##'
    } | sort -u )
    if [[ -n "$missing_hooks" ]]; then
      echo "  ⚠️  HOOK-MISMATCH: settings.json ссылается на отсутствующие hooks:$missing_hooks"
      echo "      → эти hooks упадут молча при запуске. Проверь templates/.claude/hooks/ содержит их,"
      echo "        либо убери ссылку из settings.json. (closes G-075)"
    fi
    # G-081: если settings.json использует run-hook.sh — он сам резолвит интерпретатор.
    # Но если остался прямой хардкод python3/py/python — предупредить о platform-риске.
    if grep -qE '"command": "(python3|py|python) \.claude/hooks/' "$settings_json" 2>/dev/null; then
      echo "  ⚠️  INTERPRETER-HARDCODE: settings.json вызывает hooks напрямую (python3/py/python)."
      echo "      → на платформе без этого интерпретатора hook упадёт молча. Запусти /sync-audit —"
      echo "        миграция settings-interpreter переведёт на run-hook.sh резолвер. (closes G-081)"
    fi
    # Проверка доступности интерпретатора на текущей платформе:
    _hook_py=""
    for _cmd in python3 py python; do
      command -v "$_cmd" >/dev/null 2>&1 && _hook_py="$_cmd" && break
    done
    if [[ -z "$_hook_py" ]]; then
      echo "  ⚠️  NO-PYTHON: ни python3/py/python не найдены в PATH — ВСЕ хуки методологии"
      echo "      не будут работать. Установи Python 3.10+ (методология требует). (closes G-081)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Skills — always overwrite (canonical source is methodology skills/).
# Runs for self-apply too: .claude/skills/ is the delivery path for Claude Code
# skill auto-activation — even the methodology repo needs it populated.
# ---------------------------------------------------------------------------
sync_skills "$TARGET_DIR"

# ---------------------------------------------------------------------------
# Scripts — universal infrastructure, always overwrite (consumer only).
# Copies templates/scripts/* to target/scripts/. Skipped for self-apply because
# scripts/ in the methodology repo is the canonical source, not a copy.
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]] && [[ -d "$METHODOLOGY_DIR/templates/scripts" ]]; then
  if compgen -G "$METHODOLOGY_DIR/templates/scripts/*" > /dev/null 2>&1; then
    echo "→ scripts/"
    mkdir -p "$TARGET_DIR/scripts"
    for script in "$METHODOLOGY_DIR"/templates/scripts/*; do
      [[ -f "$script" ]] || continue
      name="$(basename "$script")"
      dest="$TARGET_DIR/scripts/$name"
      cp "$script" "$dest"
      chmod +x "$dest" 2>/dev/null || true
      _track_changed "scripts/$name"
      echo "  ✓ $name"
    done
    # Migration registry subdir (Flyway/Alembic-style) — consumers need these
    # locally so /sync-audit can run versioned format-migrations on filled artifacts.
    if [[ -d "$METHODOLOGY_DIR/templates/scripts/migrations" ]]; then
      mkdir -p "$TARGET_DIR/scripts/migrations"
      for mig in "$METHODOLOGY_DIR"/templates/scripts/migrations/*; do
        [[ -f "$mig" ]] || continue
        mdest="$TARGET_DIR/scripts/migrations/$(basename "$mig")"
        cp "$mig" "$mdest"
        chmod +x "$mdest" 2>/dev/null || true
        _track_changed "scripts/migrations/$(basename "$mig")"
        echo "  ✓ migrations/$(basename "$mig")"
      done
    fi
  fi
fi

# ---------------------------------------------------------------------------
# .gitattributes — parallel-safety: union merge-driver for append-heavy logs
# (closes G-117 same-file interleave for worktree/PR path). Idempotent: appends
# any MISSING `merge=union` lines to the consumer's .gitattributes, preserving
# existing entries (never clobbers a hand-managed .gitattributes). Consumer-only:
# self-apply repo already owns its canonical .gitattributes. The `union` driver
# is built into git — no .git/config setup needed.
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]] && [[ -f "$METHODOLOGY_DIR/templates/.gitattributes.template" ]]; then
  dest_ga="$TARGET_DIR/.gitattributes"
  added_ga=0
  while IFS= read -r ga_line; do
    case "$ga_line" in ''|\#*) continue ;; esac          # skip blanks + comments
    if [[ ! -f "$dest_ga" ]] || ! grep -Fqx "$ga_line" "$dest_ga" 2>/dev/null; then
      [[ -f "$dest_ga" ]] || printf '# .gitattributes — managed by it-dev-methodology (parallel-safety: merge=union)\n' > "$dest_ga"
      printf '%s\n' "$ga_line" >> "$dest_ga"
      added_ga=1
    fi
  done < "$METHODOLOGY_DIR/templates/.gitattributes.template"
  if [[ "$added_ga" == "1" ]]; then
    _track_changed ".gitattributes"
    echo "→ .gitattributes (union merge-driver lines ensured)"
  fi
fi

# ---------------------------------------------------------------------------
# Model tiers registry — canonical reference, always overwrite.
# ---------------------------------------------------------------------------
if [[ -f "$METHODOLOGY_DIR/templates/model-tiers.md" ]]; then
  echo "→ model-tiers/"
  inject_md_banner "$METHODOLOGY_DIR/templates/model-tiers.md" "$TARGET_DIR/.claude/model-tiers.md"
  _track_changed ".claude/model-tiers.md"
  echo "  ✓ model-tiers.md"
fi

# ---------------------------------------------------------------------------
# Task types registry — canonical reference, always overwrite.
# ---------------------------------------------------------------------------
if [[ -f "$METHODOLOGY_DIR/templates/task-types.md" ]]; then
  echo "→ task-types/"
  inject_md_banner "$METHODOLOGY_DIR/templates/task-types.md" "$TARGET_DIR/.claude/task-types.md"
  _track_changed ".claude/task-types.md"
  echo "  ✓ task-types.md"
fi

# ---------------------------------------------------------------------------
# .version pointer.
# ---------------------------------------------------------------------------
cat > "$TARGET_DIR/.claude/.version" <<EOF
methodology: $VERSION
synced_at: $SYNCED_AT
source: https://github.com/cait-solutions/it-dev-methodology
EOF
_track_changed ".claude/.version"

# ---------------------------------------------------------------------------
# Artifact coverage — add-only, never overwrite project content.
# Self-apply: restore methodology artifacts (gitignored, absent after clone).
# Consumer: fill any artifact gaps introduced in newer methodology versions.
# ---------------------------------------------------------------------------
echo "→ artifact coverage/"
if [[ "$IS_SELF_APPLY" == "true" ]]; then
  # Restore methodology-platform-specific artifacts after fresh clone.
  if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "  - CLAUDE.md (exists — preserved)"
  elif [[ -f "$METHODOLOGY_DIR/templates/CLAUDE-methodology.template.md" ]]; then
    sed -e "s/{{Project Name}}/methodology-platform/g" \
        -e "s|{{github-url}}|https://github.com/cait-solutions/it-dev-methodology|g" \
        "$METHODOLOGY_DIR/templates/CLAUDE-methodology.template.md" > "$TARGET_DIR/CLAUDE.md"
    echo "  ✓ CLAUDE.md (restored from methodology template)"
  fi
  if [[ -f "$TARGET_DIR/CLAUDE_LONG.md" ]]; then
    echo "  - CLAUDE_LONG.md (exists — preserved)"
  elif [[ -f "$METHODOLOGY_DIR/templates/CLAUDE_LONG-methodology.template.md" ]]; then
    sed -e "s/{{Project Name}}/methodology-platform/g" \
        -e "s|{{github-url}}|https://github.com/cait-solutions/it-dev-methodology|g" \
        "$METHODOLOGY_DIR/templates/CLAUDE_LONG-methodology.template.md" > "$TARGET_DIR/CLAUDE_LONG.md"
    echo "  ✓ CLAUDE_LONG.md (restored from methodology template)"
  fi

  # Dogfood own hook-wiring (closes mechanism #3 «watchdog не запускался»):
  # self-apply раньше НЕ вызывал merge_settings_json (он жил только в consumer-ветке) →
  # own .claude/settings.json методологии оставался без SessionStart wiring →
  # auto-update-watchdog.py НИКОГДА не запускался у самой методологии (sync/sync-audit/
  # check_hook_health спали; last_auto_pull отсутствовал). Методология должна dog-food'ить
  # own delivery: применяем тот же merge к себе. НЕ merge_triggers_json — own triggers.json
  # это runtime state (gitignored), его merge при self-apply конфликтует с активными сессиями.
  echo "  [self-apply — dogfood hook-wiring]"
  merge_settings_json
  _track_changed ".claude/settings.json"
else
  # Consumer project: overwrite canonical artifacts, add missing project-owned artifacts.
  _pname="$(basename "$TARGET_DIR")"

  # --- OVERWRITE: methodology-canonical (always synced with banner) ---
  echo "  [canonical — overwrite]"
  sync_claude_canonical
  # ADR template format evolves with methodology
  if [[ -f "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md" ]]; then
    mkdir -p "$TARGET_DIR/docs/adr"
    inject_md_banner "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md" "$TARGET_DIR/docs/adr/_TEMPLATE.md"
    _track_changed "docs/adr/_TEMPLATE.md"
    echo "  ↻ docs/adr/_TEMPLATE.md (updated)"
  fi

  # --- MERGE: special handling ---
  echo "  [special — merge]"
  merge_triggers_json
  _track_changed ".claude/state/triggers.json"
  merge_settings_json
  _track_changed ".claude/settings.json"

  # --- PRESERVE: project-owned (add-only, never overwrite) ---
  echo "  [project-owned — add if missing]"
  check_artifact_subst "CLAUDE.local.md"                  "templates/CLAUDE_LOCAL.template.md"        "$_pname"
  check_artifact_subst "CLAUDE_LONG.md"                   "templates/CLAUDE_LONG.template.md"         "$_pname"
  check_artifact_subst "VISION.md"                        "templates/VISION.template.md"              "$_pname"
  check_artifact_subst "PRODUCT.md"                       "templates/PRODUCT.template.md"             "$_pname"
  check_artifact_subst "DEVLOG.md"                        "templates/DEVLOG.template.md"              "$_pname"
  check_artifact_subst "IDEAS.md"                         "templates/IDEAS.template.md"               "$_pname"
  check_artifact_subst "ROADMAP.md"                       "templates/ROADMAP.template.md"             "$_pname"
  check_artifact_subst "NORTH-STAR.md"                    "templates/NORTH-STAR.template.md"          "$_pname"
  check_artifact_subst "RISKS.md"                         "templates/RISKS.template.md"               "$_pname"
  check_artifact_subst "HYPOTHESES.md"                    "templates/HYPOTHESES.template.md"          "$_pname"
  check_artifact_subst "OPEN-QUESTIONS.md"                "templates/OPEN-QUESTIONS.template.md"      "$_pname"
  check_artifact_subst "README.md"                        "templates/README.template.md"              "$_pname"
  check_artifact_subst "AGENTS.md"                        "templates/AGENTS.md.template"              "$_pname"
  check_artifact_subst "AGENT-GAPS.md"                    "templates/AGENT-GAPS.md.template"          "$_pname"
  check_artifact_subst "CODE-GAPS.md"                     "templates/CODE-GAPS.md.template"           "$_pname"
  check_artifact_subst "docs/architecture/SYSTEM-MAP.md"         "templates/SYSTEM-MAP.template.md"            "$_pname"
  check_artifact_subst "docs/architecture/LIVING-ARTIFACTS.md"   "templates/LIVING-ARTIFACTS.template.md"      "$_pname"
  check_artifact_subst "docs/product/USER-MAP.md"                "templates/USER-MAP.template.md"              "$_pname"
  check_artifact_subst "docs/product/ARTIFACT-MAP.md"     "templates/ARTIFACT-MAP.template.md"        "$_pname"
  check_artifact_subst "docs/vision/AGENT_VISION.md"      "templates/vision/AGENT_VISION.template.md" "$_pname"
  check_artifact_subst "docs/vision/LONG_VISION_v1.md"    "templates/vision/LONG_VISION.template.md"  "$_pname"
  check_artifact_subst "services-registry.yaml"           "templates/services-registry.template.yaml" "$_pname"
  check_artifact_subst "docs/data-map.md"                 "templates/data-map.template.md"            "$_pname"
  check_artifact_subst "docs/glossary.md"                 "templates/glossary.template.md"            "$_pname"
  check_artifact_subst "docs/BEHAVIOR.md"                 "templates/BEHAVIOR.template.md"            "$_pname"

  # Secrets foundation (Phase 1 / v4.32.0+): never overwrite — these may hold
  # real configuration once filled. .env itself is NEVER created by sync.
  check_artifact_subst ".env.example"                     "templates/.env.example.template"           "$_pname"
  check_artifact_subst ".claude/secrets-manifest.yaml"    "templates/secrets-manifest.yaml.template"  "$_pname"
  check_artifact_subst "docs/adr/README.md"               "templates/adr/README.template.md"              "$_pname"
  check_artifact       "inbox/README.md"                  "templates/inbox/README.template.md"
  check_artifact_subst ".claude/rules/README.md"          "templates/.claude/rules/README.template.md" "$_pname"
  check_artifact_subst "external-sources.md"              "templates/external-sources.template.md"     "$_pname"
fi

# ---------------------------------------------------------------------------
# Migrations — apply pending format/rudiment migrations on consumer tree.
# CONSUMER-ONLY (Граница 7): self-apply не запускает (методология не само-модифицируется авто).
# Размещено ПЕРЕД --auto-commit: MIGRATED:<path> → SYNC_CHANGED_FILES → один manifest-commit.
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]]; then
  run_migrations "$TARGET_DIR"
fi

# ---------------------------------------------------------------------------
# .gitignore check: warn if runtime-LOCAL entries are missing.
# Does not auto-modify — consumer owns their .gitignore.
# NB (v7.8.2): commands/ hooks/ model-tiers.md are now COMMITTED (self-contained clone)
# — they are NO LONGER in this list. Only per-clone/per-developer runtime stays ignored:
#   .claude/.version  — rewritten every sync (per-clone marker)
#   .claude/state/    — per-developer counters
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]]; then
  _gi="$TARGET_DIR/.gitignore"
  _required=(".claude/.version" ".claude/state/")
  _missing=()
  if [[ -f "$_gi" ]]; then
    for entry in "${_required[@]}"; do
      grep -qF "$entry" "$_gi" 2>/dev/null || _missing+=("$entry")
    done
  else
    _missing=("${_required[@]}")
  fi
  if [[ ${#_missing[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  .gitignore is missing methodology runtime-local entries."
    echo "   These are per-clone / per-developer — committing them creates noise."
    echo "   Add to $TARGET_DIR/.gitignore:"
    for m in "${_missing[@]}"; do echo "     $m"; done
  fi
fi

echo ""
echo "✅ Sync complete. Methodology version: $VERSION"

# ---------------------------------------------------------------------------
# --print-changed: emit manifest of written paths (relative to TARGET_DIR).
# Each line prefixed "CHANGED:" for unambiguous machine parsing.
# Consumed by /push-consumers to commit ONLY sync-written files — prevents
# pathspec-overcapture (class a17ecc1): only exact files written, not broad trees.
# ---------------------------------------------------------------------------
if [[ "$PRINT_CHANGED" == "true" ]]; then
  if [[ ${#SYNC_CHANGED_FILES[@]} -gt 0 ]]; then
    for _f in "${SYNC_CHANGED_FILES[@]}"; do
      echo "CHANGED:$_f"
    done
  fi
fi

# ---------------------------------------------------------------------------
# --auto-commit: branch guard (closes sync-on-main class).
# Skips auto-commit when the consumer repo is checked out on its production_branch.
# Root cause: auto-update-watchdog calls --auto-commit at SessionStart regardless
# of current branch → sync commits land on main if consumer started session there.
# Guard: read production_branch from TARGET_DIR/CLAUDE.local.md (default: main),
# compare with current branch. If match → warn to stderr + disable AUTO_COMMIT.
# IS_SELF_APPLY=true is exempt (methodology-platform itself may live on main).
# ---------------------------------------------------------------------------
if [[ "$AUTO_COMMIT" == "true" ]] && [[ "$IS_SELF_APPLY" == "false" ]]; then
  _prod_branch="$( (grep "^production_branch:" "$TARGET_DIR/CLAUDE.local.md" 2>/dev/null || true) \
    | head -1 | sed 's/production_branch:[[:space:]]*//' | sed 's/#.*//' | tr -d '[:space:]\r' )"
  _prod_branch="${_prod_branch:-main}"
  _cur_branch="$(git -C "$TARGET_DIR" branch --show-current 2>/dev/null \
    || git -C "$TARGET_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null \
    || echo "")"
  if [[ -n "$_cur_branch" ]] && \
     { [[ "$_cur_branch" == "$_prod_branch" ]] || [[ "$_cur_branch" == "master" ]]; }; then
    echo "  ⚠️  AUTO-COMMIT SKIPPED: repo is on '${_cur_branch}' (production_branch)." >&2
    echo "     Sync applied (files written). To commit, switch to agent_branch first:" >&2
    echo "     git -C \"$TARGET_DIR\" checkout ai-dev && bash scripts/sync-methodology.sh ." >&2
    AUTO_COMMIT=false
  fi
fi

# ---------------------------------------------------------------------------
# --auto-commit: atomically commit sync output (closes P-003 dirty-tree class).
# Filters gitignored paths (e.g. .claude/commands/ in consumers), stages the rest,
# commits with explicit pathspec — no index-capture (a17ecc1 invariant preserved).
# Graceful: any git error → silent skip (return 0 + || true at call side).
# ---------------------------------------------------------------------------
if [[ "$AUTO_COMMIT" == "true" ]] && [[ ${#SYNC_CHANGED_FILES[@]} -gt 0 ]]; then
  _auto_commit_sync() {
    local _wd
    _wd="$(cd "$TARGET_DIR" && pwd)" || return 0
    # Filter: keep non-gitignored manifest files. Include a path if it exists OR
    # it is tracked-but-deleted (migration git rm — e.g. rudiment removal): такие
    # пути не -f, но их удаление надо закоммитить. Иначе пропускаем (template missing).
    local _to_add=()
    for _f in "${SYNC_CHANGED_FILES[@]}"; do
      git -C "$_wd" check-ignore -q "$_f" 2>/dev/null && continue
      if [ -f "$_wd/$_f" ] || git -C "$_wd" ls-files --error-unmatch -- "$_f" >/dev/null 2>&1; then
        _to_add+=("$_f")
      fi
    done
    [[ ${#_to_add[@]} -eq 0 ]] && return 0
    git -C "$_wd" add -- "${_to_add[@]}" 2>/dev/null || return 0
    # ⛔ EXPLICIT pathspec commit (a17ecc1-safe): коммитим ТОЛЬКО manifest-пути,
    # НЕ весь staged-индекс (прежний `git commit -- $_staged` мог захватить файл,
    # застейдженный параллельной сессией). Если среди _to_add нет staged-изменений →
    # commit вернёт non-zero → || true (нечего коммитить, корректно).
    git -C "$_wd" commit -- "${_to_add[@]}" -m "chore: sync methodology $VERSION" 2>/dev/null \
      && echo "  ✅ auto-commit: sync methodology $VERSION" \
      || true
  }
  _auto_commit_sync || true
fi
