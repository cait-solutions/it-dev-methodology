# /architecture-audit — Сверка карты с реальным кодом

Запускается:
- `last_architecture_audit.plans_since` ≥ 5-10 (триггер из /plan)
- Перед квартальным планированием
- После крупных архитектурных изменений
- ОБЯЗАТЕЛЬНО при добавлении нового сервиса/компонента

**ЗАПРЕЩЕНО:** обновлять SYSTEM-MAP.md автоматически. Human review required.

---

## Рекомендуемая модель

**Default tier:** Default tier (см. `.claude/model-tiers.md`)
**Upgrade to Capable tier if:** multi-service + 10+ сервисов; обнаружен drift > 30% (нужен глубокий анализ корректности графа)
**Downgrade to Fast tier if:** (не downgrade — even single-service audit требует понимания)
**Mid-task escalation:** нет (single-pass анализ inventory → comparison → report)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если mismatch ≥ 2 ступени — пауза + рекомендация.

---

## Шаг 1 — Inventory

1. Загрузить текущий граф из SYSTEM-MAP.md
2. Загрузить services-registry.yaml (или эквивалент) — active компоненты
3. Для каждого активного компонента inventory связей:
   - HTTP клиенты к другим компонентам
   - Event publishers (поиск по pattern conventions)
   - Event subscribers
   - External API integrations

---

## Шаг 2 — Построить граф из кода

Из inventory собрать реальный граф.

**Error handling:**
- Inaccessible repo → list "skipped (inaccessible)"
- Unparseable patterns → "investigation needed: path:line"
- Malformed registry → fail с clear error
- Always produce partial report — partial info > no report

---

## Шаг 3 — Сравнить

- В карте, не в коде → **stale edge** (удалить?)
- В коде, не в карте → **undocumented edge** (добавить?)
- В карте active, не в registry → **phantom service**
- В registry active, не в карте → **missing service**

---

## Шаг 4 — Отчёт

```markdown
# Architecture Audit — YYYY-MM-DD

## Stale edges (in map, not in code)
- source → target [type] — pattern not found in: path

## Undocumented edges (in code, not in map)
- source → target [type] — found in path:line

## Phantom services
- {service-name}

## Missing services
- {service-name}

## Skipped
- {service-name} — reason

## Inconsistencies worth noting
- [ambiguity description with file references]

## Summary
- Edges in map: X | Edges in code: Y | Drift: Z (W%)
- Skipped services: N
- Recommendation: resolve {OQ-XXXX} before next audit
```

---

## Constraints

- No invented edges — только что в коде
- No architectural opinions — только diffs
- Ambiguous patterns (dual HTTP+event) → report as inconsistency, not decision

---

## После завершения

1. Запись в DEVLOG: `[architecture-audit] Report YYYY-MM-DD: N stale, M undocumented, K skipped`
2. В triggers.json: `last_architecture_audit = { date: today, plans_since: 0 }`

---

$ARGUMENTS
