# /pull-consumers — Sync consumer repos + diff new methodology artifacts

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob `commands/*.md`).
> Цель: одной командой подтянуть все consumer repos в workspace + показать diff новых записей в methodology-tracked артефактах (AGENT-GAPS, PRODUCT-GAPS, CODE-GAPS, DEVLOG, IDEAS, ROADMAP, HYPOTHESES, RISKS, OPEN-QUESTIONS).
>
> **Заменяет ручной workflow:** `cd <repo1> && git pull && cat AGENT-GAPS.md` × N repos.

---

## Рекомендуемая модель

**Fast tier (Haiku)** — структурное чтение файлов + diff parsing + report generation. Никакого reasoning. См. [.claude/model-tiers.md](../.claude/model-tiers.md).

Pre-flight model check: spросить пользователя только если текущая = Capable (Opus) — рекомендовать downgrade для экономии токенов.

---

## Когда запускать

- **Перед `/retro`** — увидеть свежие gaps всех консьюмеров для cross-repo pattern analysis
- **Перед `/plan` методологических изменений** — убедиться что анализ на свежих данных (не stale gaps как в G-009 класс)
- **Раз в неделю** — поддерживать актуальную картину консьюмер-болей
- ❌ НЕ запускать автоматически — manual trigger only (state не отслеживается)

---

## Prerequisite (v4.34.0+)

Каждый consumer репо должен быть склонирован через credential helper, **не** через token в URL. Если ещё не склонирован:

```bash
# 1. Проверить активный gh аккаунт (GitHub repos):
gh api user -q .login

# 2. Переключить на нужный (если надо):
gh auth switch --user cait-solutions   # или нужный аккаунт

# 3. Clone using the helper-based clone script:
bash scripts/clone-consumer.sh <name>
```

> **Нет GITHUB_PAT?** — не нужен. Canonical auth = `gh auth` (gh CLI). `check-secret.sh GITHUB_PAT` exit 1 ≠ нет доступа: push/fetch работают через `gh auth`. PAT — опциональный fallback, не primary path.

`/pull-consumers` использует **fetch** на уже cloned repos — token берётся git'ом из credential helper, агент не видит значение. См. `skills/secrets-management/SKILL.md` для деталей.

---

## Шаг 0 — Discovery консьюмеров (auto)

**Два режима — приоритет: Режим A (workspace file) > Режим B (sibling scan).**

### Подшаг 0.1 — Читать конфиг

Прочитать `CLAUDE.local.md` секцию `## Consumers`:
```yaml
consumers_root: ..                                        # default ..
marker_file: .claude/.version                             # default .claude/.version
workspace_file: ../It dev methodology.code-workspace      # путь к .code-workspace, относительно methodology repo
```
Defaults если секция отсутствует: `consumers_root=..`, `marker_file=.claude/.version`, `workspace_file=` (не задан → автопоиск).

### Подшаг 0.2 — Режим A: Workspace file discovery (приоритет)

1. **Найти workspace file:**
   - Если `workspace_file` задан в конфиге → resolve абсолютный путь относительно methodology repo
   - Если не задан → автопоиск: `ls "<consumers_root>"/*.code-workspace 2>/dev/null | head -1`
   - Если файл не найден → перейти к Режиму B, показать предупреждение:
     `⚠️ .code-workspace не найден — fallback к sibling scan`

2. **Парсить JSON** (Python, избегать bash-only JSON parsing):
   ```bash
   python3 -c "
   import json, sys, pathlib
   ws = pathlib.Path(sys.argv[1])
   ws_dir = ws.parent
   data = json.loads(ws.read_text(encoding='utf-8'))
   for f in data.get('folders', []):
       p = (ws_dir / f['path']).resolve()
       print(p)
   " "<workspace_file_path>"
   ```

