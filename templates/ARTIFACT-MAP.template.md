# ARTIFACT-MAP — {{Project Name}}

Карта **жизненного цикла артефактов**: какая команда обновляет какой файл, как часто, и где gap.
Дополняет [USER-MAP](USER-MAP.md) (что умеет пользователь) и [SYSTEM-MAP](../architecture/SYSTEM-MAP.md) (как устроено) слоем актуальности документов.

> ⚠️ Этот файл создаётся один раз при bootstrap с подстановкой `{{Project Name}}`. Не синхронизируется `sync-methodology.sh`. Проект владеет и поддерживает его самостоятельно.

---

## Диаграмма: команды ↔ артефакты

Цвета: синий = ядро · фиолетовый = периодические · пурпурный = стратегические · оранжевый = state · зелёный = артефакт · серый = актор.
Стрелки: `→` обновляет/создаёт · `-.->` читает/использует как input.

```mermaid
graph LR
    classDef core fill:#e1f5ff,stroke:#0288d1,color:#000
    classDef periodic fill:#e8eaf6,stroke:#3949ab,color:#000
    classDef strategic fill:#f3e5f5,stroke:#7b1fa2,color:#000
    classDef ok fill:#e8f5e9,stroke:#388e3c,color:#000
    classDef state fill:#fff3e0,stroke:#f57c00,color:#000
    classDef actor fill:#f5f5f5,stroke:#9e9e9e,color:#000
    %% Бизнес-события CRUD (раскомментируй для marketplace/ERP):
    %% classDef event fill:#fce4ec,stroke:#e91e63,color:#000

    subgraph CoreWF["🔁 Ядро (каждый цикл)"]
        Plan["/plan"]:::core
        Deploy["/deploy"]:::core
        Rev["/review"]:::core
    end

    subgraph Periodic["📊 Периодические (по счётчику)"]
        PCheck["/product-check"]:::periodic
        Arch["/architecture-audit"]:::periodic
        PReview["/product-review"]:::periodic
        Retro["/retro"]:::periodic
    end

    subgraph Strategic["🔭 Стратегические (редко / по событию)"]
        PVision["/product-vision"]:::strategic
        SyncV["/sync-vision<br/>⚡ по событию"]:::strategic
    end

    subgraph Actors["👤 Акторы (ручной / внешний триггер)"]
        Dev["👨‍💻 Developer"]:::actor
        Owner["👤 PM / Owner"]:::actor
        Sync["⚙️ sync-script"]:::actor
        %% Добавь акторов проекта:
        %% Role1["👤 [TODO: роль]"]:::actor
    end

    %% Бизнес-события CRUD (marketplace, ERP — раскомментируй если нужно):
    %% subgraph Events["⚡ Бизнес-события (CRUD)"]
    %%     EV1["⚡ [TODO: событие]<br/>напр. order.created"]:::event
    %%     EV2["⚡ [TODO: событие]<br/>напр. invoice.approved"]:::event
    %% end

    subgraph Live["📄 Артефакты"]
        TJ["triggers.json<br/>⬅ все команды"]:::state
        DL["DEVLOG.md<br/>история деплоев"]:::ok
        PROD["PRODUCT.md<br/>поведение продукта"]:::ok
        UM["USER-MAP.md<br/>карта возможностей"]:::ok
        SM["SYSTEM-MAP.md<br/>архитектура"]:::ok
        HY["HYPOTHESES.md<br/>гипотезы и аномалии"]:::ok
        OQ["OPEN-QUESTIONS.md<br/>открытые вопросы"]:::ok
        ID["IDEAS.md<br/>сигналы и идеи"]:::ok
        RM["ROADMAP.md<br/>план развития"]:::ok
        VI["VISION.md<br/>стратегия"]:::ok
        AM["ARTIFACT-MAP.md<br/>lifecycle карта"]:::ok
        RISKS["RISKS.md<br/>реестр рисков"]:::ok
        CLM["CLAUDE.md<br/>правила AI · ⬅ все команды"]:::ok
        ADR["docs/adr/<br/>архитектурные решения"]:::ok
        INB["inbox/<br/>входящие артефакты"]:::ok
        %% Добавь проектные артефакты:
        %% Custom1["[TODO: артефакт]<br/>[TODO: назначение]"]:::ok
    end

    Plan -->|"≥5 планов"| PCheck
    Plan -->|"≥5 планов"| Arch
    Plan -->|"≥10 планов"| PReview
    Plan -->|"≥15 планов"| Retro
    Plan -->|"≥30 планов"| PVision
    Plan -.->|"≥5 + событие"| SyncV
    %% Проектные cmd→cmd триггеры (добавь если есть):
    %% CmdA -->|"условие"| CmdB
    %% Примеры: sync-catalog -->|"ошибок > 5"| notify-ops
    %%           process-order -->|"каждый заказ"| update-inventory

    Plan -->|"инкремент счётчиков"| TJ
    Deploy -->|"last_deploy"| TJ
    PCheck -->|"last_product_check"| TJ
    PReview -->|"last_product_review"| TJ
    PVision -->|"last_product_vision"| TJ
    SyncV -->|"last_sync_vision"| TJ
    Retro -->|"last_retro"| TJ

    Deploy -->|"[deploy] запись"| DL
    Arch -->|"[architecture-audit]"| DL
    Retro -->|"[retro]"| DL

    PCheck -->|"проверка / сравнение"| PROD
    PReview -->|"может обновить"| PROD
    PCheck -->|"freshness ≥ 10"| UM
    Arch -->|"верификация"| SM
    Arch -->|"гипотезы"| HY
    Retro -->|"паттерны"| HY
    SyncV -->|"риски стратегии"| HY
    SyncV -->|"создаёт"| OQ
    PReview -->|"обрабатывает"| ID
    PVision -->|"планирование"| RM
    PVision -->|"стратегия"| VI
    SyncV -->|"может обновить"| VI

    Retro -->|"паттерны рисков"| RISKS
    Owner -->|"новый риск"| RISKS
    Owner -->|"риск закрыт"| RISKS
    Dev -->|"при изменении правил"| CLM
    Sync -->|"sync pull"| CLM
    Dev -->|"архитект. решение"| ADR
    Arch -->|"ревью статусов"| ADR

    Owner -->|"закрывает"| OQ
    PReview -->|"закрывает [reviewed]"| ID

    Plan -.->|"Шаг 0.7 check"| INB
    SyncV -->|"обрабатывает / _processed"| INB
    Owner -->|"кладёт файлы"| INB
    Dev -->|"кладёт файлы"| INB

    %% Акторы → проектные артефакты (добавь если есть):
    %% Dev -->|"[TODO: условие]"| Custom1
    %% Owner -->|"[TODO: условие]"| Custom1
    %% Бизнес-события → артефакты (CRUD):
    %% EV1 -->|"lifecycle изменился"| Custom1
    %% EV2 -->|"статус изменился"| Custom2

    %% --- Read flow: артефакт → потребитель ---
    VI  -.->|"стратег. контекст"| Plan
    RM  -.->|"горизонт планирования"| Plan
    HY  -.->|"верификация гипотез"| Plan
    OQ  -.->|"блокирует / check"| Plan
    ID  -.->|"сигналы"| Plan
    DL  -.->|"паттерны"| Retro
    DL  -.->|"повторный фикс"| Rev
    SM  -.->|"верификация"| Rev
    ADR -.->|"контракты"| Rev
    %% [TODO: добавь проектные read-стрелки: Custom1 -.->|"контекст"| Plan]
```

