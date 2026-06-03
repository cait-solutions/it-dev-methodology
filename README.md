# IT Dev Methodology

AI-assisted разработка: slash-команды, шаблоны, хуки, скрипты — единый источник правды для всех проектов.

---

## Для нового разработчика — начни здесь

Проект уже создан. Тебе нужно развернуть его на своей машине.

### Шаг 1. Структура папок

Создай одну папку-контейнер. Внутри неё будут три репозитория — спроси у PM точные названия:

```
my-project/                          ← папка-контейнер (создай вручную)
├── it-dev-methodology/              ← этот репо (методология)
├── my-project-documentation/        ← артефакты, команды, архитектура
└── my-project-backend/              ← код проекта (если есть)
```

### Шаг 2. Клонируй репозитории

```bash
git clone https://github.com/cait-solutions/it-dev-methodology
git clone https://github.com/<org>/<my-project-documentation>
git clone https://github.com/<org>/<my-project-backend>   # если есть
```

> `it-dev-methodology` — публичный, клонируется без токена.
> Остальные репо — приватные. Перед клоном установи [GitHub CLI](https://cli.github.com) и выполни `gh auth login`.

### Шаг 3. Восстанови команды

Команды методологии не хранятся в git — их нужно восстановить на своей машине.

Открой папку `my-project-documentation/` в Claude Code (расширение для [VS Code](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code) или [JetBrains](https://plugins.jetbrains.com/plugin/24819-claude-code)) и напиши агенту:

> «Запусти sync-methodology.sh из папки it-dev-methodology чтобы восстановить команды методологии в этом проекте»

Или через терминал из папки `my-project-documentation/`:

```bash
bash ../it-dev-methodology/scripts/sync-methodology.sh .
```

### Шаг 4. Онбординг

В Claude Code с открытой папкой `my-project-documentation/` запусти:

```
/onboard
```

Команда покажет архитектуру проекта и что делать дальше.

---

## Обновление методологии

Когда PM сообщил что вышла новая версия — запусти в Claude Code:

```
/sync-audit
```

---

Версия методологии: см. [VERSION](VERSION)
