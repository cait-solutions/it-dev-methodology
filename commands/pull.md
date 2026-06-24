# /pull — Pull всех workspace repos с remote (ff-only)

> **Цель:** одной командой подтянуть все repos из `.code-workspace` с remote — без merge, ff-only, с preview входящих коммитов.

**Только для консьюмеров.** Methodology-platform использует `git pull` напрямую.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **Low** · thinking: **OFF** — git fetch + ff-only pull + чек-листы (mechanical). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — это git fetch + pull + чек-листы, не reasoning.
**Upgrade:** не требуется.
**Pre-flight model check:** нет.

---

## Использование

```
/pull             — pull всех workspace repos (multi-repo, дефолт)
/pull --current   — pull ТОЛЬКО текущего репо (быстро, без workspace-парсинга)
```

> **Какой режим когда:** `/pull` тянет ВЕСЬ workspace (все repos из `.code-workspace`) — для cross-repo обновления. Нужен pull **только текущего** проекта? → **`/pull --current`** (git pull --ff-only текущего репо, не трогает остальные, не требует `.code-workspace`). Closes G-091: раньше простого pull одного репо не было — приходилось в терминал (против command-first).

---

## Что тянется

**Дефолт (`/pull`):** все repos из `.code-workspace` **кроме** `it-dev-methodology` (methodology source — тянется отдельно через `sync-methodology.sh`). Включая `*-documentation` repos и любые другие repos добавленные в workspace.

**`/pull --current`:** только текущий репо (тот в чьей сессии запущено). `.code-workspace` не читается, `consumer-pull.sh` не вызывается — прямой `git pull --ff-only` текущей ветки.

---

## ⚠️ Важно: запускать из этого репо

`/pull` работает только в сессии **этого проекта** (там где есть `.claude/hooks/`).

Claude Code hooks используют относительные пути. Если CWD сессии в директории без `.claude/hooks/` — все Bash-команды включая `git` завершаются ошибкой. Переключись в правильную сессию.

---

## Шаг 1 — Pre-flight

- [ ] Нет незакоммиченных изменений в текущем репо: `git status --short` = пусто
- [ ] `workspace_file` в `CLAUDE.local.md ## Consumers` — проверить:

```bash
grep -A3 '## Consumers' CLAUDE.local.md | grep 'workspace_file:'
```

**Если `workspace_file` не задан (пустой вывод команды выше):**

```
⚠️ workspace_file не настроен в CLAUDE.local.md ## Consumers.
   consumer-pull.sh использует автодетект: ls ../*.code-workspace
   Автодетект может найти не тот workspace или не найти ничего.
   Для надёжного multi-repo pull: добавь workspace_file явно.

   Продолжить? (y — с автодетектом / добавить workspace_file сначала)
```

Показать предупреждение и ждать ответа. Если `y` — запустить `consumer-pull.sh`. Иначе — помочь добавить `workspace_file`: пример строки `workspace_file: ../It dev methodology.code-workspace` в секцию `## Consumers` в `CLAUDE.local.md`.

---

## Шаг 2 — Pull

### Режим `--current` (один репо)

Если запущено `/pull --current` — pull ТОЛЬКО текущего репо, без workspace-парсинга:

1. **Pre-pull чистота:** `git status --porcelain` — если непусто → СТОП «есть незакоммиченные изменения, закоммить/stash сначала» (не pull вслепую).
2. Определить ветку: `git symbolic-ref --short HEAD` (detached HEAD → СТОП «репо не на ветке»).
3. `git pull --ff-only origin <ветка>` — показать входящие коммиты + результат.
4. **Нет origin** → «git remote 'origin' не настроен» (не падать сырой ошибкой).
5. **ff-only не прошёл** (история разошлась) → «✗ ff-only failed — git rebase origin/<ветка> или разреши вручную».

```bash
# текущий режим (без скрипта — это один репо, прямой git):
git -C . status --porcelain   # должно быть пусто
git -C . pull --ff-only origin "$(git symbolic-ref --short HEAD)"
```

→ это всё, дальше Шаг 3 не нужен (один репо). Закончить отчётом «✓ pulled / ✓ up to date / ✗ skip».

### Дефолтный режим (весь workspace)

`/pull` без аргументов:

```bash
bash scripts/consumer-pull.sh
```

Скрипт для каждого repo из workspace:
1. Проверяет uncommitted changes — skip если есть
2. Читает `agent_branch` из `CLAUDE.local.md ## Branching` репо (default: `ai-dev`)
3. `git fetch origin` — **все ветки** (нужно для branch-audit)
4. **Branch audit** — для каждой локальной ветки с upstream показывает `ahead/behind` vs remote. Только **divergent** ветки (`⚠ main: ahead N, behind M`); in-sync молчат. Информирует, **не фиксит** (см. ниже)
5. Показывает входящие коммиты agent-ветки
6. `git pull --ff-only origin <agent_branch>` — без merge-сюрпризов

> **Почему fetch всех веток, но pull только agent-ветки:** divergence других веток (например `main` отстала пока работа идёт в `ai-dev`) была **невидима** — скрипт тянул только `agent_branch`. Теперь audit показывает её. Но автоматически другие ветки **не двигаются** — намеренная отстающая ветка не должна молча перетираться. Для подтягивания divergent ветки → `git checkout <ветка> && git pull --ff-only` или `/pull --current` на ней.

**Если repo уже актуален** — скрипт различает два случая:

- **Нет входящих коммитов И локально не впереди** → «✓ up to date»
- **Нет входящих, но локально впереди** → «✓ up to date (локально впереди +N коммит(ов) — нужен push, не pull)» + рекомендация `/push-merge` или `/deploy`. Это ловит ситуацию когда пользователь запускает `/pull` вместо `/push` — false «up to date» больше не скрывает неотправленные коммиты.

**Если история разошлась (ff-only не прошёл):** скрипт различает три случая:

- **Только sync-коммиты** (`sync methodology v*`) → авто-safe-reset на `origin/<branch>` (это локальные `sync methodology` коммиты от `/push-consumers`, безопасно сбрасываются — dirty-check перед этим уже пройден):
  ```
  ↩  safe-reset: только sync-коммиты — сброс на origin/<branch>
  ```
- **True divergence** (есть хоть один не-sync коммит) → ✗ SKIP с явными счётчиками и конкретной рекомендацией:
  ```
  ✗ SKIP — true divergence (local: +N / remote: +M)
     <ahead-коммиты>
     Рекомендация: git merge origin/<branch>
     Детали: git log --oneline --graph origin/<branch>...<branch>
  ```
  Счётчики `local: +N / remote: +M` сразу показывают характер расхождения. Рекомендация — `git merge` (сохраняет обе истории), не `rebase` (переписывает публичную историю).

**Если fetch вернул 403 / auth error:**
- GitHub: `gh auth login` → повторить `/pull`
- GitLab: проверь Personal Access Token

---

## Шаг 3 — После pull

- [ ] Все нужные repos показали «✓ pulled» или «✓ up to date»?
- [ ] **Branch audit:** есть ветки `⚠ ahead/behind` в summary? Это divergent НЕ-agent ветки (типично `main` пока работа в `ai-dev`) — реши вручную если нужно подтянуть: `git checkout <ветка> && git pull --ff-only`. Отстающая `main` при работе через `ai-dev` — норма, не требует action.
- [ ] Есть repos с ошибками? Проверь вывод — типичные причины указаны там
- [ ] Если нужно запушить локальные изменения → `/push` или `/push-merge`

---

⛔ Не использовать для методологии. Methodology-platform — `git pull` напрямую в терминале.
