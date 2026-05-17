# /product-check — Аудит актуальности PRODUCT.md

Запускается в двух точках:
1. В начале сессии — быстрый контекст по расхождениям
2. Перед деплоем если diff затрагивает команды/UI

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — структурное сравнение текста с кодом, deterministic checklist
**Upgrade:** (всегда Fast — обычно достаточно)
**Downgrade:** (всегда Fast — это минимум)
**Mid-task escalation:** нет (single pass comparison)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если используется Capable (Opus) tier — это 🟡 over-powered (2 ступени) → пауза + рекомендация Fast/Default для cost-savings.

---

Прочитай PRODUCT.md. Сравни с текущим кодом и картой данных в CLAUDE.md:

1. **Команды в таблице vs код:** каждая команда из таблицы реально зарегистрирована?
2. **Команды в коде vs таблица:** каждая зарегистрированная команда упомянута?
3. **Описание поведения:** соответствует реализации или устарело?
4. **Режимы и состояния:** описаны корректно?
5. **Хранилища:** таблица хранилищ в PRODUCT.md совпадает с data-map?
6. **Дата обновления:** есть и актуальна?
7. **ARTIFACT-MAP freshness** (если есть `docs/product/ARTIFACT-MAP.md`):
   - Новые команды в `commands/` не отражены в Command Reference → 🟡 WARNING
   - Нода без единой стрелки (island) → 🟡 WARNING "node island — проверь Gate 2"
   - `[TODO:]` маркеры в Artifact Reference → 🟡 WARNING "таблица не заполнена"
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
