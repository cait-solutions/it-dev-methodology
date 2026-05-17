# ARTIFACT-MAP — methodology-platform

Карта **жизненного цикла артефактов**: какая команда обновляет какой файл, как часто, и где gap.
Дополняет [USER-MAP](USER-MAP.md) (что умеет пользователь) и [SYSTEM-MAP](../architecture/SYSTEM-MAP.md) (как устроено) слоем актуальности документов.

> **Не синхронизируется `sync-methodology.sh`.** Обновлять при: добавлении новой команды / артефакта; изменении частоты триггера.

---

## Диаграмма: команды → артефакты

Группировка команд по частоте. Цвета: синий/фиолетовый/пурпурный = частота · оранжевый = state · зелёный = артефакт с триггером · красный = gap.

```mermaid
graph LR
    classDef core fill:#e1f5ff,stroke:#0288d1,color:#000
    classDef periodic fill:#e8eaf6,stroke:#3949ab,color:#000
    classDef strategic fill:#f3e5f5,stroke:#7b1fa2,color:#000
    classDef ok fill:#e8f5e9,stroke:#388e3c,color:#000
    classDef gap fill:#ffebee,stroke:#c62828,color:#c62828
    classDef state fill:#fff3e0,stroke:#f57c00,color:#000

    subgraph CoreWF["🔁 Ядро (каждый цикл)"]
        Plan["/plan"]:::core
        Deploy["/deploy"]:::core
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

    subgraph Live["📄 Артефакты (есть триггер)"]
        TJ["triggers.json<br/>счётчики планов"]:::state
        DL["DEVLOG.md<br/>история деплоев"]:::ok
        PM["PRODUCT.md<br/>поведение продукта"]:::ok
        UM["USER-MAP.md<br/>карта возможностей"]:::ok
        SM["SYSTEM-MAP.md<br/>архитектура"]:::ok
        HY["HYPOTHESES.md<br/>гипотезы и аномалии"]:::ok
        OQ["OPEN-QUESTIONS.md<br/>открытые вопросы"]:::ok
        ID["IDEAS.md<br/>сигналы и идеи"]:::ok
        RM["ROADMAP.md<br/>план развития"]:::ok
        VI["VISION.md<br/>стратегия"]:::ok
        AM["ARTIFACT-MAP.md<br/>lifecycle карта"]:::ok
    end

    subgraph Stale["❌ Артефакты без триггера"]
        RISKS["RISKS.md<br/>реестр рисков"]:::gap
        CLM["CLAUDE.md<br/>правила AI"]:::gap
        ADR["docs/adr/<br/>архитектурные решения"]:::gap
    end

    Plan -->|"≥5 планов"| PCheck
    Plan -->|"≥5 планов"| Arch
    Plan -->|"≥10 планов"| PReview
    Plan -->|"≥15 планов"| Retro
    Plan -->|"≥30 планов"| PVision
    Plan -.->|"≥5 + событие"| SyncV

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

    PCheck -->|"проверка / сравнение"| PM
    PReview -->|"может обновить"| PM
    PCheck -->|"freshness ≥ 10"| UM
    Arch -->|"верификация"| SM
    Arch -->|"гипотезы"| HY
    Retro -->|"паттерны"| HY
    SyncV -->|"риски стратегии"| HY
    SyncV -->|"конфликты"| OQ
    PReview -->|"обрабатывает"| ID
    PVision -->|"планирование"| RM
    PVision -->|"стратегия"| VI
    SyncV -->|"может обновить"| VI
```

---

## Command Reference