3. **Для каждого resolved path:**
   - Пропустить если не существует или не директория
   - Пропустить если `resolved_path == methodology_repo_path` (self)
   - Пропустить если нет `.git/` (не git repo)
   - **Пропустить если `resolved_path` присутствует в `exclude_paths`** (CLAUDE.local.md ## Consumers) — без вывода в inventory (владелец сознательно исключил через `/sync-audit` Gap 14 → `never`)
   - Определить тип: `[marker]` если есть `<path>/<marker_file>`, иначе `[no-marker]`
   - Добавить в список consumers с флагом типа

4. **Для каждого consumer определить branch:**
   - Прочитать `<consumer>/CLAUDE.local.md` → `## Branching` → `agent_branch`
   - Default `ai-dev` если не найден

5. **`[no-marker]` consumers:** включаются в discovery и report, но в Шаге 3 (diff artifacts) — только читать DEVLOG/IDEAS если файлы существуют; gap-checks (`.claude/.version` version comparison) пропускаются. В report помечать: `⚪ [no-marker] — методология не инициализирована`.

### Подшаг 0.3 — Режим B: Sibling scan (fallback)

Если workspace file не найден — использовать sibling scan (поведение до v4.62.0):
```bash
WORKSPACE_ROOT="<methodology_repo>/<consumers_root>"
for dir in "$WORKSPACE_ROOT"/*/; do
  [[ "$dir" == "$METHODOLOGY_DIR/" ]] && continue   # skip self
  [[ ! -d "$dir/.git" ]] && continue                # skip non-git
  [[ ! -f "$dir/$MARKER_FILE" ]] && continue        # skip no-marker (sibling mode: strict)
  # discovered consumer
done
```

> **Отличие от Режима A:** sibling scan в Режиме B требует marker_file (строгий фильтр). Режим A включает `[no-marker]` repos — потому что workspace = явный список выбранных разработчиком.

### Подшаг 0.4 — Вывести inventory

```
Discovery mode: workspace file (<path>) — 8 folders found
Discovered consumers:
  ✅ erp-documentantion              (branch: ai-dev, remote: gitlab)        [marker v4.47.5]
  ✅ ai-assistant-documentation      (branch: ai-dev, remote: github)        [marker v4.10.6]
  ✅ it-dev-methodology-documentation(branch: main,   remote: github)        [marker v4.45.0]
  ⚪ legal-ai-assistant-documentation(branch: ai-dev, remote: github)        [no-marker]
  ⚪ social-promo-documentation      (branch: ai-dev, remote: github)        [no-marker]
  ⚪ ebay-template-documentation     (branch: ai-dev, remote: github)        [no-marker]
  ⚪ lead-gen-documentation          (branch: ai-dev, remote: github)        [no-marker]
  — it-dev-methodology (self — skipped)
```

---

## Шаг 1 — Pre-flight check каждого консьюмера

Для каждого discovered консьюмера ДО pull:

- [ ] **Dirty .claude/ check:** `git -C <path> status --short -- .claude/ 2>/dev/null` непусто? → SKIP только этот репо `[skip: dirty .claude/]` + сообщение; **продолжить следующий** (не блокировать весь батч). Dirty вне `.claude/` (DEVLOG.md, ROADMAP.md и т.п.) — не повод для skip; `git merge --ff-only` сам разберётся если нет конфликтов. Для разрешения dirty: запусти `/sync-audit` Gap 17 (stash / ignore / ignore-always), затем повтори `/pull-consumers`.
- [ ] `git -C <path> remote get-url origin` существует? Если нет → SKIP «no origin remote»
- [ ] Запомнить `prev_sha = git -C <path> rev-parse HEAD`
- [ ] **GitHub multi-account check** — выполнить **один раз перед циклом**, не per-consumer:

  **Инициализация (до начала цикла по consumers):**
  ```bash
  # Надёжный способ получить активный аккаунт (работает стабильно между версиями gh CLI):
  ORIGINAL_GH_ACCOUNT=$(gh api user -q .login 2>/dev/null || echo "")
  # Установить trap СРАЗУ — до любых switch:
  [[ -n "$ORIGINAL_GH_ACCOUNT" ]] && \
    trap "gh auth switch --user $ORIGINAL_GH_ACCOUNT 2>/dev/null; trap - EXIT INT TERM" EXIT INT TERM
  ```

  **Для каждого github.com consumer в цикле:**
  1. Получить remote URL: `git -C <path> remote get-url origin`
     Нормализовать SSH → HTTPS: `echo "$url" | sed 's|git@github\.com:|https://github.com/|; s|\.git$||'`
     Результат: `https://github.com/org/repo`
  2. Найти `gh_account` из `.claude/secrets-manifest.yaml` — **URL-prefix longest-match**:
     - Собрать все записи с непустым `gh_account`, отсортировать по длине `service_url` (descending)
     - Первая запись чей `service_url` является prefix'ом нормализованного remote URL → `gh_account` найден
     - Если не найдено в manifest → Fallback: прочитать `CLAUDE.local.md ## Branching → gh_account` (если задан)
     - Если не найдено нигде → `🟡 gh_account не определён для <consumer> — switch пропущен` + пропустить
  3. Если `gh_account` не найден (после fallback) → пропустить (backward compat, 🟡 выше показан)
  4. Если `gh_account` ≠ текущему активному (`gh api user -q .login`) → показать warning и переключить:
  ```
  ⚠️ GitHub account mismatch для <consumer>:
     Нужен: <gh_account из manifest>
     Активен: <current>
     Переключаю: gh auth switch --user <gh_account>
  ```
  4. Выполнить switch: `gh auth switch --user <gh_account>`
  5. Выполнить fetch (Шаг 2) для этого consumer
  6. После fetch — revert: `gh auth switch --user $ORIGINAL_GH_ACCOUNT`

  **После цикла:**
  - Снять trap: `trap - EXIT INT TERM`
  - В финальном report показать: `🔄 gh account restored: $ORIGINAL_GH_ACCOUNT`

  Если `gh` CLI недоступен → пропустить с `🟡 gh CLI not found — skipping account check`.

⛔ Read-only mode: НИКОГДА не выполнять `git push`, `git commit`, `git reset --hard` в консьюмере. Только `fetch` + `merge --ff-only`. См. CLAUDE.local.md правило «Consumer repos — READ ONLY».

---

## Шаг 2 — Fetch + ff-merge

Для каждого консьюмера прошедшего pre-flight:

```bash
git -C "$consumer_path" fetch origin "$branch" 2>&1
# Сохранить stderr — sanitize tokens перед report:
# sed 's/x-access-token:[^@]*@/x-access-token:***@/g'
# sed 's/oauth2:[^@]*@/oauth2:***@/g'
```

Если fetch fail (404, auth, network) → SKIP с sanitized stderr в report.

Если fetch OK:
```bash
git -C "$consumer_path" merge --ff-only "origin/$branch" 2>&1
```

Если merge fail (non-ff, divergent) → SKIP «non-ff merge — manual rebase needed».

Если merge OK:
- `head_sha = git -C <path> rev-parse HEAD`
- Если `prev_sha == head_sha` → mark as «up to date»
- Иначе → mark как «pulled: N commits» (`git log --oneline prev_sha..head_sha | wc -l`)

⚠️ **Silent failure check:** если fetch вернул 0 но HEAD не изменился — это может быть «реально up to date» или «network proxy глотает payload». Команда сообщает «up to date» как факт. Подозрение на silent fail → разработчик проверяет вручную через web UI remote.

---

## Шаг 3 — Diff methodology artifacts

**`[marker]` consumers:** полный diff по git (prev_sha..head_sha).
**`[no-marker]` consumers:** нет prev_sha — читать файлы напрямую и показать последние 5 entries каждого артефакта (snapshot, не diff). Пометить секцию: `⚪ [no-marker] — показан snapshot (нет baseline для diff)`.

**Методология-tracked файлы** (искать в **корне И в `docs/`**):
- `AGENT-GAPS.md`
- `PRODUCT-GAPS.md`
- `CODE-GAPS.md` *(read-only diff для cross-domain pattern detection — какие классы product-багов повторяются у консьюмеров; НЕ копировать баги в methodology-артефакты, G-032)*
- `DEVLOG.md`
- `IDEAS.md`
- `ROADMAP.md`
- `HYPOTHESES.md`
- `RISKS.md`
- `OPEN-QUESTIONS.md`

Для **`[marker]` consumers** (diff mode):
```bash
git -C "$consumer_path" diff "$prev_sha..$head_sha" -- "$file"
```

Для **`[no-marker]` consumers** (snapshot mode):
```bash
# Читать файл напрямую — последние N записей
grep -E "^## 20|^## G-|^## P-|^- \[|^Gap-ID:" "$consumer_path/$file" | tail -5
```

Парсить diff/snapshot:
- **GAPS файлы:** блоки с `Gap-ID:` → извлечь ID + first 60 chars описания
- **DEVLOG:** строки начинающиеся с `## 20` → извлечь tag + первая строка
- **IDEAS / ROADMAP:** строки начинающиеся с `- [ ]` или `## 20` → извлечь
- **HYPOTHESES / RISKS / OPEN-QUESTIONS:** заголовки `## ` → извлечь

Edge cases:
- Файл существует в **обоих** местах (`./IDEAS.md` И `docs/IDEAS.md`) — показать оба отдельно
- Файл пустой / нет diff → «no new entries»
- Файл не существует в консьюмере → пропустить тихо

---

## Шаг 3.5 — Partial-hook-state check (closes G-087 — детект рекурсивной дыры доставки)

**Зачем:** G-087 повторялся трижды — у консьюмера `settings.json` ссылается на хуки, но сами файлы (в т.ч. `run-hook.sh`) отсутствуют на диске → все хуки молча падают, escalation/защита мертвы, и runtime-детектор (`check_hook_health` внутри `auto-update-watchdog`) сам недоступен потому что его раннер `run-hook.sh` отсутствует. `/pull-consumers` видит все репо разом — идеальное место для cross-consumer детекта этого driftّа ПОСЛЕ pull (свежее состояние).

**Только для `[marker]` consumers** (у `[no-marker]` нет инициализированной методологии — пропустить тихо).

Для каждого `[marker]` консьюмера, у которого есть `.claude/settings.json`:

```bash
SETTINGS="$consumer_path/.claude/settings.json"
HOOKS_DIR="$consumer_path/.claude/hooks"
[[ -f "$SETTINGS" ]] || continue   # нет settings — пропустить
# Зеркало canon (auto-update-watchdog.template.py:211-215): два паттерна.
referenced=$( {
  grep -oE '\.claude/hooks/[A-Za-z0-9_.-]+\.(py|sh)' "$SETTINGS" 2>/dev/null | sed 's#.*\.claude/hooks/##'
  grep -oE 'run-hook\.sh [A-Za-z0-9_.-]+\.py' "$SETTINGS" 2>/dev/null | sed 's#run-hook\.sh ##'
} | sort -u )
missing=""
for h in $referenced; do
  [[ -f "$HOOKS_DIR/$h" ]] || missing="$missing $h"
done
```

- **`missing` непусто** → пометить консьюмера в Report флагом `⚠️ HOOK-DRIFT` с перечнем отсутствующих файлов. Если в `missing` есть `run-hook.sh` — **критично** (раннер всех хуков): отдельно отметить `🔴 run-hook.sh отсутствует → ВСЕ хуки мертвы`.
- **`missing` пусто** → тихо (хуки целы).

⛔ Read-only: команда **только сообщает** drift в Report, не чинит (консьюмер чинит сам через `sync-methodology.sh`). Рекомендация в Report: «консьюмер должен запустить `bash <methodology>/scripts/sync-methodology.sh .`».

---

## Шаг 3.6 — Freshness check (LAR presence + diagram freshness, v5.51.0)

**Зачем:** без LAR у консьюмера lifecycle-реестр пуст; без аннотаций `diagram-sources` движок PLAN-H не видит связь диаграммы с данными. `/pull-consumers` — единственное место где владелец методологии видит состояние freshness по всем репо сразу.

**Только для `[marker]` consumers.** `[no-marker]` — пропустить тихо.

Для каждого `[marker]` консьюмера:

1. **LAR presence check:**
   ```bash
   # Определить doc_repo_path из CLAUDE.local.md (single / two-repo)
   # single-repo: docs/architecture/LIVING-ARTIFACTS.md
   # two-repo: <doc_repo_path>/docs/architecture/LIVING-ARTIFACTS.md
   LAR_PRESENT="❌"
   [[ -f "$lar_path" ]] && LAR_PRESENT="✅"
   ```

2. **Diagram freshness check (Read-only):**
   ```bash
   FRESHNESS="—"
   if [[ -f "$consumer_path/scripts/validate-maps-coverage.sh" ]]; then
     result=$(bash "$consumer_path/scripts/validate-maps-coverage.sh" --report 2>&1)
     errors=$(echo "$result" | grep -c "^\[ERROR\]" || true)
     warnings=$(echo "$result" | grep -c "^\[WARN\]" || true)
     if [ "$errors" -gt 0 ]; then
       FRESHNESS="🔴 ${errors} err"
     elif [ "$warnings" -gt 0 ]; then
       FRESHNESS="🟡 ${warnings} warn"
     else
       FRESHNESS="🟢 0/0"
     fi
   fi
   ```
   Если скрипт отсутствует → `FRESHNESS="— (v5.47.0+)"`.

3. Сохранить `LAR_PRESENT` + `FRESHNESS` для drift-таблицы в Шаге 4.

⛔ Read-only: не запускать `validate-lar.sh` с изменением state, не писать в консьюмера.

---

## Шаг 4 — Report

Вывести структурированный отчёт пользователю, включая **drift-колонку** (closes PLAN-05 visibility):

```
## Pull Consumers Report — <ISO date>
Discovery: workspace file (It dev methodology.code-workspace) — 8 repos, 4 with marker, 4 no-marker

Drift summary (methodology v5.41.0):
| Репо | ver | synced | Δ minor | LAR | Freshness | Статус |
|---|---|---|---|---|---|---|
| erp-documentantion | v4.47.5 | 2026-06-01 | +94 | ✅ | 🟡 2 warn | [drift] |
| it-dev-documentation | v4.45.0 | 2026-06-01 | +96 | ❌ | — | [drift] |
| ... | ... | ... | ... | ... | ... | ... |
Запустить /push-consumers чтобы доставить обновления.

LAR = наличие LIVING-ARTIFACTS.md (✅ / ❌); Freshness = результат validate-maps-coverage.sh --report (🟢 0/0 / 🟡 N warn / 🔴 N err / — нет карт).

### [marker] erp-documentantion (gitlab/ai-dev) — v4.47.5
✓ Pulled abc123 → def456 (12 commits since 2026-05-25)
⚠️ HOOK-DRIFT: 🔴 run-hook.sh отсутствует → ВСЕ хуки мертвы; iteration-watchdog.py отсутствует
   → консьюмер должен запустить `bash <methodology>/scripts/sync-methodology.sh .`

**AGENT-GAPS** (root): +2 new
- G-010: «Не сгенерировал ссылку для USER-MAP, gitignored файл выпал из diff»
- G-011: «ARTIFACT-MAP не получил mermaid.live ссылку — гипотеза неверна»

**DEVLOG** (root): +5 entries (2026-05-27..28)
- [feat:command] /pull-consumers v4.28.0
- [fix:hook] auto-update-watchdog interval

**PRODUCT-GAPS** (root): no new
**IDEAS** (root): +1 new
- «cross-repo gap pattern analysis tool»

### [marker] ai-assistant-documentation (github/ai-dev) — v4.10.6
✗ SKIPPED — fetch failed: remote repository not found (404)

### [marker] it-dev-methodology-documentation (github/main) — v4.45.0
✓ up to date — no new commits

---

### [no-marker] legal-ai-assistant-documentation (github/ai-dev)
⚪ Методология не инициализирована — snapshot последних записей

✓ Pulled (up to date)
**DEVLOG** (snapshot, последние 5): нет файла
**IDEAS** (snapshot, последние 5): нет файла

### [no-marker] social-promo-documentation (github/ai-dev)
⚪ Методология не инициализирована — snapshot последних записей
✓ Pulled def789 → abc012 (3 commits)
**DEVLOG** (snapshot): no file
**IDEAS** (snapshot): no file

### [no-marker] ebay-template-documentation (github/ai-dev)
⚪ up to date — no new commits

### [no-marker] lead-gen-documentation (github/ai-dev)
⚪ up to date — no new commits

---

## Summary
Discovery: workspace file — 8 repos (4 marker / 4 no-marker)
Pulled: 6 ok, 1 skipped (fetch failed), 1 skipped (uncommitted changes)
New gap entries [marker repos]: 2 AGENT-GAPS, 0 PRODUCT-GAPS, 1 IDEAS
Recommendations:
  • 2+ new AGENT-GAPS → consider /retro --consumers
  • 4 repos [no-marker] — запусти /sync-audit для per-repo решения (Gap 14: init / skip / never)
```

**Brevity rules:**
- Per-entry preview = first 60 chars содержания (one-line summary), не full content
- Показывать **все** новые записи (не truncate с «…»); если разработчик хочет full content — отдельный Read tool на конкретный файл/ID
- Если консьюмер «up to date» — одна строка, не раздувать

---

## Шаг 5 — Cleanup и exit

- НЕ обновлять `triggers.json` (manual trigger only — no state tracking by design)
- НЕ запускать `sync-methodology.sh` (не deploy, не code change)
- Финальная строка: «✅ /pull-consumers done. <N consumers pulled, M skipped, K new entries>. Run /retro --consumers для анализа или просто прочитай конкретные файлы.»

---

## Что эта команда НЕ делает

- ❌ НЕ клонирует новые консьюмеры (один раз `git clone` вручную или через VSCode «Add Folder to Workspace»)
- ❌ НЕ пушит изменения обратно в консьюмеры (read-only by design)
- ❌ НЕ резолвит merge conflicts (ff-only mode, fail-safe)
- ❌ НЕ автоматически кросс-аналитика gaps (отдельная команда `/retro --consumers` если появится)
- ❌ НЕ обновляет state — каждый запуск независим
- ❌ НЕ синхронизируется в `.claude/commands/` консьюмеров (lives в `commands-local/`)

---

## Configuration в CLAUDE.local.md

Минимальная (defaults достаточно):
```yaml
## Consumers
consumers_root: ..
marker_file: .claude/.version
```

Если консьюмеры в другой структуре (например `../projects/<name>/`):
```yaml
## Consumers
consumers_root: ../projects
marker_file: .claude/.version
```

---

## Troubleshooting

**Pull failed «non-ff»:** консьюмер local diverged от origin. Решение: вручную `cd <consumer> && git rebase origin/<branch>` или `git reset --hard origin/<branch>` (если local изменения не нужны).

**`[no-marker]` repos видны но нет gap-tracking:** ожидаемо — методология не инициализирована. Запусти `/sync-audit` — Gap 14 предложит per-repo решение (init / skip / never) без ручного bash. После init + commit репо появится как `[marker]` в следующем запуске.

**`[no-marker]` repos НЕ должны быть в /pull-consumers:** запусти `/sync-audit` и выбери `never` в Gap 14 для этого репо — путь автоматически добавится в `exclude_paths` в `CLAUDE.local.md ## Consumers`. При следующем запуске `/pull-consumers` этот репо исчезнет из inventory.

**404 на одном консьюмере:** repo private/удалён/wrong URL. Проверь `git -C <consumer> remote get-url origin`. Исправь через `git remote set-url origin <correct-url>`.

**Discovery не находит консьюмеров (Режим A):** проверь что `workspace_file` в `CLAUDE.local.md ## Consumers` указывает на актуальный `.code-workspace`. Путь относительно methodology repo. Открой файл — убедись что JSON корректный.

**Discovery не находит консьюмеров (Режим B / fallback):** проверь `consumers_root` в `CLAUDE.local.md` — путь должен резолвиться к директории содержащей sibling папки с `.claude/.version`.
