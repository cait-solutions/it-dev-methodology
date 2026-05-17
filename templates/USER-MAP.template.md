# USER-MAP — {{Project Name}}

This artifact has **two parts**:
- **Part 1: Dev Setup** — how developers and PM work with the three-repo structure. Near-complete skeleton, minimal customization.
- **Part 2: Product Capabilities** — what end users of {{Project Name}} can do. Fully customizable per project type.

> ⚠️ This file is created ONCE during bootstrap with `{{Project Name}}` substitution. It is NOT synced by `sync-methodology.sh`. Your project owns and maintains this diagram.

---

## Требования к диаграммам

**Mermaid обязателен.** USER-MAP (как и SYSTEM-MAP) всегда содержит Mermaid-диаграмму. Замена на ASCII/текст запрещена.

**Все стрелки подписаны.** Стрелка без метки — это неоднозначность. Каждая связь должна объяснять что происходит.

**Гибридный язык (EN + RU):**
- EN: команды (`git pull`, `/deploy → git push`, `triggers.json → /plan`), имена файлов, технические термины
- RU: описания действий (`копирует + баннер`, `создаёт артефакты`, `анализирует сигналы`)

**Типы стрелок:** `-->` сплошная — активное действие; `-.->` пунктирная — чтение / пассивная связь.

**Repo / setup контекст обязателен.** Новый разработчик должен понять из диаграммы откуда берутся команды и куда деплоится код.

---

## Part 1: Dev / Methodology Setup

Общая структура для всех проектов на этой методологии. Кастомизируй только узел отмеченный `[TODO]`.

```mermaid
graph TD
    Dev["👤 Dev / Team Lead"]
    PM["👤 Project Manager"]

    subgraph Remote["☁️ Remote Git"]
        RemoteNode["it-dev-methodology ·<br/>{{Project Name}}-documentation · Код проекта"]
    end

    subgraph Local["💻 Локальная машина разработчика"]
        subgraph Methodology["it-dev-methodology (git, канон)"]
            Canon["📦 commands/ + hooks/ + templates/<br/>единственный источник правды"]
        end
        subgraph DocRepo["{{Project Name}}-documentation (git, workspace)"]
            LocalCmds["⚙️ Инструменты методологии<br/>.claude/commands/ + .claude/hooks/<br/>gitignored — восстанавливается sync"]
            Storage["💾 Артефакты проекта<br/>CLAUDE.md, PRODUCT.md, VISION.md,<br/>SYSTEM-MAP.md, DEVLOG.md,<br/>HYPOTHESES.md, triggers.json"]
        end
        subgraph CodeRepos["Код проекта (git)"]
            Services["💻 [TODO: тип кода]<br/>монолит / микросервисы / bot+webhook"]
        end
    end

    Dev -->|"Новый проект"| Init["🚀 Initialize Project<br/>$ bash new-project-init.sh<br/>однократно, из терминала"]
    Dev -->|"Присоединиться к проекту"| Onboard["🧭 /onboard<br/>ориентация нового разработчика<br/>(после git clone + sync)"]
    Dev -->|"Начало цикла"| Workflow["🔄 Workflow Cycle<br/>/plan → /code → /review → /deploy"]
    Dev -->|"Обновить методологию"| Sync["🔄 Sync Methodology<br/>$ bash sync-methodology.sh<br/>из терминала"]

    PM -.->|"анализирует сигналы"| Storage
    PM -->|"улучшает инструменты"| Canon

    Remote -.->|"git pull"| Canon
    Sync -.->|"читает"| Canon
    Canon -->|"копирует + баннер"| LocalCmds
    Init -->|"копирует команды"| LocalCmds
    Init -->|"создаёт артефакты"| Storage
    Onboard -.->|"читает контекст"| Storage
    Workflow -->|"читает / обновляет"| Storage
    Workflow -->|"пишет"| Services
    Workflow -->|"/deploy → git push"| RemoteNode

    Workflow -->|"каждые ~5 циклов"| Audit["🏗️ /architecture-audit<br/>drift vs SYSTEM-MAP"]
    Workflow -->|"при контракт-изменениях"| Vision["👁️ /sync-vision<br/>реальность vs стратегия"]
    Workflow -->|"каждые ~15 циклов"| Retro["🔁 /retro<br/>анализ накопленного"]
    Workflow -->|"каждые ~10 циклов"| ProductHealth["📋 /product-review<br/>/product-check · /product-vision"]

    Audit -->|"пишет в"| Storage
    Vision -->|"пишет в"| Storage
    Retro -->|"пишет в"| Storage
    ProductHealth -->|"пишет в"| Storage
    Storage -.->|"triggers.json → /plan"| Workflow

    style Dev fill:#e1f5ff
    style PM fill:#e1f5ff
    style Init fill:#fff3e0
    style Onboard fill:#fff3e0
    style Workflow fill:#f3e5f5
    style Sync fill:#fff3e0
    style Canon fill:#fff8e1
    style LocalCmds fill:#fce4ec
    style Storage fill:#fce4ec
    style Services fill:#e3f2fd
    style RemoteNode fill:#f5f5f5
    style Audit fill:#e8f5e9
    style Vision fill:#e8f5e9
    style Retro fill:#e8f5e9
    style ProductHealth fill:#e8f5e9
```

