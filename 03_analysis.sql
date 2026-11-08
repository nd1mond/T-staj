/* ---------- 1. ПРОВЕРКА ГРУПП ---------- */

-- @block 1.1 Размер групп
SELECT
    "group",
    COUNT(DISTINCT user_id) AS users_cnt,
    ROUND(COUNT(DISTINCT user_id) * 100.0 / (SELECT COUNT(DISTINCT user_id) FROM ab_data), 2) AS users_pct
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 751 (50.03%), B - 750 (49.97%)

-- @block 1.2 Устройства в группах (% клиентов внутри группы)
SELECT
    "group",
    COUNT(DISTINCT user_id) AS users_cnt,
    ROUND(100.0 * COUNT(DISTINCT user_id) FILTER (WHERE device_type = 'android') / COUNT(DISTINCT user_id), 1) AS android_pct,
    ROUND(100.0 * COUNT(DISTINCT user_id) FILTER (WHERE device_type = 'ios') / COUNT(DISTINCT user_id), 1) AS ios_pct
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - android 54.2%, ios 45.8%; B - android 49.2%, ios 50.8%

-- @block 1.3 Города в группах (% клиентов внутри группы)
SELECT
    "group",
    COUNT(DISTINCT user_id) AS users_cnt,
    ROUND(100.0 * COUNT(DISTINCT user_id) FILTER (WHERE city = 'Москва') / COUNT(DISTINCT user_id), 1) AS moscow_pct,
    ROUND(100.0 * COUNT(DISTINCT user_id) FILTER (WHERE city = 'СПб') / COUNT(DISTINCT user_id), 1) AS spb_pct,
    ROUND(100.0 * COUNT(DISTINCT user_id) FILTER (WHERE city = 'Регион') / COUNT(DISTINCT user_id), 1) AS region_pct
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - Москва 38.3%, СПб 25.8%, Регион 35.7% (+ 9004 без города);
--            B - Москва 40.8%, СПб 26.5%, Регион 32.7%

-- @block 1.4 Возраст в группах
SELECT
    "group",
    ROUND(AVG(age), 1) AS avg_age,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM (SELECT DISTINCT user_id, "group", age FROM ab_data) AS u
GROUP BY "group"
ORDER BY "group";
-- Результат: средний возраст 32.7 в обеих группах, диапазон 20-60


/* ---------- 2. ВОРОНКА ---------- */

-- @block 2.1 Сколько попыток дошло до каждого шага
-- COUNT(колонка) не считает NULL, поэтому получаем число попыток, которые дошли до шага
SELECT
    "group",
    COUNT(step1_opened) AS step1,
    COUNT(step2_entered) AS step2,
    COUNT(step3_confirmed) AS step3,
    COUNT(step4_success) AS step4
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 1307, 1060, 757, 650; B - 1351, 1194, 960, 870

-- @block 2.2 Доля от открытия формы (%)
SELECT
    "group",
    ROUND(100.0 * COUNT(step2_entered) / COUNT(step1_opened), 1) AS step2_pct,
    ROUND(100.0 * COUNT(step3_confirmed) / COUNT(step1_opened), 1) AS step3_pct,
    ROUND(100.0 * COUNT(step4_success) / COUNT(step1_opened), 1) AS step4_pct
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 81.1%, 57.9%, 49.7%; B - 88.4%, 71.1%, 64.4%

-- @block 2.3 Переход с шага на шаг (%)
SELECT
    "group",
    ROUND(100.0 * COUNT(step2_entered) / COUNT(step1_opened), 1) AS step1_to_2,
    ROUND(100.0 * COUNT(step3_confirmed) / COUNT(step2_entered), 1) AS step2_to_3,
    ROUND(100.0 * COUNT(step4_success) / COUNT(step3_confirmed), 1) AS step3_to_4
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 81.1%, 71.4%, 85.9%; B - 88.4%, 80.4%, 90.6%


/* ---------- 3. КОНВЕРСИЯ ---------- */

-- @block 3.1 Конверсия на клиента (оплатил хотя бы раз)
-- user_level: одна строка = один клиент, paid = 1 если была хотя бы одна успешная оплата
WITH user_level AS (
    SELECT
        user_id,
        "group",
        MAX(CASE WHEN step4_success IS NOT NULL THEN 1 ELSE 0 END) AS paid
    FROM ab_data
    GROUP BY user_id, "group"
)
SELECT
    "group",
    COUNT(*) AS users_cnt,
    SUM(paid) AS paid_cnt,
    ROUND(100.0 * SUM(paid) / COUNT(*), 1) AS conversion_pct
