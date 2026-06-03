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

Открой терминал в папке-контейнере и выполни:

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

### Шаг 3. Инициализация

Есть два способа — выбери удобный:

**Способ A — через терминал:**

```bash
cd my-project-documentation
bash ../it-dev-methodology/scripts/sync-methodology.sh .
```

**Способ B — через AI-агента (Claude Code):**

Установи расширение Claude Code в свой IDE (VS Code или JetBrains).
Открой папку `my-project-documentation/` как workspace.
Напиши агенту:

> «Запусти sync-methodology.sh из папки it-dev-methodology чтобы восстановить команды методологии в этом проекте»

Агент сам найдёт скрипт и выполнит его.

---

### Шаг 4. Запуск онбординга

После инициализации открой `my-project-documentation/` в Claude Code и запусти:

```
/onboard
```

Команда проведёт тебя по архитектуре проекта, покажет что где лежит и что делать дальше.

---

## Для владельца — создание нового проекта

Если проект ещё не существует и ты создаёшь его с нуля:

```bash
# Из папки-контейнера:
bash it-dev-methodology/scripts/new-project-init.sh <project-name> <project-name>-documentation/
```

Скрипт создаст полную структуру артефактов в `project-name-documentation/`:
команды, шаблоны, триггеры, хуки, карты архитектуры.

После этого открой `project-name-documentation/` в Claude Code и запусти `/onboard`.

---

## Обновление методологии в существующем проекте

Когда вышла новая версия методологии — обнови команды у себя:

```bash
cd my-project-documentation
bash ../it-dev-methodology/scripts/sync-methodology.sh .
```

Или попроси агента: «Запусти sync-methodology.sh для обновления команд».

После sync агент автоматически предложит проверить что нового (`/sync-audit`).

---

## Что внутри этого репо

| Папка | Назначение |
|---|---|
| `commands/` | Slash-команды (`/plan`, `/code`, `/review`, `/deploy`, `/retro` и др.) |
| `templates/` | Шаблоны артефактов (CLAUDE.md, PRODUCT.md, триггеры, хуки) |
| `scripts/` | Bootstrap и sync скрипты |
| `skills/` | Agent Skills — knowledge-domain (secrets, marketing и др.) |
| `VERSION` | Текущая версия методологии |

Изменять файлы в этом репо не нужно — всё что тебе нужно уже скопируется в твой проект через `sync-methodology.sh`.

---

Версия методологии: см. [VERSION](VERSION)
