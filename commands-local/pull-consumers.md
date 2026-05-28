# /pull-consumers — Sync consumer repos + diff new methodology artifacts

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob `commands/*.md`).
> Цель: одной командой подтянуть все consumer repos в workspace + показать diff новых записей в methodology-tracked артефактах (AGENT-GAPS, PRODUCT-GAPS, DEVLOG, IDEAS, ROADMAP, HYPOTHESES, RISKS, OPEN-QUESTIONS).
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

## Шаг 0 — Discovery консьюмеров (auto)

1. Прочитать `CLAUDE.local.md` секцию `## Consumers`:
   ```yaml
   consumers_root: ..              # path relative to methodology repo (default ..)
   marker_file: .claude/.version   # marker that folder is methodology consumer
   ```
   Defaults если секция отсутствует: `consumers_root=..`, `marker_file=.claude/.version`.

2. Resolve absolute path: `<methodology-repo>/<consumers_root>` → workspace root.

3. Сканировать sibling папки workspace root:
   ```bash
   for dir in "$WORKSPACE_ROOT"/*/; do
     name=$(basename "$dir")
     # Skip self (methodology repo)
     [[ "$dir" == "$METHODOLOGY_DIR/" ]] && continue
     # Skip if not a git repo
     [[ ! -d "$dir/.git" ]] && continue
     # Skip if no methodology marker
     [[ ! -f "$dir/$MARKER_FILE" ]] && continue
     # This is a methodology consumer — discover branch
     ...
   done
   ```

4. Для каждого консьюмера определить branch:
   - Прочитать `<consumer>/CLAUDE.local.md` секцию `## Branching` → `agent_branch`
   - Default `ai-dev` если не указан (методологический инвариант — все консьюмеры используют `ai-dev` для AI-агента)

5. Вывести inventory:
   ```
   Discovered consumers in <workspace-root>:
   - erp-documentantion         (branch: ai-dev, remote: gitlab)
   - ai-assistant-documentation (branch: ai-dev, remote: github)
   - it-dev-methodology-documentation (branch: ai-dev, remote: github)
   ```

---

## Шаг 1 — Pre-flight check каждого консьюмера

Для каждого discovered консьюмера ДО pull:

- [ ] `git -C <path> status --porcelain` пусто? Если нет → SKIP «local uncommitted changes»
- [ ] `git -C <path> remote get-url origin` существует? Если нет → SKIP «no origin remote»
- [ ] Запомнить `prev_sha = git -C <path> rev-parse HEAD`

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

Для каждого pulled консьюмера: собрать новые записи в methodology-tracked артефактах.

**Методология-tracked файлы** (искать в **корне И в `docs/`**):
- `AGENT-GAPS.md`
- `PRODUCT-GAPS.md`
- `DEVLOG.md`
- `IDEAS.md`
- `ROADMAP.md`
- `HYPOTHESES.md`
- `RISKS.md`
- `OPEN-QUESTIONS.md`

Для каждого файла который существует:

```bash
git -C "$consumer_path" diff "$prev_sha..$head_sha" -- "$file"
```

Парсить diff:
- **GAPS файлы:** новые блоки между разделителями `---` с полем `Gap-ID:` → извлечь ID + first 60 chars описания
- **DEVLOG:** новые строки начинающиеся с `## ` или с timestamp pattern `[YYYY-MM-DD]` → извлечь tag + первая строка
- **IDEAS / ROADMAP:** новые строки начинающиеся с `- [ ]` или `## ` → извлечь
- **HYPOTHESES / RISKS / OPEN-QUESTIONS:** новые секции по заголовкам `## ` → извлечь заголовок

Edge cases:
- Файл существует в **обоих** местах (`./IDEAS.md` И `docs/IDEAS.md`) — показать оба отдельно (drift между двумя копиями — сигнал для отдельной диагностики, не дедуплицируем)
- Файл пустой / нет diff → «no new entries»
- Файл не существует в консьюмере → пропустить тихо

---

## Шаг 4 — Report

Вывести структурированный отчёт пользователю:

```
## Pull Consumers Report — <ISO date>

### erp-documentantion (gitlab/ai-dev)
✓ Pulled abc123 → def456 (12 commits since 2026-05-25)

**AGENT-GAPS** (root): +2 new
- G-010: «Не сгенерировал ссылку для USER-MAP, gitignored файл выпал из diff»
- G-011: «ARTIFACT-MAP не получил mermaid.live ссылку — гипотеза неверна»

**DEVLOG** (root): +5 entries (2026-05-27..28)
- [feat:command] /pull-consumers v4.28.0
- [fix:hook] auto-update-watchdog interval
- ... (2 more)

**PRODUCT-GAPS** (root): no new
**IDEAS** (root): +1 new
- «cross-repo gap pattern analysis tool»

**docs/HYPOTHESES**: +1 (drift с root/HYPOTHESES — оба обновлены, проверь синхронизацию)

### ai-assistant-documentation (github/ai-dev)
✗ SKIPPED — fetch failed: remote repository not found (404)

### it-dev-methodology-documentation (github/ai-dev)
✓ Pulled (up to date — no new commits)

---

## Summary
- 2/3 consumers updated successfully, 1 skipped
- 5 new gap-class entries across all repos (3 AGENT-GAPS, 0 PRODUCT-GAPS, 2 IDEAS)
- Recommendation: 
  • 3+ new AGENT-GAPS → consider /retro --consumers для cross-repo pattern analysis
  • Drift detected: erp-documentantion docs/HYPOTHESES.md vs ./HYPOTHESES.md — оба обновлены
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

**Все консьюмеры SKIPPED «no marker_file»:** консьюмеры не bootstrap'нуты через `new-project-init.sh` (нет `.claude/.version`). Либо запусти bootstrap, либо вручную: `mkdir <consumer>/.claude && echo v4.28.0 > <consumer>/.claude/.version`.

**404 на одном консьюмере (как ai-assistant сейчас):** repo private/удалён/wrong URL. Проверь `git -C <consumer> remote get-url origin`. Исправь через `git remote set-url origin <correct-url>`.

**Discovery не находит консьюмеров:** проверь `pwd` методологии и `consumers_root` в `CLAUDE.local.md` — путь должен резолвиться к директории содержащей sibling папки с `.claude/.version`.
