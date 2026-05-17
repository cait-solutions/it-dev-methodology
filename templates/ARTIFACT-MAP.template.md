# ARTIFACT-MAP — {{Project Name}}

Карта **жизненного цикла артефактов**: какая команда обновляет какой файл, как часто, и где gap.
Дополняет [SYSTEM-MAP](architecture/SYSTEM-MAP.md) (компоненты и связи) слоем актуальности.

> ⚠️ Этот файл создаётся один раз при bootstrap с подстановкой `{{Project Name}}`. Не синхронизируется `sync-methodology.sh`. Проект владеет и поддерживает его самостоятельно.

---

## Диаграмма: команды → артефакты

Синий = команда · Оранжевый = state · Зелёный = артефакт с триггером · Красный = gap (нет триггера)

```mermaid
graph LR
    classDef cmd fill:#e1f5ff,stroke:#0288d1,color:#000
    classDef ok fill:#e8f5e9,stroke:#388e3c,color:#000
    classDef gap fill:#ffebee,stroke:#c62828,color:#c62828
    classDef state fill:#fff3e0,stroke:#f57c00,color:#000

    subgraph Cmds["⚙️ Триггеры"]
        Plan["/plan"]:::cmd
        Deploy["/deploy"]:::cmd
        PCheck["/product-check"]:::cmd
        PReview["/product-review"]:::cmd
        PVision["/product-vision"]:::cmd
        SyncV["/sync-vision"]:::cmd
        Arch["/architecture-audit"]:::cmd
        Retro["/retro"]:::cmd
    end

    subgraph Live["📄 Артефакты (есть триггер)"]
        TJ["triggers.json"]:::state
        DL["DEVLOG.md"]:::ok
        PM["PRODUCT.md"]:::ok
        UM["USER-MAP.md"]:::ok
        SM["SYSTEM-MAP.md"]:::ok
        HY["HYPOTHESES.md"]:::ok
        OQ["OPEN-QUESTIONS.md"]:::ok
        ID["IDEAS.md"]:::ok
        RM["ROADMAP.md"]:::ok
        VI["VISION.md"]:::ok
        AM["ARTIFACT-MAP.md"]:::ok
        Custom1["[TODO: артефакт проекта]"]:::ok
    end

    subgraph Stale["❌ Артефакты без триггера"]
        RISKS["RISKS.md"]:::gap
        CLM["CLAUDE.md"]:::gap
        ADR["docs/adr/"]:::gap
        CustomGap["[TODO: артефакт без триггера]"]:::gap
    end

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

    %% Добавь стрелки для проектных артефактов ниже
    %% Plan -->|"[TODO: действие]"| Custom1
```

---

## Lifecycle table

### Стандартные артефакты (из методологии)

| Артефакт | Команда-триггер | Условие | Частота | Gap |
|---|---|---|---|---|
| `triggers.json` | `/plan`, `/deploy`, все периодические | автоматически | каждый цикл | ✅ |
| `DEVLOG.md` | `/deploy`, `/architecture-audit`, `/retro` | обязательно при деплое | каждый деплой | ✅ |
| `PRODUCT.md` | `/product-check`, `/product-review` | `last_product_check.plans_since ≥ 5` | ~каждые 5 планов | ✅ |
| `docs/product/USER-MAP.md` | `/product-check` (шаг 7) | `last_user_map_sync.plans_since ≥ 10` | ~каждые 10 планов | ✅ |
| `docs/architecture/SYSTEM-MAP.md` | `/architecture-audit` | `plans_since ≥ 5` | ~каждые 5 планов | ✅ |
| `HYPOTHESES.md` | `/architecture-audit`, `/retro`, `/sync-vision` | по событию | при аудите / ретро | ✅ |
| `OPEN-QUESTIONS.md` | `/sync-vision` | при контракт-изменениях | по событию | ✅ |
| `IDEAS.md` | `/product-review` | `plans_since ≥ 10` ИЛИ ≥ 7 unreviewed | ~каждые 10 планов | ✅ |
| `ROADMAP.md` | `/product-vision` | `plans_since ≥ 30` | ~каждые 30 планов | ✅ |
| `VISION.md` | `/product-vision`, `/sync-vision` | `plans_since ≥ 30` | ~каждые 30 планов | ✅ |
| `docs/architecture/ARTIFACT-MAP.md` | ручное | при добавлении команды / артефакта | по событию | ✅ |
| **`RISKS.md`** | — | **нет триггера** | — | ❌ |
| **`CLAUDE.md`** | — | **нет триггера** | — | ❌ |
| **`docs/adr/`** | — | при новом решении | нет ревью старых | ❌ частично |

### Проектные артефакты (заполнить)

| Артефакт | Команда-триггер | Условие | Частота | Gap |
|---|---|---|---|---|
| `[TODO: артефакт]` | `[TODO: команда]` | `[TODO: условие]` | `[TODO: частота]` | ✅/❌ |

**Как найти gap:** пройди по всем файлам в `docs/` и корне проекта. Если файл важен но не упомянут ни в одной команде — это gap (❌). Добавь в таблицу и секцию Known gaps.

---

## Known gaps

| Gap | Риск | Возможное решение |
|---|---|---|
| `RISKS.md` без триггера | Риски устаревают незаметно | Добавить в `/retro` или `/product-review` |
| `CLAUDE.md` без триггера | Правила расходятся с практикой | Добавить в `/architecture-audit` или `/retro` |
| `docs/adr/` без ревью устаревших | ADR противоречат текущей архитектуре | Добавить в `/architecture-audit` |
| `[TODO: артефакт]` | `[TODO: риск]` | `[TODO: решение]` |

---

## Refresh Policy

Обновлять этот файл когда:
- Добавлена новая команда (`/X`) → добавить строку в таблицу + node в диаграмму
- Добавлен новый тип артефакта → добавить строку
- Изменился порог триггера → обновить колонку "Частота"
- Gap закрыт → переместить из Gaps в Live, обновить до ✅

`/review` проверяет: новая команда или артефакт → ARTIFACT-MAP обновлён?
