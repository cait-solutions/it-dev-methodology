# ARTIFACT-MAP — {{Project Name}}

Карта **жизненного цикла артефактов**: какая команда обновляет какой файл, как часто, и где gap.
Дополняет [USER-MAP](USER-MAP.md) (что делает user → actor/trigger/entity/outcome) и [SYSTEM-MAP](../architecture/SYSTEM-MAP.md) (как устроено внутри) слоем актуальности документов.
ARTIFACT-MAP отвечает на вопрос "кто владеет этим файлом и когда он обновляется"; USER-MAP отвечает на вопрос "что делает пользователь и что получает".

> ⚠️ Этот файл создаётся один раз при bootstrap с подстановкой `{{Project Name}}`. Не синхронизируется `sync-methodology.sh`. Проект владеет и поддерживает его самостоятельно.

---

## Обзор: командные группы → артефакты

> 🔗 [Открыть в Mermaid Live](<url>)
> _(обновить ссылку: `py scripts/mermaid-link.py docs/product/ARTIFACT-MAP.md` — извлекает первый mermaid-блок)_

```mermaid
graph LR
    subgraph Cmd["Команды"]
        CORE["🔁 Ядро<br/>/plan · /code · /review · /deploy"]
        PER["📅 Периодические<br/>/retro · /arch-audit · /product-check"]
        STR["🎯 Стратегические<br/>/product-vision · /product-review"]
    end
    subgraph Art["Артефакты"]
        PROD["📄 [TODO: spec doc]<br/>что обещано"]
        STATE["⚙️ DEVLOG.md · triggers.json<br/>история · счётчики"]
    end
    CORE -.->|"читают"| PROD
    CORE -->|"пишут"| STATE
    PER -.->|"читают"| STATE
    PER -->|"обновляют"| STATE
    STR -.->|"читают"| PROD
    STR -->|"обновляют"| PROD
```

> **Паттерн для больших диаграмм:** если URL полной диаграммы > 2000 символов (предупреждение от `mermaid-link.py`), добавь section "Обзор" (compact, первый блок = кликабельный) + section "Полная карта" (детали, copy-paste).

---

## Полная карта: команды ↔ артефакты

Цвета: синий = ядро · фиолетовый = периодические · пурпурный = стратегические · оранжевый = state · зелёный = артефакт · серый = актор.
Стрелки: `-->` пишет (W) · `-.->` читает (R) · `===` читает+пишет (RW) · `--x` закрывает (C)

> Для редактирования полной карты: `py scripts/mermaid-link.py --all docs/product/ARTIFACT-MAP.md` → **второй** URL → вставить в браузер

