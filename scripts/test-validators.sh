#!/usr/bin/env bash
# test-validators.sh — proof-of-rejection harness (closes G-112 class).
#
# Кормит каждый negative-fixture его валидатору и ASSERT-ит ожидаемый exit.
# Positive-control прогон (assert_exit 0 на чистом входе) ловит «всё всегда падает» вырожденность.
#
# Guard: methodology-platform only ([ -d commands ] && [ -f scripts/sync-methodology.sh ]).
# Consumer не имеет commands/ source-dir → guard false → harness N/A.
#
# Exit 0 = все assertions прошли; Exit 1 = ≥1 assert_exit провалился (false-green).
#
# Fixtures: scripts/fixtures/validators/ (dual-copy в templates/scripts/, кроме parity-divergent/).
# Добавить новый фикстур: см. scripts/fixtures/validators/README.md.
#
# Usage: bash scripts/test-validators.sh
# Вызывается из: deploy-push.sh methodology-gate (после script-parity, перед maps-coverage).

set -u

if [ ! -d "commands" ] || [ ! -f "scripts/sync-methodology.sh" ]; then
  echo "INFO: not methodology-platform — validator harness N/A."
  exit 0
fi

METHODOLOGY_ROOT="$(pwd)"
FX="scripts/fixtures/validators"
FAILS=0
RAN=0
CLEANUP_DIRS=""

_cleanup() {
  for d in $CLEANUP_DIRS; do
    rm -rf "$d"
  done
}
trap _cleanup EXIT

# assert_exit <expected> <label> -- <command...>
assert_exit() {
  local want="$1" label="$2"; shift 2; [ "$1" = "--" ] && shift
  RAN=$((RAN+1))
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" -ne "$want" ]; then
    echo "[FAIL] $label — ожидался exit $want, получен $got (валидатор НЕ ведёт себя как ожидалось)"
    FAILS=$((FAILS+1))
  else
    echo "[ok]   $label — exit $got как ожидалось"
  fi
}

echo "=== test-validators.sh (proof-of-rejection harness) ==="
echo ""

# ── Test 1: triggers-duplicate ──────────────────────────────────────────────────
# validate-triggers.sh должен обнаружить дубль-ключ (global.last_retro + top-level last_retro) → exit 1.
T1="$(mktemp -d)"
CLEANUP_DIRS="$CLEANUP_DIRS $T1"
mkdir -p "$T1/.claude/state"
cp "$FX/triggers-duplicate-key.json" "$T1/.claude/state/triggers.json"
assert_exit 1 "triggers-duplicate" -- bash scripts/validate-triggers.sh --root "$T1"

# ── Test 2: maps-no-scripts ──────────────────────────────────────────────────────
# validate-maps-coverage.sh должен обнаружить .sh-ноду в USER-MAP mermaid-блоке → exit 1.
# Запускаем из корня methodology (где [ -d commands ] → NOSCRIPT_SEV=ERROR).
# --doc-root=$T2 переопределяет где искать карты (CLAUDE.local.md override).
T2="$(mktemp -d)"
CLEANUP_DIRS="$CLEANUP_DIRS $T2"
mkdir -p "$T2/docs/product"
cp "$FX/usermap-with-script-node.md" "$T2/docs/product/USER-MAP.md"
assert_exit 1 "maps-no-scripts" -- bash scripts/validate-maps-coverage.sh "--doc-root=$T2"

# ── Test 3: mermaid-missing-link ────────────────────────────────────────────────
# validate-mermaid-links.sh должен обнаружить mermaid-блок без mermaid.live URL → exit 1.
T3="$(mktemp -d)"
CLEANUP_DIRS="$CLEANUP_DIRS $T3"
cp "$FX/mermaid-missing-link.md" "$T3/test-fixture.md"
assert_exit 1 "mermaid-missing-link" -- bash scripts/validate-mermaid-links.sh --root "$T3"

# ── Test 4: parity-divergent ────────────────────────────────────────────────────
# validate-script-parity.sh должен обнаружить расхождение между scripts/ и templates/scripts/
# в sandbox-поддереве → exit 1.
# Sandbox: parity-divergent/ содержит commands/ + scripts/_fixture_pair.sh + templates/scripts/_fixture_pair.sh
# (намеренно расходящиеся). cd изолирует sandbox-cwd от реального дерева.
RAN=$((RAN+1))
FX_ABS="$(cd "$FX" 2>/dev/null && pwd)"
(cd "$FX_ABS/parity-divergent" && bash "$METHODOLOGY_ROOT/scripts/validate-script-parity.sh") >/dev/null 2>&1
PARITY_EXIT=$?
if [ "$PARITY_EXIT" -ne 1 ]; then
  echo "[FAIL] parity-divergent — ожидался exit 1, получен $PARITY_EXIT"
  FAILS=$((FAILS+1))
else
  echo "[ok]   parity-divergent — exit 1 как ожидалось"
fi

# ── Test 5: delivery-empty-settings ─────────────────────────────────────────────
# validate-delivery.sh должен обнаружить 0 hook-refs в settings.template.json → exit 1.
# Sandbox: delivery-empty-settings/templates/settings.template.json (без hook-refs)
#          delivery-empty-settings/templates/.claude/hooks/ (пустая директория)
assert_exit 1 "delivery-empty-settings" -- bash scripts/validate-delivery.sh --root "$FX/delivery-empty-settings"