### Легенда

| Элемент | Тип узла |
|---|---|
| 👤 | Актор (человек) |
| 📦 | Источник правды (канон) |
| ⚙️ | Инструменты методологии (gitignored) |
| 💾 | Хранилище артефактов проекта |
| 💻 | Код проекта (сервисы, монолит, bot) |
| 🚀🧭🔄 | Точки входа / действия разработчика |
| 🏗️👁️🔁📋 | Периодические команды методологии |

### Node Vocabulary

Используй точно эти имена — так же в SYSTEM-MAP, PRODUCT.md, DEVLOG. Синонимы создают путаницу при поиске.

| Каноническое имя | Не использовать |
|---|---|
| Артефакты проекта | project files, документы, docs, artifacts |
| Инструменты методологии | команды, scripts, tools, commands |
| Workflow Cycle | dev cycle, рабочий процесс, pipeline |
| единственный источник правды | source of truth, канон (только в комментариях) |
| `{{Project Name}}-documentation` | project repo, docs repo, project-docs |
| Код проекта | source code, codebase, services (в общем контексте) |

### Что кастомизировать в Part 1

- **`[TODO: тип кода]`** — замени на реальное описание: `монолит + React frontend`, `Telegram bot + webhook server`, `N микросервисов (auth, api, worker)`. После замены удали `[TODO: ...]`.
- Если docs и code в **одном репо** — объедини subgraph-и `DocRepo` и `CodeRepos` в один.

---

## Part 2: Product Capabilities

Что могут делать **конечные пользователи продукта** (не разработчики). Выбери вариант по сложности.

| Вариант | Когда | Структура |
|---------|-------|-----------|
| **A (Simple)** | До 5 возможностей, одна роль | Дерево возможностей |
| **B (Medium)** | Несколько ролей с разными workflow | Workflow по ролям + матрица |
| **C (Complex)** | 10+ возможностей, несколько доменов | Три уровня: workflow + домены + данные |

Если не уверен — **начни с Variant A**. Эволюция: A → B → C по мере роста.

---

### Variant A — Simple

```mermaid
graph TD
    User["👤 Пользователь"]

    User -->|"инициирует"| Cap1["📦 [TODO: Возможность 1]<br/>(что делает)"]
    User -->|"использует"| Cap2["⚙️ [TODO: Возможность 2]<br/>(что делает)"]
    User -->|"получает результат"| Cap3["📊 [TODO: Возможность 3]<br/>(что делает)"]

    Cap1 -->|"сохраняет"| Storage["💾 [TODO: Хранилище]<br/>(что хранится)"]
    Cap2 -->|"сохраняет"| Storage
    Cap3 -.->|"читает"| Storage

    Cap3 -->|"отправляет в"| Output["📤 [TODO: Получатель]<br/>(куда идёт результат)"]

    style User fill:#e1f5ff
    style Cap1 fill:#fff3e0
    style Cap2 fill:#f3e5f5
    style Cap3 fill:#e8f5e9
    style Storage fill:#fce4ec
    style Output fill:#fce4ec
```

**Замени `[TODO: ...]` узлы:**
- `Возможность 1, 2, 3` → реальные фичи продукта
- `Хранилище` → что хранится (БД, облако, файл)
- `Получатель` → куда уходит результат (API, чат, файл)

