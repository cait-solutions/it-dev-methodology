# ARTIFACT-MAP — methodology-platform

Карта **жизненного цикла артефактов**: какая команда обновляет какой файл, как часто, и где gap.
Дополняет [USER-MAP](USER-MAP.md) (что умеет пользователь) и [SYSTEM-MAP](../architecture/SYSTEM-MAP.md) (как устроено) слоем актуальности документов.

> **Не синхронизируется `sync-methodology.sh`.** Обновлять при: добавлении новой команды / артефакта; изменении частоты триггера.

---

## Диаграмма: команды ↔ артефакты

Цвета: синий = ядро · фиолетовый = периодические · пурпурный = стратегические · оранжевый = state · зелёный = артефакт · серый = актор.
Стрелки: `-->` пишет (W) · `-.->` читает (R) · `<-->` читает+пишет (RW) · `--x` закрывает (C)

```mermaid
graph LR
    classDef core fill:#e1f5ff,stroke:#0288d1,color:#000
    classDef periodic fill:#e8eaf6,stroke:#3949ab,color:#000
    classDef strategic fill:#f3e5f5,stroke:#7b1fa2,color:#000
    classDef ok fill:#e8f5e9,stroke:#388e3c,color:#000
    classDef state fill:#fff3e0,stroke:#f57c00,color:#000
    classDef actor fill:#f5f5f5,stroke:#9e9e9e,color:#000

    subgraph CoreWF["🔁 Ядро (каждый цикл)"]
        Plan["/plan"]:::core
        Code["/code"]:::core
        Deploy["/deploy"]:::core
        Rev["/review"]:::core
    end

    subgraph Periodic["📊 Периодические (по счётчику)"]
        PCheck["/product-check"]:::periodic
        Arch["/architecture-audit"]:::periodic
        PReview["/product-review"]:::periodic
        Retro["/retro"]:::periodic
    end

    subgraph Strategic["🔭 Стратегические + Ad-hoc (редко / по событию)"]
        PVision["/product-vision"]:::strategic
        SyncV["/sync-vision<br/>⚡ по событию"]:::strategic
        Diag["/diagnose<br/>⚡ по событию"]:::strategic
    end

    subgraph Actors["👤 Акторы (ручной / внешний триггер)"]
        Dev["👨‍💻 Developer"]:::actor
        Owner["👤 PM / Owner"]:::actor
        Sync["⚙️ sync-script"]:::actor
    end

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
    end

    Plan -->|"≥5 планов"| PCheck
    Plan -->|"≥5 планов"| Arch
    Plan -->|"≥10 планов"| PReview
    Plan -->|"≥15 планов"| Retro
    Plan -->|"≥30 планов"| PVision
    Plan -.->|"≥5 + событие"| SyncV

    %% --- W: команда пишет артефакт (-->) ---
    Plan -->|"инкремент счётчиков"| TJ
    Deploy -->|"last_deploy"| TJ
    PCheck -->|"last_product_check"| TJ
    PReview -->|"last_product_review"| TJ
    PVision -->|"last_product_vision"| TJ
    SyncV -->|"last_sync_vision"| TJ
    Retro -->|"last_retro"| TJ

    Deploy -->|"[deploy] запись"| DL
    Arch -->|"[architecture-audit]"| DL

    PReview -->|"может обновить"| PROD
    PCheck -->|"freshness ≥ 10"| UM
    Arch -->|"гипотезы"| HY
    SyncV -->|"риски стратегии"| HY
    SyncV -->|"создаёт"| OQ
    Owner -->|"новый риск"| RISKS
    Sync -->|"sync pull"| CLM
    Arch -.->|"ревью статусов"| ADR

    Plan -.->|"Шаг 0.7 check"| INB
    SyncV -->|"обрабатывает / _processed"| INB
    Owner -->|"кладёт файлы"| INB
    Dev -->|"кладёт файлы"| INB
    Code -->|"если изм. архитектуру"| SM
    Code -->|"если изм. поведение"| PROD
    Code -->|"если изм. правила"| CLM
    Code -->|"если реализовано ADR"| ADR
    PCheck -->|"freshness check"| AM
    Rev  -->|"out-of-scope findings"| ID

    %% --- C: закрывает / архивирует записи (--x) ---
    Owner --x|"закрывает"| RISKS
    Owner --x|"закрывает"| OQ

    %% --- RW: команда читает И пишет артефакт (<-->) ---
    Arch    <-->|"drift check"| SM
    PCheck  <-->|"актуальность"| PROD
    PReview <-->|"обработка / [reviewed]"| ID
    Plan    <-->|"capture / сигналы"| ID
    Retro   <-->|"паттерны"| HY
    Retro   <-->|"история"| DL
    Diag    <-->|"гипотезы"| HY
    PVision <-->|"стратегия"| VI
    PVision <-->|"план"| RM
    SyncV   <-->|"sync vs реальность"| VI

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
```

