# /product-check — Аудит актуальности PRODUCT.md

> **Цель:** проверить что PRODUCT.md описание соответствует реальному поведению (команды зарегистрированы, числа актуальны, ARTIFACT-MAP / USER-MAP консистентны). Структурное сравнение текста с кодом, deterministic checklist. НЕ для архитектуры (это /architecture-audit) и НЕ для прироизводства фич.

Запускается в двух точках:
1. В начале сессии — быстрый контекст по расхождениям
2. Перед деплоем если diff затрагивает команды/UI

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **Low** · thinking: **OFF** — структурное сравнение текста с кодом (mechanical checklist). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — структурное сравнение текста с кодом, deterministic checklist
**Upgrade:** (всегда Fast — обычно достаточно)
**Downgrade:** (всегда Fast — это минимум)
**Mid-task escalation:** нет (single pass comparison)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если используется Capable (Opus) tier — это 🟡 over-powered (2 ступени) → пауза + рекомендация Fast/Default для cost-savings.

---

Прочитай PRODUCT.md. Сравни с текущим кодом и картой данных в CLAUDE.md:

⛔ Discipline-creating: п.1-2-6 проверяются командой, не чтением «на глаз».

1. **Команды в таблице vs код:** для каждой команды из таблицы — `ls commands/<cmd>.md` подтверждает существование? Список расхождений.
2. **Команды в коде vs таблица:** `ls commands/*.md` → каждая упомянута в PRODUCT.md? (`grep`). Незадокументированные — перечислить.
3. **Описание поведения:** соответствует реализации или устарело? Для команд с числами (N шагов, M точек) — число в PRODUCT.md = число в команде? (точечный grep, не память).
4. **Режимы и состояния:** описаны корректно?
5. **Хранилища:** таблица хранилищ в PRODUCT.md совпадает с data-map?
6. **Дата обновления:** сравнить дату в PRODUCT.md с git-историей:
   ```bash
   git log -1 --format=%ad --date=short -- PRODUCT.md   # реальная дата последнего изменения
   ```
   Дата в шапке старше git-даты на > 7 дней → ⚠️ "дата актуализации врёт — обновить".
7. **ARTIFACT-MAP freshness** (если есть `docs/product/ARTIFACT-MAP.md`):
   - Новые команды в `commands/` не отражены в Command Reference → 🔵 Recommendation
   - Нода без единой стрелки (island) → 🔵 Recommendation "node island — проверь Gate 2"
   - `[TODO:]` маркеры в Artifact Reference → 🔵 Recommendation "таблица не заполнена"

7б. **ARTIFACT-MAP arrow type check** (если есть `docs/product/ARTIFACT-MAP.md`):
   **Если доступен `scripts/validate-artifact-map.sh`** (methodology-platform или consumer с установленным скриптом):
   ```
   bash scripts/validate-artifact-map.sh
   ```
   Exit 1 → 🔵 Recommendation "W→RW candidate detected: [список]" — проверить каждый вручную.

   **Если скрипта нет** — ручной spot-check:
   - Для каждого `===` (RW) ребра: команда действительно И читает И пишет?
   - Для каждого `-->` (W) ребра: читает ли как логический вход? Если да → `===`
   Приоритет: `===` рёбра первыми.
   → 🔵 Recommendation "arrow type mismatch: [команда] → [артефакт] — ожидается [тип], реально [тип]"
8. **USER-MAP freshness** (если есть `docs/product/USER-MAP.md`):
   - Прочитать `triggers.json` → `last_user_map_sync.plans_since` (если поле отсутствует — считать 0, не ошибка)
   - Если ≥ 10 → ⚠️ "USER-MAP давно не проверялся — соответствует ли текущим возможностям продукта?"
   - Grep на `[TODO: ...]` маркеры → если найдены → 🔴 CRITICAL: USER-MAP не заполнен
   - После проверки: обновить `last_user_map_sync = { "date": today, "plans_since": 0 }`

---

## Вывод

Расхождения в формате:
- ⚠️ [тип]: что не совпадает → что должно быть

Если всё совпадает → "✅ PRODUCT.md актуален"

---

## После анализа

Обновить triggers.json: `last_product_check = { date: today, plans_since: 0 }`

Если найдены расхождения → предложить конкретные правки PRODUCT.md. Не применять без явного "да".

---

$ARGUMENTS
---

## Вывод простым языком (обязательно — Plain-language output rule)

Заверши вывод этой команды коротким блоком `## Простыми словами` (2-5 строк): что это значит для пользователя и что делать дальше — понятным языком, без жаргона/меток/внутренних терминов. Остальной вывод (разбор, метки, детали) оставь как есть — резюме добавляется в конце. См. CLAUDE.md → Plain-language output rule.