> **Легенда:** `→` обновляет · `-.->` читает/использует · Артефакт без входящих `-.->` = кандидат на рудимент

---

## Command Reference

### Стандартные команды методологии

| Команда | Назначение | Частота | Обновляет |
|---|---|---|---|
| `/plan` | Анализ задачи: риски, архитектура, план до первой строки кода | 🔁 каждый цикл | `triggers.json` |
| `/deploy` | Публикация изменений + обязательная запись истории | 🔁 каждый цикл | `DEVLOG.md`, `triggers.json` |
| `/review` | Архитектурное ревью изменений до деплоя | 🔁 каждый цикл | — (только анализ) |
| `/product-check` | Соответствие PRODUCT.md реальному поведению | 📊 ≥5 планов | `PRODUCT.md`, `USER-MAP.md` |
| `/architecture-audit` | Drift SYSTEM-MAP vs реальный код — ищет расхождения | 📊 ≥5 планов | `SYSTEM-MAP.md`, `HYPOTHESES.md`, `DEVLOG.md` |
| `/product-review` | Обработка накопленных IDEAS.md сигналов → решения | 📊 ≥10 планов | `IDEAS.md`, `PRODUCT.md` |
| `/retro` | Паттерны проблем за N планов — системные причины | 📊 ≥15 планов | `HYPOTHESES.md`, `DEVLOG.md` |
| `/sync-vision` | Стратегия vs реальность при изменении контрактов | ⚡ по событию | `VISION.md`, `OPEN-QUESTIONS.md`, `HYPOTHESES.md` |
| `/product-vision` | Стратегический обзор: VISION + ROADMAP обновление | 🔭 ≥30 планов | `VISION.md`, `ROADMAP.md` |