> **Легенда:** `-->` пишет (W) · `-.->` читает (R) · `<-->` читает+пишет (RW) · `--x` закрывает (C) · Артефакт без входящих стрелок = кандидат на рудимент

---

## Command Reference

| Команда | Назначение | Частота | Обновляет |
|---|---|---|---|
| `/plan` | Анализ задачи: риски, архитектура, план до первой строки кода | 🔁 каждый цикл | `triggers.json`, `IDEAS.md` (Шаг 0.2/100) |
| `/code` | Реализация плана: обновляет документацию по результату изменений | 🔁 каждый цикл | `SYSTEM-MAP.md`, `docs/adr/`, `PRODUCT.md`, `CLAUDE.md` (по условию Шаг 5) |
| `/deploy` | Публикация изменений + обязательная запись истории | 🔁 каждый цикл | `DEVLOG.md`, `triggers.json` |
| `/review` | Архитектурное ревью изменений до деплоя | 🔁 каждый цикл | `IDEAS.md` (out-of-scope findings) |
| `/product-check` | Соответствие PRODUCT.md реальному поведению | 📊 ≥5 планов | `PRODUCT.md`, `USER-MAP.md` |
| `/architecture-audit` | Drift SYSTEM-MAP vs реальный код — ищет расхождения | 📊 ≥5 планов | `SYSTEM-MAP.md`, `HYPOTHESES.md`, `DEVLOG.md` |
| `/product-review` | Обработка накопленных IDEAS.md сигналов → решения | 📊 ≥10 планов | `IDEAS.md`, `PRODUCT.md` |
| `/retro` | Паттерны проблем за N планов — системные причины | 📊 ≥15 планов | `HYPOTHESES.md`, `DEVLOG.md` |
| `/diagnose` | Глубокий root-cause анализ при повторном `[fix:X]` — 3+ гипотезы, Capable tier | ⚡ при `[fix:X]` ≥2 за 7 дней | `HYPOTHESES.md` |
| `/sync-vision` | Стратегия vs реальность при изменении контрактов | ⚡ по событию | `VISION.md`, `OPEN-QUESTIONS.md`, `HYPOTHESES.md` |
| `/product-vision` | Стратегический обзор: VISION + ROADMAP обновление | 🔭 ≥30 планов | `VISION.md`, `ROADMAP.md` |

---

## Artifact Reference