# ── Test 6: consumer-delivery orphan ─────────────────────────────────────────────
# validate-consumer-delivery.sh должен обнаружить orphan-скрипт в templates/scripts/
# (нет ссылки в commands/ / hooks/ / др. скрипте) под severity=error → exit 1.
assert_exit 1 "consumer-delivery-orphan" -- env CONSUMER_DELIVERY_SEVERITY=error bash scripts/validate-consumer-delivery.sh --root "$FX/delivery-orphan"

# ── Test 6b: consumer-delivery clean (positive control + allow-marker) ───────────
# Скрипт с `# delivery-allow:` маркером не флагуется → даже под error → exit 0.
assert_exit 0 "consumer-delivery-clean" -- env CONSUMER_DELIVERY_SEVERITY=error bash scripts/validate-consumer-delivery.sh --root "$FX/delivery-clean"

# ── Test 7: migrations-self-apply bridge (a17ecc1-safe) ──────────────────────────
# Consumer-shaped дерево (НЕТ templates/ commands/ — опасный путь, который GUARD
# методологии никогда не проходит на self-apply). Проверяет 3 вещи разом:
#  (1) _runner применяет auto-миграцию в consumer-shaped дереве (GUARD danger-path);
#  (2) migration_changed_paths → _runner эмитит MIGRATED:<path>;
#  (3) explicit-pathspec commit MIGRATED-путей НЕ захватывает parallel-staged файл (a17ecc1).
RAN=$((RAN+1))
T7="$(mktemp -d)"
CLEANUP_DIRS="$CLEANUP_DIRS $T7"
(
  cd "$T7" || exit 9
  git init -q && git config user.email t@t && git config user.name t || exit 9
  mkdir -p docs scripts/migrations
  printf 'OLD-FORMAT\n' > docs/fixture.md
  git add -A && git commit -qm init || exit 9
  # fake auto-migration с migration_changed_paths
  cat > scripts/migrations/v0.0.0-fixture.sh <<'MIG'
MIGRATION_TARGET_VERSION="v0.0.0"; MIGRATION_ID="fixture-transform"; MIGRATION_MODE="auto"
migration_describe(){ echo "fixture"; }
migration_detect(){ grep -q "OLD-FORMAT" "$1/docs/fixture.md" 2>/dev/null; }
migration_apply(){ sed 's/OLD-FORMAT/NEW-FORMAT/' "$1/docs/fixture.md" > "$1/docs/fixture.md.t" && mv "$1/docs/fixture.md.t" "$1/docs/fixture.md"; }
migration_changed_paths(){ echo "docs/fixture.md"; }
MIG
  cp "$METHODOLOGY_ROOT/scripts/migrations/_runner.sh" scripts/migrations/_runner.sh
  # parallel session стейджит неотносящийся файл (a17ecc1-ловушка)
  printf 'parallel-work\n' > docs/PARALLEL.md && git add docs/PARALLEL.md
  # run runner, собрать MIGRATED-пути (как делает sync run_migrations)
  out="$(bash scripts/migrations/_runner.sh . 2>&1)"
  echo "$out" | grep -q "MIGRATED:docs/fixture.md" || { echo "no MIGRATED emit"; exit 1; }
  grep -q "NEW-FORMAT" docs/fixture.md || { echo "migration not applied"; exit 1; }
  # имитировать explicit-pathspec commit MIGRATED-путей (как _auto_commit_sync)
  git add -- docs/fixture.md && git commit -q -m "migrate" -- docs/fixture.md || exit 1
  # a17ecc1 assert: PARALLEL.md НЕ должен попасть в коммит (всё ещё staged, uncommitted)
  git diff --cached --name-only | grep -q "docs/PARALLEL.md" || { echo "PARALLEL captured!"; exit 1; }
  exit 0
)
MIG_EXIT=$?
if [ "$MIG_EXIT" -ne 0 ]; then
  echo "[FAIL] migrations-selfapply-bridge — ожидался exit 0, получен $MIG_EXIT (MIGRATED-emit / apply / a17ecc1-capture)"
  FAILS=$((FAILS+1))
else
  echo "[ok]   migrations-selfapply-bridge — apply + MIGRATED-emit + parallel-файл не захвачен"
fi

# ── Test 8: work-home hygiene (artifact-storage-rule) ────────────────────────────
# validate-work-home.sh должен флагать stray _tmp_* в корне fixture-дерева → exit 1;
# чистое дерево (delivery-clean, нет scratch) → exit 0.
assert_exit 1 "work-home-stray" -- bash scripts/validate-work-home.sh --root "$FX/work-home-stray"
assert_exit 0 "work-home-clean" -- bash scripts/validate-work-home.sh --root "$FX/delivery-clean"

# ── Positive control ─────────────────────────────────────────────────────────────
# validate-triggers.sh на чистом triggers.json → exit 0.
# Ловит «harness всегда видит non-zero» вырожденность.
T6="$(mktemp -d)"
CLEANUP_DIRS="$CLEANUP_DIRS $T6"
mkdir -p "$T6/.claude/state"
printf '{"global":{"last_retro":{"date":"2026-01-01","count":1}}}\n' > "$T6/.claude/state/triggers.json"
assert_exit 0 "triggers-positive-control" -- bash scripts/validate-triggers.sh --root "$T6"

echo ""
echo "=== harness: $RAN проверено, $FAILS провалено ==="

if [ "$FAILS" -gt 0 ]; then
  echo "" >&2
  echo "BLOCKED: ≥1 валидатор не ведёт себя как ожидалось (G-112 false-green)." >&2
  echo "  [FAIL] выше показывает какой assert провалился." >&2
  echo "  Если валидатор «починили» так что fixture больше не трипает → обнови fixture или harness." >&2
  exit 1
fi

exit 0