FROM user_level
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 492 из 751 (65.5%), B - 603 из 750 (80.4%)

-- @block 3.2 Конверсия на попытку (дополнительно)
SELECT
    "group",
    COUNT(*) AS attempts_cnt,
    COUNT(step4_success) AS success_cnt,
    ROUND(100.0 * COUNT(step4_success) / COUNT(*), 1) AS conversion_pct
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 49.7%, B - 64.4%


/* ---------- 4. СЕГМЕНТЫ ---------- */

-- @block 4.1 Конверсия по устройствам
WITH user_level AS (
    SELECT
        user_id,
        "group",
        device_type,
        MAX(CASE WHEN step4_success IS NOT NULL THEN 1 ELSE 0 END) AS paid
    FROM ab_data
    GROUP BY user_id, "group", device_type
)
SELECT
    device_type,
    "group",
    COUNT(*) AS users_cnt,
    ROUND(100.0 * SUM(paid) / COUNT(*), 1) AS conversion_pct
FROM user_level
GROUP BY device_type, "group"
ORDER BY device_type, "group";
-- Результат: android - A 64.4%, B 79.9% (+15.6); ios - A 66.9%, B 80.8% (+14.0)

-- @block 4.2 Конверсия по городам
WITH user_level AS (
    SELECT
        user_id,
        "group",
        city,
        MAX(CASE WHEN step4_success IS NOT NULL THEN 1 ELSE 0 END) AS paid
    FROM ab_data
    WHERE city IS NOT NULL
    GROUP BY user_id, "group", city
)
SELECT
    city,
    "group",
    COUNT(*) AS users_cnt,
    ROUND(100.0 * SUM(paid) / COUNT(*), 1) AS conversion_pct
FROM user_level
GROUP BY city, "group"
ORDER BY city, "group";
-- Результат: Москва - A 62.2%, B 81.0% (+18.9); СПб - A 68.6%, B 84.4% (+15.9);
--            Регион - A 66.8%, B 76.3% (+9.5)


/* ---------- 5. ВРЕМЯ ОПЛАТЫ ---------- */

-- @block 5.1 Сколько минут занимает успешная оплата
SELECT
    "group",
    COUNT(*) AS success_cnt,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (step4_success - step1_opened)) / 60) AS median_min
FROM ab_data
WHERE step4_success IS NOT NULL
GROUP BY "group"
ORDER BY "group";
-- Результат: медиана 12 минут в обеих группах


/* ---------- 6. ПРОВЕРКА БЕЗ КЛИЕНТА 9004 ---------- */

-- @block 6.1 Конверсия на клиента без 9004
-- 9004 я оставил при очистке (у него нормальный платеж, нет только города). Проверяю, что без него вывод тот же
WITH user_level AS (
    SELECT
        user_id,
        "group",
        MAX(CASE WHEN step4_success IS NOT NULL THEN 1 ELSE 0 END) AS paid
    FROM ab_data
    WHERE user_id <> 9004
    GROUP BY user_id, "group"
)
SELECT
    "group",
    COUNT(*) AS users_cnt,
    ROUND(100.0 * SUM(paid) / COUNT(*), 1) AS conversion_pct
FROM user_level
GROUP BY "group"
ORDER BY "group";
-- Результат: A - 65.5%, B - 80.4%, то же самое


/* ---------- 7. КОНВЕРСИЯ ПО НЕДЕЛЯМ ---------- */

-- @block 7.1 Конверсия попыток по неделям теста
-- неделя считается по дате открытия формы, 29-30 апреля отношу к 4-й неделе
SELECT
    LEAST((EXTRACT(DAY FROM step1_opened)::int - 1) / 7 + 1, 4) AS week,
    "group",
    COUNT(*) AS attempts_cnt,
    ROUND(100.0 * COUNT(step4_success) / COUNT(*), 1) AS conversion_pct
FROM ab_data
GROUP BY week, "group"
ORDER BY week, "group";
-- Результат: 1 неделя - A 50.8%, B 66.3%; 2 - A 52.3%, B 66.0%;
--            3 - A 48.0%, B 62.3%; 4 - A 48.3%, B 62.9%