| Артефакт | Назначение | Условие обновления | Пишет / Актор | Читает | Закрывает | Частота |
|---|---|---|---|---|---|---|
| `triggers.json` | State-машина методологии: счётчики, даты, статус сессии | автоматически при каждом `/plan` и `/deploy` | `/plan`, `/deploy` | все команды (state check) | — | 🔁 каждый цикл |
| `DEVLOG.md` | Хронология проекта: деплои, решения, milestones | каждый деплой — обязательно | `/deploy` | `/retro`, `/review`, `/product-vision` | — | 🔁 каждый деплой |
| `PRODUCT.md` | Спецификация поведения продукта с точки зрения пользователя | `last_product_check.plans_since ≥ 5` | `/product-check`, `/product-review`, `/code` | `/plan`, `/product-check` | — | 📊 ~5 планов |
| `docs/product/USER-MAP.md` | Визуальная карта возможностей пользователей (Mermaid) | `last_user_map_sync.plans_since ≥ 10` или `[TODO:]` найдены | `/product-check` | Developer, PM/Owner | — | 📊 ~10 планов |
| `docs/architecture/SYSTEM-MAP.md` | Архитектурная карта: компоненты, связи, границы модулей | `plans_since ≥ 5` | `/architecture-audit`, `/code` | `/review`, `/architecture-audit`, Developer | — | 📊 ~5 планов |
| `HYPOTHESES.md` | Гипотезы о поведении системы, наблюдения, аномалии | при аудите / ретро / диагностике / sync-vision | `/architecture-audit`, `/retro`, `/diagnose`, `/sync-vision` | `/plan` (Шаг -1.5), `/retro` | — | 📊 ~5–15 планов |
| `OPEN-QUESTIONS.md` | Открытые вопросы, требующие решения команды или PM | при изменении контрактов | `/sync-vision`, `/plan` | `/plan` (Шаг -3.3), `/retro`, PM/Owner | PM / Owner | ⚡ по событию |
| `inbox/` | Очередь внешних входящих документов: VCD, specs, анализы — ждут обработки | при получении внешнего документа | PM / Owner / Developer | `/plan` (Шаг 0.7), `/sync-vision` | `/sync-vision`, `/plan` → `_processed/` | ⚡ по событию |
| `IDEAS.md` | Сырые сигналы: боль пользователей, идеи, friction | `plans_since ≥ 10` или ≥ 7 unreviewed | Developer, `/plan`, `/review` | `/product-review`, `/plan` (Шаг 1.6) | `/product-review` | 📊 ~10 планов |
| `ROADMAP.md` | Стратегический план: что делаем и когда | `plans_since ≥ 30` | `/product-vision` | `/plan` (Шаг 1.5), Developer, PM/Owner | — | 🔭 ~30 планов |
| `VISION.md` | Стратегические оси, долгосрочные цели продукта | `plans_since ≥ 30` или при контракт-изменениях | `/product-vision`, `/sync-vision` | `/plan`, `/product-review`, `/sync-vision` | — | 🔭 ~30 планов |
| `docs/product/ARTIFACT-MAP.md` | Lifecycle карта артефактов (этот файл) | при добавлении команды / артефакта / актора | Developer | Developer, `/review` | — | ручное |
| `RISKS.md` | Реестр рисков: угрозы, вероятность, mitigation | при новом риске или по рекомендации `/retro` | PM / Owner | `/plan`, PM/Owner, Developer | PM / Owner | 📊 ~15 планов |
| `CLAUDE.md` | Правила работы AI-агентов в проекте | при sync pull или изменении правил | `/code`, sync-script | все команды (rules) | — | ⚡ по событию |
| `docs/adr/` | Архитектурные решения и их обоснование | при архитектурном решении | `/code` | `/review` (Шаг 2), `/architecture-audit`, `/sync-vision` | Developer (deprecated) | ⚡ по решению |

---

## Ручные триггеры (риск пропуска)

> **Правило: у каждого артефакта есть триггер.** Если кажется что его нет — ищи внимательнее. Ручное обновление тоже триггер: укажи кто (Developer / PM / Owner) и при каком событии. Артефакт без триггера = документ который никто не поддерживает = устаревший.

Артефакты ниже имеют триггер, но ручной — требуют дисциплины:

| Артефакт | Триггер | Актор | Риск если не обновлять |
|---|---|---|---|
| `RISKS.md` | `/retro` (паттерны) или новый риск | PM / Owner | Устаревший threat landscape |
| `CLAUDE.md` | sync pull или изменение правил | Developer | Правила расходятся с практикой |
| `docs/adr/` | архитектурное решение или `/architecture-audit` | Developer | ADR противоречат текущей архитектуре |
| `inbox/` | Получен новый внешний документ | PM / Owner / Developer | Документ не обработан → план и sync-vision работают с устаревшими данными |

---

## Refresh Policy

Обновлять этот файл когда:
- Добавлена новая команда (`/X`) → добавить строку в Command Reference + node в диаграмму
- Добавлен новый тип артефакта → добавить строку в Artifact Reference + node в диаграмму
- Появился новый актор (Developer, PM, скрипт, бизнес-событие) → добавить в Actors / Events subgraph
- Изменился порог триггера → обновить колонку "Частота" и стрелку Plan→команда в диаграмме
- Ручной триггер автоматизирован → убрать из "Ручные триггеры", обновить Актор в таблице
- Артефакт без входящих стрелок (`-->`, `<-->`, `-.->`) И с `Читает = —` → кандидат на рудимент: проверить при `/retro`
- Изменён тип связи (W→RW) → заменить `-->` + `-.->` на `<-->`

**Checklist перед коммитом этого файла:**
- [ ] Каждая **команда** в "Читает" → есть `-.->` или `<-->` стрелка в диаграмме (human actors — Developer/PM — не требуют стрелки)
- [ ] Каждый "Пишет / Актор" в таблице → есть `-->` или `<-->` стрелка в диаграмме
- [ ] Если команда одновременно в "Пишет" И "Читает" для одного артефакта → используется `<-->`, не две отдельные стрелки
- [ ] Нет нод без единой стрелки (входящей или исходящей)
- [ ] Каждая стрелка в диаграмме → соответствующая строка в таблице

`/review` проверяет: новая команда или артефакт → ARTIFACT-MAP обновлён? table↔Mermaid консистентны?