### Проектные команды (если есть)

Если в проекте есть дополнительные команды (cron-jobs, миграции, sync-скрипты) — добавь их сюда.

| Команда / Скрипт | Назначение | Частота | Обновляет |
|---|---|---|---|
| `[TODO: команда]` | `[TODO: что делает]` | `[TODO: частота]` | `[TODO: артефакты]` |
| *Пример маркетплейс:* `bash sync-catalog.sh` | Синхронизирует каталог товаров с внешним поставщиком | по расписанию / вручную | `docs/product/catalog.md` |

---

## Artifact Reference

### Стандартные артефакты методологии

| Артефакт | Назначение | Условие обновления | Пишет / Актор | Читает | Закрывает | Частота |
|---|---|---|---|---|---|---|
| `triggers.json` | State-машина методологии: счётчики, даты, статус сессии | автоматически при каждом `/plan` и `/deploy` | `/plan`, `/deploy` | все команды (state check) | — | 🔁 каждый цикл |
| `DEVLOG.md` | Хронология проекта: деплои, решения, milestones | каждый деплой — обязательно | `/deploy` | `/retro`, `/review`, `/product-vision` | — | 🔁 каждый деплой |
| `PRODUCT.md` | Спецификация поведения продукта с точки зрения пользователя | `last_product_check.plans_since ≥ 5` | `/product-check`, `/product-review` | `/plan`, `/product-check` | — | 📊 ~5 планов |
| `docs/product/USER-MAP.md` | Визуальная карта возможностей пользователей (Mermaid) | `last_user_map_sync.plans_since ≥ 10` или `[TODO:]` найдены | `/product-check` | Developer, PM/Owner | — | 📊 ~10 планов |
| `docs/architecture/SYSTEM-MAP.md` | Архитектурная карта: компоненты, связи, границы модулей | `plans_since ≥ 5` | `/architecture-audit` | `/review`, `/architecture-audit`, Developer | — | 📊 ~5 планов |
| `HYPOTHESES.md` | Гипотезы о поведении системы, наблюдения, аномалии | при аудите / ретро / sync-vision | `/architecture-audit`, `/retro`, `/sync-vision` | `/plan` (Шаг -1.5), `/retro` | — | 📊 ~5–15 планов |
| `OPEN-QUESTIONS.md` | Открытые вопросы, требующие решения команды или PM | при изменении контрактов | `/sync-vision`, `/plan` | `/plan` (Шаг -3.3), `/retro`, PM/Owner | PM / Owner | ⚡ по событию |
| `inbox/` | Очередь внешних входящих документов: VCD, specs, анализы — ждут обработки | при получении внешнего документа | PM / Owner / Developer | `/plan` (Шаг 0.7), `/sync-vision` | `/sync-vision`, `/plan` → `_processed/` | ⚡ по событию |
| `IDEAS.md` | Сырые сигналы: боль пользователей, идеи, friction | `plans_since ≥ 10` или ≥ 7 unreviewed | Developer, `/plan` | `/product-review`, `/plan` (Шаг 1.6) | `/product-review` | 📊 ~10 планов |
| `ROADMAP.md` | Стратегический план: что делаем и когда | `plans_since ≥ 30` | `/product-vision` | `/plan` (Шаг 1.5), Developer, PM/Owner | — | 🔭 ~30 планов |
| `VISION.md` | Стратегические оси, долгосрочные цели продукта | `plans_since ≥ 30` или при контракт-изменениях | `/product-vision`, `/sync-vision` | `/plan`, `/product-review`, `/sync-vision` | — | 🔭 ~30 планов |
| `docs/product/ARTIFACT-MAP.md` | Lifecycle карта артефактов (этот файл) | при добавлении команды / артефакта / актора | Developer | Developer, `/review` | — | ручное |
| `RISKS.md` | Реестр рисков: угрозы, вероятность, mitigation | при `/retro` или новом риске | `/retro`, PM / Owner | `/plan`, PM/Owner, Developer | PM / Owner | 📊 ~15 планов |
| `CLAUDE.md` | Правила работы AI-агентов в проекте | при sync pull или изменении правил | Developer, sync-script | все команды (rules) | — | ⚡ по событию |
| `docs/adr/` | Архитектурные решения и их обоснование | при архитектурном решении | Developer | `/review` (Шаг 2), `/architecture-audit`, `/sync-vision` | Developer (deprecated) | ⚡ по решению |

