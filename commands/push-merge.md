# /push-merge — Push ai-dev и merge в develop (или main)

> **Цель:** опубликовать изменения из ветки `ai-dev` в `develop` (по умолчанию) или `main`. Platform-aware: работает с GitHub и GitLab без ручной настройки.

**Только для консьюмеров.** Methodology-platform использует `/deploy`.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — команда это git-операция + чек-листы, не reasoning.
**Upgrade:** не требуется.
**Pre-flight model check:** нет (Fast tier — минимально допустимый для этой команды).

---

## Использование

```
/push-merge          — push ai-dev → develop (спросит если develop не найден)
/push-merge --main   — push ai-dev → main напрямую, без вопросов
```

---

## Шаг 1 — Pre-flight

- [ ] Текущая ветка = `agent_branch` (default: `ai-dev`) из `CLAUDE.local.md ## Branching`
- [ ] Все изменения закоммичены: `git status --short` = пусто
- [ ] `/review` прошёл в этой сессии
- [ ] Прочитать `mode` из `CLAUDE.local.md ## Branching` (solo / team — определяет поведение push)

```bash
grep -A5 '## Branching' CLAUDE.local.md | grep 'mode:'
```

---

## Шаг 2 — Push

```bash
bash scripts/consumer-push.sh $ARGUMENTS
```

Скрипт автоматически:
1. Определяет платформу (GitHub / GitLab) из `git remote get-url origin`
2. Проверяет наличие ветки `develop` на remote
3. Solo mode → push напрямую в target ветку (нет MR/PR — не нужен для single-owner)
4. Team mode → push ветки + вывод URL для создания MR/PR (merge делает человек)

**Если `develop` не найдена:**
- Скрипт спросит "Push в main? (y/n)"
- Или используй `/push-merge --main` чтобы пропустить вопрос

**Если push вернул 403 / permission denied** — следуй инструкции скрипта:
- GitHub: `gh auth login` → повторить
- GitLab: проверь Personal Access Token или SSH-ключ

**Override платформы** (если auto-detection неверна для self-hosted GitLab):
```yaml
# В CLAUDE.local.md ## Branching:
remote_platform: gitlab   # github | gitlab
```

---

## Шаг 3 — После push

- [ ] Solo: `git log -1 --oneline origin/<target>` совпадает с последним коммитом?
- [ ] Team: MR/PR создан и назначен ревьюеру?
- [ ] Обновить `triggers.json` если нужно (скрипт делает это автоматически)

---

## Solo vs Team — разница в поведении

| mode | GitHub | GitLab |
|---|---|---|
| `solo` | `git push origin ai-dev:<target>` — напрямую, нет PR | то же — push напрямую |
| `team` | Push ветки + URL для `gh pr create` | Push ветки + URL для создания MR |

`mode` читается из `CLAUDE.local.md ## Branching`. Default: `solo`.

---

⛔ Не использовать для методологии. `/deploy` — правильная команда для methodology-platform.

$ARGUMENTS
