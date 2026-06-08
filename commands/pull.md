# /pull — Pull ai-dev с remote (ff-only)

> **Цель:** подтянуть последние коммиты из remote в локальную ветку `ai-dev` — безопасно, без auto-merge.

**Только для консьюмеров.** Methodology-platform использует `git pull` напрямую.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — это git fetch + pull + чек-листы, не reasoning.
**Upgrade:** не требуется.
**Pre-flight model check:** нет.

---

## Использование

```
/pull   — pull origin/<agent_branch> → локальная ветка (нет аргументов)
```

---

## ⚠️ Важно: запускать из этого репо

`/pull` работает только в сессии **этого проекта** — не из соседнего репо.

Claude Code hooks используют относительные пути (`py .claude/hooks/...`). Если CWD сессии находится в директории без `.claude/hooks/` — все Bash-команды включая `cd`, `git`, `echo` завершаются ошибкой. Переключись в нужную сессию перед запуском.

---

## Шаг 1 — Pre-flight

- [ ] Нет незакоммиченных изменений: `git status --short` = пусто (или `git stash`)
- [ ] Текущая ветка = `agent_branch` из `CLAUDE.local.md ## Branching` (default: `ai-dev`)

```bash
grep -A5 '## Branching' CLAUDE.local.md | grep 'agent_branch:'
```

---

## Шаг 2 — Pull

```bash
bash scripts/consumer-pull.sh
```

Скрипт:
1. Проверяет наличие `.claude/` (hook-safety guard)
2. Читает `agent_branch` из `CLAUDE.local.md`
3. Проверяет uncommitted changes — блокирует если есть
4. Выполняет `git fetch origin <agent_branch>`
5. Показывает входящие коммиты (preview)
6. `git pull --ff-only origin <agent_branch>` — без merge, без rebase-сюрпризов

**Если уже актуально** — скрипт скажет "✅ Уже актуально" и выйдет без изменений.

**Если история разошлась (ff-only не прошёл):**

```
❌ Pull --ff-only не прошёл: история разошлась.
```

Варианты:
- Посмотреть расхождение: `git log --oneline --graph origin/ai-dev...ai-dev`
- Принять remote: `git reset --hard origin/ai-dev` ⚠️ деструктивно — спроси пользователя
- Rebase: `git rebase origin/ai-dev`

---

## Шаг 3 — После pull

- [ ] `git log -1 --oneline` совпадает с `git log -1 --oneline origin/<agent_branch>`?
- [ ] Если нужно запушить локальные изменения → `/push` или `/push-merge`

---

⛔ Не использовать для методологии. Methodology-platform — `git pull` напрямую в терминале.
