# IT Dev Methodology

AI-assisted разработка: slash-команды, шаблоны, хуки, скрипты — единый источник правды для всех проектов.

---

## Для нового разработчика — начни здесь

### Шаг 1. Структура папок

Создай одну папку-контейнер для проекта. Внутри неё будут три репозитория:

```
my-project/                          ← папка-контейнер (не git-репо)
├── it-dev-methodology/              ← этот репо (методология)
├── my-project-documentation/        ← артефакты, команды, архитектура
└── my-project-backend/              ← код проекта (если есть)
```

Имена `my-project-documentation` и `my-project-backend` уточни у PM — они могут отличаться.

---

### Шаг 2. Клонируй репозитории

```bash
git clone https://github.com/cait-solutions/it-dev-methodology
git clone https://github.com/<org>/<my-project-documentation>
git clone https://github.com/<org>/<my-project-backend>   # если есть
```

> Адреса репозиториев проекта узнай у PM или Team Lead.
> `it-dev-methodology` — публичный, клонируется без токена.
> Остальные — приватные, потребуют аутентификацию:
> - Проще всего: установи [GitHub CLI](https://cli.github.com) и выполни `gh auth login` перед клоном.
> - Или используй SSH-ключ если он уже настроен.

---

### Шаг 3. Восстанови команды методологии

Открой папку `my-project-documentation/` в Claude Code (расширение для [VS Code](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code) или [JetBrains](https://plugins.jetbrains.com/plugin/24819-claude-code)).

Напиши агенту:

> «Запусти sync-methodology.sh из папки it-dev-methodology чтобы восстановить команды методологии в этом проекте»

Или через терминал из папки `my-project-documentation/`:

```bash
bash ../it-dev-methodology/scripts/sync-methodology.sh .
```

---

### Шаг 4. Запуск онбординга

В Claude Code с открытой папкой `my-project-documentation/` запусти:

```
/onboard
```

Команда проведёт тебя по архитектуре проекта, покажет что где лежит и что делать дальше.

---

## Обновление методологии в существующем проекте

Когда вышла новая версия — запусти в Claude Code:

```
/sync-audit
```

Команда покажет что изменилось и что нужно обновить в проекте.

Или через терминал из папки `my-project-documentation/`:

```bash
bash ../it-dev-methodology/scripts/sync-methodology.sh .
```

---

## Для владельца — создание нового проекта

Если проект ещё не существует и ты создаёшь его с нуля, из папки-контейнера выполни:

```bash
bash it-dev-methodology/scripts/new-project-init.sh <project-name> <project-name>-documentation/
```

Скрипт создаст полную структуру артефактов в `project-name-documentation/`:
команды, шаблоны, триггеры, хуки, карты архитектуры.

После этого открой `project-name-documentation/` в Claude Code и запусти `/onboard`.

---

## Что внутри этого репо

| Папка | Назначение |
|---|---|
| `commands/` | Slash-команды (`/plan`, `/code`, `/review`, `/deploy`, `/retro` и др.) |
| `templates/` | Шаблоны артефактов (CLAUDE.md, PRODUCT.md, триггеры, хуки) |
| `scripts/` | Bootstrap и sync скрипты |
| `skills/` | Agent Skills — knowledge-domain (secrets, marketing и др.) |
| `VERSION` | Текущая версия методологии |

Изменять файлы в этом репо не нужно — всё нужное скопируется в твой проект через sync.

---

Версия методологии: см. [VERSION](VERSION)
