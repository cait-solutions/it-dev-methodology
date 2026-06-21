# skills-local/ — Maintainer-only Agent Skills

Skill-аналог `commands-local/`. Skills здесь **НЕ доставляются консьюмерам**.

## Зачем

`sync_skills()` в `scripts/sync-methodology.sh` итерирует **только** `skills/*` — эта папка
(`skills-local/*`) ему структурно невидима (L4 closedness: нет альтернативного пути доставки,
не «помни не клади maintainer-skill в skills/»). При self-apply методологии skills-local
копируется в её собственный `.claude/skills/` — методология может пользоваться своими
maintainer-skills, консьюмеры — нет.

## Когда класть skill сюда vs в skills/

| | `skills/` (доставляется) | `skills-local/` (maintainer-only) |
|---|---|---|
| Аудитория | любой консьюмер-проект | только владелец методологии |
| Примеры | `secrets-management`, `design-spec`, marketing-skills | (пока пусто) skill оркестрации консьюмеров, portfolio-операции |
| Решение | consumer-facing capability | операция над workspace/портфелем консьюмеров |

Критерий — тот же что для команд (`commands/` vs `commands-local/`):
**consumer-facing capability → `skills/`; операция над самими консьюмерами / workspace методолога → `skills-local/`.**
Классификация при создании — `/plan` Шаг -1.3 (author-time), не deploy-grep.

## Структура

```
skills-local/
  <skill-name>/
    SKILL.md          ← YAML frontmatter на строке 1 (Agent Skills spec)
```

Сейчас папка содержит только этот README — реальных maintainer-only skills ещё нет
(zero scaffolding by design). При появлении первого — создать `skills-local/<name>/SKILL.md`;
self-apply подхватит автоматически.
