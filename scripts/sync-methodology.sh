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
#   PRESERVE (project-owned):      everything else — CLAUDE.local.md, PRODUCT.md, VISION.md, etc.

set -euo pipefail

# Parse args: optional --print-changed flag (for /push-consumers manifest-commit).
# Usage: sync-methodology.sh <target-project-dir> [--print-changed]
# With --print-changed: after sync, prints a machine-readable manifest of written paths
# to stdout prefixed with "CHANGED:" — one line per file. Used by /push-consumers to
# commit ONLY these exact files (not broad trees), preventing pathspec-overcapture (a17ecc1 class).
PRINT_CHANGED=false
_args=()
for _a in "$@"; do
  case "$_a" in
    --print-changed) PRINT_CHANGED=true ;;
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
  _config_url="$( (grep "^origin_url:" "$TARGET_DIR/CLAUDE.local.md" 2>/dev/null || true) | head -1 | sed 's/^origin_url:[[:space:]]*//' | tr -d '\r')"
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
  if ! head -1 "$f" 2>/dev/null | grep -q "AUTO-GENERATED from methodology-platform"; then
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
    if head -1 "$dest" 2>/dev/null | grep -q "AUTO-GENERATED from methodology-platform"; then
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
  [[ -f "$dest" ]] && old_body="$(tail -n +7 "$dest" 2>/dev/null || true)"
  inject_md_banner "$cmd" "$dest"
  _track_changed ".claude/commands/$name"
  new_body="$(tail -n +7 "$dest" 2>/dev/null || true)"
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
if [[ "$IS_SELF_APPLY" == "true" ]] && [[ -d "$METHODOLOGY_DIR/commands-local" ]]; then
  if compgen -G "$METHODOLOGY_DIR/commands-local/*.md" > /dev/null 2>&1; then
    echo "→ commands-local/ (self-apply only)"
    for cmd in "$METHODOLOGY_DIR"/commands-local/*.md; do
      [[ -f "$cmd" ]] || continue
      name="$(basename "$cmd")"
      dest="$TARGET_DIR/.claude/commands/$name"
      inject_md_banner "$cmd" "$dest"
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
  if [[ "$IS_SELF_APPLY" == "true" ]] && [[ -f "$METHODOLOGY_DIR/commands-local/$name" ]]; then
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
# Hooks — universal infrastructure, always overwrite. Strips .template from
# filename so wiring in settings.json resolves.
#
# NOTE: This will overwrite local fills of docs_reminder.py LIBS dict. If your
# project has filled LIBS, mirror that change in methodology/hooks/docs_reminder.template.py
# before syncing, or keep a project-local docs_reminder_libs.py and import from it.
# ---------------------------------------------------------------------------
if [[ -d "$METHODOLOGY_DIR/templates/.claude/hooks" ]] && compgen -G "$METHODOLOGY_DIR/templates/.claude/hooks/*" >/dev/null; then
  echo "→ hooks/"
  mkdir -p "$TARGET_DIR/.claude/hooks"
  for hook in "$METHODOLOGY_DIR"/templates/.claude/hooks/*; do
    [[ -f "$hook" ]] || continue
    name="$(basename "$hook")"
    dest_name="${name/.template/}"
    dest="$TARGET_DIR/.claude/hooks/$dest_name"
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
# Model tiers registry — canonical reference, always overwrite.
# ---------------------------------------------------------------------------
if [[ -f "$METHODOLOGY_DIR/templates/model-tiers.md" ]]; then
  echo "→ model-tiers/"
  inject_md_banner "$METHODOLOGY_DIR/templates/model-tiers.md" "$TARGET_DIR/.claude/model-tiers.md"
  _track_changed ".claude/model-tiers.md"
  echo "  ✓ model-tiers.md"
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
  check_artifact_subst "RISKS.md"                         "templates/RISKS.template.md"               "$_pname"
  check_artifact_subst "HYPOTHESES.md"                    "templates/HYPOTHESES.template.md"          "$_pname"
  check_artifact_subst "OPEN-QUESTIONS.md"                "templates/OPEN-QUESTIONS.template.md"      "$_pname"
  check_artifact_subst "README.md"                        "templates/README.template.md"              "$_pname"
  check_artifact_subst "AGENTS.md"                        "templates/AGENTS.md.template"              "$_pname"
  check_artifact_subst "AGENT-GAPS.md"                    "templates/AGENT-GAPS.md.template"          "$_pname"
  check_artifact_subst "CODE-GAPS.md"                     "templates/CODE-GAPS.md.template"           "$_pname"
  check_artifact_subst "docs/architecture/SYSTEM-MAP.md"  "templates/SYSTEM-MAP.template.md"          "$_pname"
  check_artifact_subst "docs/product/USER-MAP.md"         "templates/USER-MAP.template.md"            "$_pname"
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
fi

# ---------------------------------------------------------------------------
# .gitignore check: warn if methodology runtime entries are missing.
# Does not auto-modify — consumer owns their .gitignore.
# ---------------------------------------------------------------------------
if [[ "$IS_SELF_APPLY" == "false" ]]; then
  _gi="$TARGET_DIR/.gitignore"
  _required=(".claude/commands/" ".claude/hooks/" ".claude/skills/" ".claude/model-tiers.md" ".claude/.version" ".claude/state/")
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
    echo "⚠️  .gitignore is missing methodology runtime entries."
    echo "   These files are regenerated by sync — committing them creates noise."
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