### Проектные артефакты (заполнить)

Добавь все значимые документы проекта которые требуют поддержки актуальности.

**Откуда брать список артефактов:**
1. Открой `PRODUCT.md` — каждая ключевая сущность (orders, invoices, users, flows) может иметь свой doc-артефакт
2. Пройди по всем файлам в `docs/` и корне проекта
3. **Для каждого артефакта обязательно указать триггер.** Если кажется что его нет — ищи внимательнее. Ручное / CRUD / событийное — тоже триггер.

> ⚠️ Артефакт в этой карте = **документ** который описывает сущность или процесс, не сама сущность.
> Для маркетплейса: `orders.md` = спецификация флоу заказов (lifecycle, статусы, правила); сама таблица `orders` — это данные, не артефакт.

**Примеры по типу проекта:**

| Тип проекта | Возможные doc-артефакты | Пишет / Актор | Читает | Закрывает |
|---|---|---|---|---|
| Маркетплейс | `docs/product/orders.md`, `docs/product/invoices.md`, `docs/product/catalog.md` | `/product-check`, `order.created` (CRUD) | Developer, PM | PM (статус deprecated) |
| CRM / продажи | `docs/product/customers.md`, `docs/product/pipelines.md` | `/product-review`, Owner | Developer, Owner | — |
| ИИ-бот / агент | `docs/product/prompts.md`, `docs/product/conversation-flows.md` | `/product-check`, Developer | Developer, `/review` | — |
| API-сервис | `docs/api-contracts.md`, `docs/rate-limits.md` | `/sync-vision`, Developer | Developer, `/review` | Developer (v-deprecated) |
| Внутренний инструмент | `docs/product/user-roles.md`, `docs/product/permissions.md` | `/product-check`, PM | Developer, PM | PM (роль удалена) |

| Артефакт | Назначение | Условие обновления | Пишет / Актор | Читает | Закрывает | Частота |
|---|---|---|---|---|---|---|
| `[TODO: артефакт]` | `[TODO: что описывает из PRODUCT.md]` | `[TODO: когда обновлять]` | `[TODO: актор / команда]` | `[TODO: кто читает]` | `[TODO: кто закрывает или —]` | `[TODO: частота]` |

---

## Ручные триггеры (риск пропуска)

> **Правило: у каждого артефакта есть триггер.** Если кажется что его нет — ищи внимательнее. Ручное обновление тоже триггер: укажи кто (Developer / PM / Owner) и при каком событии. Артефакт без триггера = документ который никто не поддерживает = устаревший.

Артефакты с ручным триггером требуют дисциплины — добавь их сюда:

| Артефакт | Триггер | Актор | Риск если не обновлять |
|---|---|---|---|
| `RISKS.md` | `/retro` (паттерны) или новый риск | PM / Owner | Устаревший threat landscape |
| `CLAUDE.md` | sync pull или изменение правил | Developer | Правила расходятся с практикой |
| `docs/adr/` | архитектурное решение или `/architecture-audit` | Developer | ADR противоречат текущей архитектуре |
| `inbox/` | Получен новый внешний документ | PM / Owner / Developer | Документ не обработан → план и sync-vision работают с устаревшими данными |
| `[TODO: артефакт]` | `[TODO: триггер]` | `[TODO: актор]` | `[TODO: риск]` |

---

## Refresh Policy

Обновлять этот файл когда:
- Добавлена новая команда (`/X`) → добавить строку в Command Reference + node в диаграмму
- Добавлен новый тип артефакта → добавить строку в Artifact Reference + node в диаграмму
- Появился новый актор (Developer, PM, скрипт, CRUD-событие) → добавить в Actors / Events subgraph
- Изменился порог триггера → обновить колонку "Частота" и стрелку Plan→команда в диаграмме
- Ручной триггер автоматизирован → убрать из "Ручные триггеры", обновить Актор в таблице
- Артефакт без входящих `-.->` в диаграмме И с `Читает = —` → кандидат на рудимент: проверить при `/retro`

`/review` проверяет: новая команда или артефакт → ARTIFACT-MAP обновлён?