**Примеры:**

ERP: `Cap1: Управление каталогом` / `Cap2: Создание заказов` / `Cap3: Экспорт на платформу` / `Storage: БД товаров + история` / `Output: API платформы`

Telegram bot: `Cap1: Создание задач из сообщений` / `Cap2: Напоминания по расписанию` / `Cap3: Экспорт в календарь` / `Storage: Список задач` / `Output: Calendar API + Telegram`

---

### Variant B — Medium (Несколько ролей)

Для проектов где разные пользователи взаимодействуют по-разному.

```mermaid
graph TD
    subgraph WorkflowA["Workflow A: Администратор"]
        Admin["👤 Admin"]
        Admin -->|"настраивает"| Cap1A["инициализация системы"]
        Cap1A -->|"создаёт"| Data1["конфигурация + базовые данные"]
    end

    subgraph WorkflowB["Workflow B: Пользователь"]
        UserB["👤 User"]
        UserB -->|"создаёт / редактирует"| Cap2B["работа с объектами"]
        Cap2B -->|"сохраняет"| Data2["хранилище объектов"]
        Data2 -.->|"читает"| Cap3B["запросы / отчёты"]
    end

    subgraph WorkflowC["Workflow C: Интеграция"]
        External["🔌 Внешняя система"]
        Data2 -->|"экспортирует"| External
        External -->|"обновляет"| Data2
    end
```

**Матрица ролей:**

| Возможность | Admin | User | Внешняя система |
|---|---|---|---|
| Создать / редактировать | ✓ | ✓ (свои) | ✓ (API) |
| Удалить | ✓ | ✗ | ✗ |
| Просмотр аналитики | ✓ | ✗ | ✓ (read-only) |
| Экспорт данных | ✓ | ✓ (свои) | ✓ |

---

### Variant C — Complex (Multi-domain)

```mermaid
graph TD
    User1["👤 Пользователь домена A"]
    User2["👤 Пользователь домена B"]

    User1 -->|"выполняет"| WF1["Workflow A<br/>цель → действие → результат"]
    User2 -->|"выполняет"| WF2["Workflow B<br/>цель → действие → результат"]

    WF1 -->|"использует"| DomA["Домен A"]
    WF2 -->|"использует"| DomB["Домен B"]

    DomA -->|"читает / пишет"| SharedData["💾 Общий слой данных<br/>единственный источник правды"]
    DomB -->|"читает / пишет"| SharedData

    SharedData -->|"публикует"| IntA["Выход A"]
    SharedData -->|"публикует"| IntB["Выход B"]
```

---

## Refresh Policy

**Обновлять USER-MAP когда:**
- Добавлена новая крупная возможность продукта
- Изменился workflow между возможностями
- Новый тип пользователя с отдельным workflow
- Изменился получатель результата (новый API, платформа)
- Изменилась структура репозиториев (новый сервис, объединение репо)

**Не обновлять при:**
- Внутреннем рефакторинге (пользователь не видит)
- Багфиксах
- Улучшении производительности

**Sync trigger:** `.claude/state/triggers.json` — поле `last_user_map_sync`.

---

## Bootstrap (для новых проектов)

При запуске `new-project-init.sh`:
1. Этот файл копируется в `docs/product/USER-MAP.md`
2. `{{Project Name}}` автоматически подставляется
3. Заполни `[TODO: тип кода]` в Part 1 под реальный стек
4. Выбери вариант Part 2 (начни с A)
5. Удали инструкционные комментарии после заполнения
6. PRODUCT.md — детальное поведение; USER-MAP — верхний уровень

---

## Notes

- Part 1 (Dev Setup) показывает **пользовательские возможности разработчика** — /plan, /code и т.п. здесь допустимы как user capabilities
- Part 2 (Product Capabilities) показывает **возможности конечных пользователей продукта**
  - ✅ "Создать статью", "Экспорт в API", "Синхронизация с облаком"
  - ❌ "REST endpoint", "Async queue", "database connection" — внутренняя реализация
- Диаграммы максимум **2-3 уровня глубины** — детали идут в PRODUCT.md
- USER-MAP = "что умеет пользователь"; SYSTEM-MAP = "как оно устроено внутри"