```mermaid
graph LR
    classDef core fill:#e1f5ff,stroke:#0288d1,color:#000
    classDef periodic fill:#e8eaf6,stroke:#3949ab,color:#000
    classDef strategic fill:#f3e5f5,stroke:#7b1fa2,color:#000
    classDef ok fill:#e8f5e9,stroke:#388e3c,color:#000
    classDef state fill:#fff3e0,stroke:#f57c00,color:#000
    classDef actor fill:#f5f5f5,stroke:#9e9e9e,color:#000
    classDef legend fill:#ffffff,stroke:#cccccc,color:#666666
    %% Бизнес-события CRUD (раскомментируй для marketplace/ERP):
    %% classDef event fill:#fce4ec,stroke:#e91e63,color:#000

    subgraph CoreWF["🔁 Ядро (каждый цикл)"]
        Plan["/plan<br/>анализ · риски · план"]:::core
        Code["/code<br/>реализация по плану"]:::core
        Deploy["/deploy<br/>деплой + история"]:::core
        Rev["/review<br/>ревью до деплоя"]:::core
    end

    subgraph Periodic["📊 Периодические (по счётчику)"]
        PCheck["/product-check<br/>freshness PRODUCT.md"]:::periodic
        Arch["/architecture-audit<br/>структурный аудит · SYSTEM-MAP + AGENT-GAPS + Level 4+ ladder"]:::periodic
        PReview["/product-review<br/>обработка IDEAS"]:::periodic
        Retro["/retro<br/>тактическая гигиена · сигналы → /architecture-audit"]:::periodic
    end

    subgraph Strategic["🔭 Стратегические + Ad-hoc (редко / по событию)"]
        PVision["/product-vision<br/>обзор VISION+ROADMAP"]:::strategic
        SyncV["/sync-vision<br/>стратегия vs реальность · ⚡"]:::strategic
        Diag["/diagnose<br/>root-cause анализ · ⚡"]:::strategic
    end

    subgraph Actors["👤 Акторы (ручной / внешний триггер)"]
        Dev["👨‍💻 Developer"]:::actor
        Owner["👤 PM / Owner"]:::actor
        Sync["⚙️ sync-script"]:::actor
        %% Добавь акторов проекта:
        %% Role1["👤 [TODO: роль]"]:::actor
        %% AgentAI["🤖 AI Agent<br/>(если пишет напрямую)"]:::actor
    end

    %% Бизнес-события CRUD (marketplace, ERP — раскомментируй если нужно):
    %% subgraph Events["⚡ Бизнес-события (CRUD)"]
    %%     EV1["⚡ [TODO: событие]<br/>напр. order.created"]:::event
    %%     EV2["⚡ [TODO: событие]<br/>напр. invoice.approved"]:::event
    %% end

    subgraph Live["📄 Артефакты"]
        TJ["triggers.json<br/>план · деплой · периодические"]:::state
        DL["DEVLOG.md<br/>история деплоев"]:::ok
        PROD["PRODUCT.md<br/>поведение продукта"]:::ok
        UM["USER-MAP.md<br/>карта возможностей"]:::ok
        SM["SYSTEM-MAP.md<br/>архитектура"]:::ok
        HY["HYPOTHESES.md<br/>гипотезы и аномалии"]:::ok
        AG["AGENT-GAPS.md<br/>пропуски AI · сигнал методологии"]:::ok
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

    %% --- W: команда пишет артефакт (-->) ---
    Deploy -->|"[deploy] запись"| DL
    Arch -->|"[architecture-audit]"| DL

    PReview -->|"может обновить"| PROD
    PCheck -.->|"freshness check"| UM
    SyncV -->|"Type B → риски"| RISKS
    SyncV -->|"создаёт"| OQ
    Sync -->|"sync pull"| CLM
    Arch -.->|"ревью статусов"| ADR

    Plan -.->|"Шаг 0.7 check"| INB
    SyncV -.->|"читает"| INB
    Owner -->|"кладёт файлы"| INB
    Dev -->|"кладёт файлы"| INB
    Code ===|"если изм. архитектуру"| SM
    Code ===|"если изм. поведение"| PROD
    Code ===|"если изм. правила"| CLM
    Code ===|"если реализовано ADR"| ADR
    Code ===|"если изм. возможности"| UM
    PCheck -.->|"freshness check"| AM
    Rev  -->|"out-of-scope findings"| ID
    SyncV -->|"[sync-vision] запись"| DL
    Retro ===|"missed-signal"| ID

    %% --- C: закрывает / архивирует записи (--x) ---
    %% (PM/Owner --x RISKS/OQ — ручная операция, не систематический поток; не показывается в диаграмме)
    %% Добавь --x стрелки для project-specific артефактов где есть команда-закрыватель:
    %% CmdX --x|"архивирует"| CustomArtifact

    %% Акторы → проектные артефакты (добавь если есть):
    %% Dev -->|"[TODO: условие]"| Custom1
    %% Owner -->|"[TODO: условие]"| Custom1
    %% Бизнес-события → артефакты (CRUD):
    %% EV1 -->|"lifecycle изменился"| Custom1
    %% EV2 -->|"статус изменился"| Custom2

    %% --- RW: команда читает И пишет артефакт (===, оранжевый) ---
    Arch    -.->|"drift check"| SM
    PCheck  ===|"актуальность"| PROD
    PReview ===|"обработка / [reviewed]"| ID
    Plan    ===|"capture / сигналы"| ID
    Retro   ===|"паттерны"| HY
    Retro   ===|"история"| DL
    Diag    ===|"гипотезы"| HY
    PVision ===|"стратегия"| VI
    PVision ===|"план"| RM
    SyncV   ===|"sync vs реальность"| VI

    %% --- RW: triggers.json (читают все команды, пишут при завершении) ---
    Plan    ===|"счётчики + сессия"| TJ
    Deploy  ===|"last_deploy"| TJ
    PCheck  ===|"last_product_check"| TJ
    Retro   ===|"last_retro"| TJ
    Arch    ===|"last_architecture_audit"| TJ
    PVision ===|"last_product_vision"| TJ
    SyncV   ===|"last_sync_vision"| TJ

    %% --- R: читает как input (-.->), только те что не покрыты RW выше ---
    %% /plan
    VI    -.->|"стратег. контекст"| Plan
    RM    -.->|"горизонт планирования"| Plan
    HY    -.->|"верификация гипотез"| Plan
    OQ    -.->|"блокирует / check"| Plan
    RISKS -.->|"контекст рисков"| Plan
    %% /review
    DL  -.->|"повторный фикс"| Rev
    SM  -.->|"верификация"| Rev
    ADR -.->|"контракты"| Rev
    AM  -.->|"lifecycle check"| Rev
    %% /product-review
    DL -.->|"за 14 дней"| PReview
    VI -.->|"оси стратегии"| PReview
    %% /retro
    OQ -.->|"stale check"| Retro
    VI -.->|"alignment"| Retro
    %% /diagnose
    DL -.->|"паттерн [fix:X]"| Diag
    %% [TODO: добавь проектные read-стрелки: Custom1 -.->|"контекст"| Plan]

    SyncV --x|"→ _processed"| INB

    %% --- /architecture-audit reads AGENT-GAPS (Способность B) ---
    AG -.->|"паттерны gaps"| Arch

    %% --- /retro эскалирует структурные сигналы → /architecture-audit ---
    Retro -.->|"структурный сигнал"| Arch

    subgraph Legend["📖 Легенда типов связей"]
        direction LR
        W1(( )):::legend -->|"W · пишет"| W2(( )):::legend
        R1(( )):::legend -.->|"R · читает"| R2(( )):::legend
        RW1(( )):::legend ===|"RW · читает+пишет"| RW2(( )):::legend
        C1(( )):::legend --x|"C · закрывает"| C2(( )):::legend
    end

    %% RW (===) edge indices: 18-22 (Code×5), 26 (Retro→ID), 28-36 (RW block), 37-43 (TJ block), 63 (Legend)
    linkStyle 18,19,20,21,22,26,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,63 stroke:#ff8c00,stroke-width:3px
```

