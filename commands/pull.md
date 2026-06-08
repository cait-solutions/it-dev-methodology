# /pull — Pull всех workspace repos с remote (ff-only)

> **Цель:** одной командой подтянуть все repos из `.code-workspace` с remote — без merge, ff-only, с preview входящих коммитов.

**Только для консьюмеров.** Methodology-platform использует `git pull` напрямую.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — это git fetch + pull + чек-листы, не reasoning.
**Upgrade:** не требуется.
**Pre-flight model check:** нет.

---

## Использование

```
/pull   — pull всех workspace repos (нет аргументов)
```

---

## Что тянется

Все repos из `.code-workspace` **кроме** `it-dev-methodology` (methodology source — тянется отдельно через `sync-methodology.sh`).

Включая `*-documentation` repos и любые другие repos добавленные в workspace.

---

## ⚠️ Важно: запускать из этого репо

`/pull` работает только в сессии **этого проекта** (там где есть `.claude/hooks/`).

Claude Code hooks используют относительные пути. Если CWD сессии в директории без `.claude/hooks/` — все Bash-команды включая `git` завершаются ошибкой. Переключись в правильную сессию.

---

## Шаг 1 — Pre-flight

- [ ] Нет незакоммиченных изменений в текущем репо: `git status --short` = пусто
- [ ] `.code-workspace` указан в `CLAUDE.local.md ## Consumers → workspace_file`

```bash
grep -A3 '## Consumers' CLAUDE.local.md | grep 'workspace_file:'
```

---

## Шаг 2 — Pull

```bash
bash scripts/consumer-pull.sh
```

Скрипт для каждого repo из workspace:
1. Проверяет uncommitted changes — skip если есть
2. Читает `agent_branch` из `CLAUDE.local.md ## Branching` репо (default: `ai-dev`)
3. `git fetch origin <agent_branch>`
4. Показывает входящие коммиты
5. `git pull --ff-only origin <agent_branch>` — без merge-сюрпризов

**Если repo уже актуален** — одна строка «✓ up to date».

**Если история разошлась (ff-only не прошёл):**

```
✗ SKIP — ff-only failed (история разошлась)
   git log --oneline --graph origin/<branch>...<branch>
```

Разрешить вручную: `git rebase origin/<branch>` или спросить пользователя.

**Если fetch вернул 403 / auth error:**
- GitHub: `gh auth login` → повторить `/pull`
- GitLab: проверь Personal Access Token

---

## Шаг 3 — После pull

- [ ] Все нужные repos показали «✓ pulled» или «✓ up to date»?
- [ ] Есть repos с ошибками? Проверь вывод — типичные причины указаны там
- [ ] Если нужно запушить локальные изменения → `/push` или `/push-merge`

---

⛔ Не использовать для методологии. Methodology-platform — `git pull` напрямую в терминале.
