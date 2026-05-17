# {{Project Name}}

> Открой эту папку как workspace в Claude Code, затем запусти `/plan` для первой фичи.

---

## Три репозитория

Проект использует три уровня репо:

```
it-dev-methodology/          ← slash-команды, хуки, шаблоны (читай-только для консьюмеров)
  └── scripts/sync-methodology.sh
              │
              ▼ sync (после каждого git clone)
              │
{{Project Name}}/            ← этот репо (workspace в Claude Code)
  ├── .claude/commands/      ← локальные копии команд (gitignored, не коммитить)
  ├── .claude/hooks/         ← хуки (gitignored)
  ├── CLAUDE.md              ← правила AI-агента (project-owned, коммитить)
  ├── PRODUCT.md, DEVLOG.md, VISION.md...
  └── docs/
              │
              ▼ /code пишет, /deploy деплоит
              │
Код проекта/                 ← монолит (один репо) или микросервисы (N репо)
```

Команды не хранятся в этом репо — они синхронизируются из `it-dev-methodology`.

---

## После `git clone`

Slash-команды gitignored — восстанови их локально:

```bash
# 1. Склонируй методологию (один раз, куда удобно)
git clone https://github.com/cait-solutions/it-dev-methodology /path/to/it-dev-methodology

# 2. Синхронизируй команды в этот проект
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .
```

Занимает < 30 секунд. После этого открой `{{Project Name}}/` в Claude Code — все `/plan`, `/code`, `/review`, `/deploy` доступны.

**Workspace root:** открывай именно папку `{{Project Name}}/`, не родительскую директорию. Команды резолвятся от workspace root.

---

## Workflow

```
/plan  →  /code  →  /review  →  /deploy
```

| Команда | Что делает |
|---|---|
| `/plan` | Архитектурный анализ + план реализации |
| `/code` | Реализация по согласованному плану |
| `/review` | Ревью перед деплоем с архитектурными проверками |
| `/deploy` | Деплой с safety checks + запись в DEVLOG |

---

## Архитектура проекта

- [SYSTEM-MAP](docs/architecture/SYSTEM-MAP.md) — компоненты, связи, слои
- [USER-MAP](docs/product/USER-MAP.md) — что могут делать пользователи/команда
- [PRODUCT.md](PRODUCT.md) — поведение системы с точки зрения пользователя
- [VISION.md](VISION.md) — стратегические оси

---

## Артефакты разработки

| Файл | Назначение |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Операционные правила для AI-агента |
| [DEVLOG.md](DEVLOG.md) | История решений и деплоев |
| [IDEAS.md](IDEAS.md) | Сырые продуктовые сигналы |
| [ROADMAP.md](ROADMAP.md) | Продуктовый бэклог |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Нерешённые вопросы |
| [HYPOTHESES.md](HYPOTHESES.md) | Гипотезы под проверку |
| [RISKS.md](RISKS.md) | Реестр рисков |

---

## Обновление методологии

Для подтягивания новых команд и хуков из upstream:

```bash
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .
```