| Команда | Назначение | Частота | Обновляет |
|---|---|---|---|
| `/plan` | Анализ задачи: риски, архитектура, план до первой строки кода | 🔁 каждый цикл | `triggers.json` |
| `/deploy` | Публикация изменений + обязательная запись истории | 🔁 каждый цикл | `DEVLOG.md`, `triggers.json` |
| `/product-check` | Соответствие PRODUCT.md реальному поведению | 📊 ≥5 планов | `PRODUCT.md`, `USER-MAP.md` |
| `/architecture-audit` | Drift SYSTEM-MAP vs реальный код — ищет расхождения | 📊 ≥5 планов | `SYSTEM-MAP.md`, `HYPOTHESES.md`, `DEVLOG.md` |
| `/product-review` | Обработка накопленных IDEAS.md сигналов → решения | 📊 ≥10 планов | `IDEAS.md`, `PRODUCT.md` |
| `/retro` | Паттерны проблем за N планов — системные причины | 📊 ≥15 планов | `HYPOTHESES.md`, `DEVLOG.md` |
| `/sync-vision` | Стратегия vs реальность при изменении контрактов | ⚡ по событию | `VISION.md`, `OPEN-QUESTIONS.md`, `HYPOTHESES.md` |
| `/product-vision` | Стратегический обзор: VISION + ROADMAP обновление | 🔭 ≥30 планов | `VISION.md`, `ROADMAP.md` |

---

## Artifact Reference

| Артефакт | Назначение | Условие обновления | Частота | Gap |
|---|---|---|---|---|
| `triggers.json` | State-машина методологии: счётчики, даты, статус сессии | автоматически при каждом `/plan` и `/deploy` | 🔁 каждый цикл | ✅ |
| `DEVLOG.md` | Хронология проекта: деплои, решения, milestones | каждый деплой — обязательно | 🔁 каждый деплой | ✅ |
| `PRODUCT.md` | Спецификация поведения продукта с точки зрения пользователя | `last_product_check.plans_since ≥ 5` | 📊 ~5 планов | ✅ |
| `docs/product/USER-MAP.md` | Визуальная карта возможностей пользователей (Mermaid) | `last_user_map_sync.plans_since ≥ 10` или `[TODO:]` найдены | 📊 ~10 планов | ✅ |
| `docs/architecture/SYSTEM-MAP.md` | Архитектурная карта: компоненты, связи, границы модулей | `plans_since ≥ 5` | 📊 ~5 планов | ✅ |
| `HYPOTHESES.md` | Гипотезы о поведении системы, наблюдения, аномалии | при аудите / ретро / sync-vision | 📊 ~5–15 планов | ✅ |
| `OPEN-QUESTIONS.md` | Открытые вопросы, требующие решения команды или PM | при изменении контрактов | ⚡ по событию | ✅ |
| `IDEAS.md` | Сырые сигналы: боль пользователей, идеи, friction | `plans_since ≥ 10` или ≥ 7 unreviewed | 📊 ~10 планов | ✅ |
| `ROADMAP.md` | Стратегический план: что делаем и когда | `plans_since ≥ 30` | 🔭 ~30 планов | ✅ |
| `VISION.md` | Стратегические оси, долгосрочные цели продукта | `plans_since ≥ 30` или при контракт-изменениях | 🔭 ~30 планов | ✅ |
| `docs/product/ARTIFACT-MAP.md` | Lifecycle карта артефактов (этот файл) | при добавлении команды / артефакта | ручное | ✅ |
| **`RISKS.md`** | Реестр рисков: угрозы, вероятность, mitigation | **нет триггера** | — | ❌ |
| **`CLAUDE.md`** | Правила работы AI-агентов в проекте | **нет триггера** | — | ❌ |
| **`docs/adr/`** | Архитектурные решения и их обоснование | при новом решении; нет ревью старых | — | ❌ частично |

---

## Known gaps

| Gap | Риск | Возможное решение |
|---|---|---|
| `RISKS.md` без триггера | Риски устаревают незаметно — threat landscape меняется | Добавить в `/retro` или `/product-review` периодический check |
| `CLAUDE.md` без триггера | Правила могут расходиться с реальной практикой | Добавить в `/architecture-audit` или `/retro` check на устаревшие правила |
| `docs/adr/` без ревью устаревших | ADR от ранних фаз могут противоречить текущей архитектуре | Добавить в `/architecture-audit` проверку статусов ADR |

---

## Refresh Policy

Обновлять этот файл когда:
- Добавлена новая команда (`/X`) → добавить строку в Command Reference + node в диаграмму
- Добавлен новый тип артефакта → добавить строку в Artifact Reference
- Изменился порог триггера → обновить колонку "Частота" и subgraph label в диаграмме
- Gap закрыт → переместить из Stale в Live subgraph, обновить до ✅

`/review` проверяет: новая команда или артефакт → ARTIFACT-MAP обновлён?