> **Легенда:** `-->` пишет (W) · `-.->` читает (R) · `===` читает+пишет (RW, оранжевый) · `--x` закрывает (C) · Артефакт без входящих стрелок = кандидат на рудимент

---

## Command Reference

### Стандартные команды методологии

| Команда | Назначение | Частота | Обновляет |
|---|---|---|---|
| `/plan` | Анализ задачи: риски, архитектура, план до первой строки кода | 🔁 каждый цикл | `triggers.json`, `IDEAS.md` (Шаг 0.2/100) |
| `/code` | Реализация плана: обновляет документацию по результату изменений | 🔁 каждый цикл | `SYSTEM-MAP.md`, `docs/adr/`, `PRODUCT.md`, `CLAUDE.md` (по условию Шаг 5) |
| `/deploy` | Публикация изменений + обязательная запись истории | 🔁 каждый цикл | `DEVLOG.md`, `triggers.json` |
| `/review` | Архитектурное ревью изменений до деплоя | 🔁 каждый цикл | `IDEAS.md` (out-of-scope findings) |
| `/product-check` | Соответствие PRODUCT.md реальному поведению | 📊 ≥5 планов | `PRODUCT.md`, `triggers.json` (user-map-sync) |
| `/architecture-audit` | Структурный аудит: SYSTEM-MAP↔code drift + gap pattern analysis (AGENT-GAPS) + Level 4+ ladder + decommission. Способности активируются по наличию артефактов | 📊 ≥5 планов или `agent_gaps_open_count ≥ 10` | `DEVLOG.md`, `triggers.json` (recommendations[]) |
| `/product-review` | Обработка накопленных IDEAS.md сигналов → решения | 📊 ≥10 планов | `IDEAS.md`, `PRODUCT.md` |
| `/retro` | Тактическая гигиена проекта: skip rates, stale OQ, reminder health, паттерны DEVLOG. Эскалирует структурные сигналы в `/architecture-audit` | 📊 ≥15 планов | `HYPOTHESES.md`, `DEVLOG.md`, `IDEAS.md` (Шаг 8 missed-signal) |
| `/diagnose` | Глубокий root-cause анализ при повторном `[fix:X]` — 3+ гипотезы, Capable tier | ⚡ при `[fix:X]` ≥2 за 7 дней | `HYPOTHESES.md` |
| `/sync-vision` | Стратегия vs реальность при изменении контрактов | ⚡ по событию | `VISION.md`, `OPEN-QUESTIONS.md`, `RISKS.md` (Type B), `DEVLOG.md` |
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
| `DEVLOG.md` | Хронология проекта: деплои, решения, milestones | каждый деплой — обязательно | `/deploy`, `/architecture-audit`, `/sync-vision` | `/retro`, `/review`, `/product-vision` | — | 🔁 каждый деплой |
| `PRODUCT.md` | Спецификация поведения продукта с точки зрения пользователя | `last_product_check.plans_since ≥ 5` | `/product-check`, `/product-review`, `/code` | `/plan`, `/product-check`, `/code` | — | 📊 ~5 планов |
| `docs/product/USER-MAP.md` | Визуальная карта возможностей пользователей (Mermaid) | `last_user_map_sync.plans_since ≥ 10` или `[TODO:]` найдены | `/code` | `/product-check`, `/code`, Developer, PM/Owner | — | 📊 ~10 планов |
| `docs/architecture/SYSTEM-MAP.md` | Архитектурная карта: компоненты, связи, границы модулей | `plans_since ≥ 5` | `/code` | `/review`, `/architecture-audit`, `/code`, Developer | — | 📊 ~5 планов |
| `HYPOTHESES.md` | Гипотезы о поведении системы, наблюдения, аномалии | при ретро / диагностике | `/retro`, `/diagnose` | `/plan` (Шаг -1.5), `/retro` | — | 📊 ~5–15 планов |
| `AGENT-GAPS.md` | Лог признанных пропусков / ошибок AI — сигнал к улучшению методологии | при явном признании ошибки AI (триггер -4 в `/plan`) | `/plan` (Шаг -4), `/code`, `/review`, AI Agent | `/architecture-audit` (Способность B: pattern analysis + Level 4+ ladder), `/retro` (lightweight signal) | — | ⚡ по событию |
| `OPEN-QUESTIONS.md` | Открытые вопросы, требующие решения команды или PM | при изменении контрактов | `/sync-vision`, `/plan` | `/plan` (Шаг -3.3), `/retro`, PM/Owner | PM / Owner | ⚡ по событию |
| `inbox/` | Очередь внешних входящих документов: VCD, specs, анализы — ждут обработки | при получении внешнего документа | PM / Owner / Developer | `/plan` (Шаг 0.7), `/sync-vision` | `/sync-vision`, `/plan` → `_processed/` | ⚡ по событию |
| `IDEAS.md` | Сырые сигналы: боль пользователей, идеи, friction | `plans_since ≥ 10` или ≥ 7 unreviewed | `/plan`, `/review`, `/retro` | `/product-review`, `/plan` (Шаг 1.6), `/retro` (Шаг 6) | `/product-review` | 📊 ~10 планов |
| `ROADMAP.md` | Стратегический план: что делаем и когда | `plans_since ≥ 30` | `/product-vision` | `/plan` (Шаг 1.5), Developer, PM/Owner | — | 🔭 ~30 планов |
| `VISION.md` | Стратегические оси, долгосрочные цели продукта | `plans_since ≥ 30` или при контракт-изменениях | `/product-vision`, `/sync-vision` | `/plan`, `/product-review`, `/sync-vision` | — | 🔭 ~30 планов |
| `docs/product/ARTIFACT-MAP.md` | Lifecycle карта артефактов (этот файл) | при добавлении команды / артефакта / актора | Developer | Developer, `/review` | — | ручное |
| `RISKS.md` | Реестр рисков: угрозы, вероятность, mitigation | при новом риске или по рекомендации `/retro` | `/sync-vision` (Type B), PM / Owner | `/plan`, PM/Owner, Developer | PM / Owner | 📊 ~15 планов |
| `CLAUDE.md` | Правила работы AI-агентов в проекте | при sync pull или изменении правил | `/code`, sync-script | все команды (rules) | — | ⚡ по событию |
| `docs/adr/` | Архитектурные решения и их обоснование | при архитектурном решении | `/code` | `/review` (Шаг 2), `/architecture-audit`, `/sync-vision`, `/code` | Developer (deprecated) | ⚡ по решению |

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
| `CLAUDE.md` | sync pull или изменение правил | Developer (запускает sync-script) | Правила расходятся с практикой |
| `docs/adr/` | архитектурное решение или `/architecture-audit` | Developer (запускает `/code`) | ADR противоречат текущей архитектуре |
| `inbox/` | Получен новый внешний документ | PM / Owner / Developer | Документ не обработан → план и sync-vision работают с устаревшими данными |
| `[TODO: артефакт]` | `[TODO: триггер]` | `[TODO: актор]` | `[TODO: риск]` |

