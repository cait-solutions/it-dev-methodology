# /push — Push ai-dev на remote (без merge)

> **Цель:** опубликовать ветку `ai-dev` на remote как есть — без merge, без MR/PR, без вопросов.

**Только для консьюмеров.** Methodology-platform использует `/deploy`.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — это git push + чек-листы, не reasoning.
**Upgrade:** не требуется.
**Pre-flight model check:** нет.

---

## Использование

```
/push   — push ai-dev → origin/ai-dev (нет аргументов)
```

---

## Шаг 1 — Pre-flight

- [ ] Все изменения закоммичены: `git status --short` = пусто
- [ ] Прочитать `agent_branch` из `CLAUDE.local.md ## Branching` (default: `ai-dev`)

```bash
grep -A5 '## Branching' CLAUDE.local.md | grep 'agent_branch:'
```

---

## Шаг 2 — Push

```bash
bash scripts/consumer-push-only.sh
```

Скрипт:
1. Читает `agent_branch` из `CLAUDE.local.md`
2. Показывает коммиты которые улетят
3. `git push origin <agent_branch>:<agent_branch>` — без merge, без вопросов

**Если push вернул 403 / permission denied** — следуй инструкции скрипта:
- GitHub: `gh auth login` → повторить
- GitLab: проверь Personal Access Token или SSH-ключ

---

## Шаг 3 — После push

- [ ] `git log -1 --oneline origin/<agent_branch>` совпадает с последним коммитом?
- [ ] Если нужен merge в develop/main → запусти `/push-merge`

---

⛔ Не использовать для методологии. `/deploy` — правильная команда для methodology-platform.