---

## Refresh Policy

Обновлять этот файл когда:
- Добавлена новая команда (`/X`) → добавить строку в Command Reference + node в диаграмму + двустрочный label
- Добавлен новый тип артефакта → добавить строку в Artifact Reference + node в диаграмму
- Появился новый актор (Developer, PM, скрипт, CRUD-событие) → добавить в Actors / Events subgraph
- Изменился порог триггера → обновить колонку "Частота" и стрелку Plan→команда в диаграмме
- Ручной триггер автоматизирован → убрать из "Ручные триггеры", обновить Актор в таблице
- Артефакт без входящих стрелок (`-->`, `===`) И с `Читает = —` → кандидат на рудимент: проверить при `/retro`
- Артефакт без входящих стрелок но с `Пишет = PM / Owner` → не рудимент, а automation gap: документировать в "Ручные триггеры"
- Изменён тип связи (W→RW) → заменить `-->` + `-.->` на `===`

**Принцип диаграммы: только command-driven flow.**
Диаграмма показывает систематические потоки (команды → артефакты). Человек (Developer / PM / Owner) появляется в диаграмме **только** как источник `inbox/` — единая точка входа внешних документов. Все остальные операции человека (написать RISKS.md, закрыть OQ) — ручные, несистематические; отражаются в таблицах и "Ручные триггеры", но НЕ стрелками в диаграмме.

**Checklist перед коммитом этого файла:**
- [ ] Каждая **команда** в "Читает" → есть `-.->` или `===` стрелка в диаграмме (human actors — Developer/PM — не требуют стрелки)
- [ ] Каждый "Пишет / Актор" → есть `-->` или `===` стрелка в диаграмме
      **ИСКЛЮЧЕНИЕ:** human actors (Developer / PM / Owner) без `inbox` — их записи в "Пишет" = ручное ownership (не показывается в диаграмме)
- [ ] Если команда одновременно в "Пишет" И "Читает" для одного артефакта → используется `===`, не две отдельные стрелки
- [ ] Нет нод без единой стрелки (входящей или исходящей)
- [ ] Каждая стрелка в диаграмме → соответствующая строка в таблице
- [ ] Command-ноды в диаграмме имеют двустрочный формат: `["/command<br/>описание"]` (описание ≤ 30 символов)

`/review` проверяет: новая команда или артефакт → ARTIFACT-MAP обновлён? table↔Mermaid консистентны?
