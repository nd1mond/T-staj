/* ---------- Анализ users таблицы ---------- */
/* ---------- 1. ОБЗОР ---------- */

-- @block 1. Размер таблицы users
-- Вопрос: сколько всего строк (клиентов)?
SELECT COUNT(*) AS users_cnt
FROM users;
-- Результат: 1504.


/* ---------- 2. ДОПУСТИМЫЕ ЗНАЧЕНИЯ КАТЕГОРИЙ ---------- */

-- @block 2.1 Уникальные значения в категориях
-- Вопрос: сколько разных значений в каждой категориальной колонке?
SELECT
    COUNT(DISTINCT "group") AS group_unique,
    COUNT(DISTINCT city) AS city_unique,
    COUNT(DISTINCT device_type) AS device_unique
FROM users;
-- Результат: group = 2, city = 3, device_type = 2 (COUNT DISTINCT не учитывает NULL).

-- @block 2.2 Значения group
SELECT
    "group",
    COUNT(*) AS users_cnt
FROM users
GROUP BY "group"
ORDER BY "group";
-- Результат: A = 752, B = 751, NULL = 1.

-- @block 2.3 Значения city
SELECT
    city,
    COUNT(*) AS users_cnt
FROM users
GROUP BY city
ORDER BY city;
-- Результат: Москва = 595, Регион = 514, СПб = 394, NULL = 1.

-- @block 2.4 Значения device_type
SELECT
    device_type,
    COUNT(*) AS users_cnt
FROM users
GROUP BY device_type
ORDER BY device_type;
-- Результат: android = 777, ios = 727, NULL нет.


/* ---------- 3. ПРОПУСКИ (NULL) ---------- */

-- @block 3.1 Количество NULL по всем колонкам
SELECT
    COUNT(*) FILTER (WHERE user_id IS NULL) AS null_user_id,
    COUNT(*) FILTER (WHERE "group" IS NULL) AS null_group,
    COUNT(*) FILTER (WHERE age IS NULL) AS null_age,
    COUNT(*) FILTER (WHERE city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE device_type IS NULL) AS null_device_type
FROM users;
-- Результат: user_id = 0, group = 1, age = 0, city = 1, device_type = 0.

-- @block 3.2 Строки с пропусками
SELECT *
FROM users
WHERE "group" IS NULL
   OR city IS NULL;
-- Результат: user_id 9001 (нет группы), user_id 9004 (нет города).


/* ---------- 4. ВОЗРАСТ ---------- */

-- @block 4.1 Диапазон возраста
-- Вопрос: есть ли неправдоподобные значения?
SELECT
    MIN(age) AS min_age,
    MAX(age) AS max_age,
    ROUND(AVG(age), 1) AS avg_age,
    COUNT(*) FILTER (WHERE age < 14 OR age > 100) AS suspicious_age_cnt
FROM users;
-- Результат: min = -5, max = 150, avg = 32.7, подозрительных = 2.

-- @block 4.2 Квантили и границы по правилу IQR
-- Вопрос: где основная масса значений и что считает выбросом формальное правило?
SELECT
    age_q1,
    age_median,
    age_q3,
    age_q3 - age_q1 AS iqr,
    age_q1 - 1.5 * (age_q3 - age_q1) AS iqr_lower,
    age_q3 + 1.5 * (age_q3 - age_q1) AS iqr_upper
FROM (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY age) AS age_q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY age) AS age_median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY age) AS age_q3
    FROM users
) q;
-- Результат: Q1 = 27, медиана = 33, Q3 = 38, IQR = 11, границы IQR: 10.5-54.5.

-- @block 4.3 Сравнение двух подходов к выбросам
SELECT
    COUNT(*) FILTER (WHERE age < 14 OR age > 100) AS outliers_by_domain,
    COUNT(*) FILTER (WHERE age < 10.5 OR age > 54.5) AS outliers_by_iqr
FROM users;
-- Результат: по смысловой границе = 2, по IQR = 8.

-- @block 4.4 Строки с аномальным возрастом
SELECT *
FROM users
WHERE age < 14 OR age > 100;
-- Результат: user_id 9002 (age = −5), user_id 9003 (age = 150).


/* ---------- 5. user_id ---------- */

-- @block 5.1 Непрерывность user_id
-- Вопрос: идут ли id подряд, без разрывов?
SELECT
    MIN(user_id) AS min_id,
    MAX(user_id) AS max_id,
    COUNT(*) AS users_cnt,
    MAX(user_id) - MIN(user_id) + 1 AS expected_if_continuous
FROM users;
-- Результат: min = 1001, max = 9004, строк = 1504, при непрерывной нумерации было бы 8004. (9004 - 1000)

-- @block 5.2 Где разрывы
SELECT *
FROM (
    SELECT
        user_id,
        LAG(user_id) OVER (ORDER BY user_id) AS prev_id,
        user_id - LAG(user_id) OVER (ORDER BY user_id) AS gap
    FROM users
) t
WHERE gap > 1;
-- Результат: один разрыв: после 2500 сразу идёт 9001 (gap = 6501).

-- @block 5.3 Записи после разрыва
SELECT *
FROM users
WHERE user_id > 2500
ORDER BY user_id;
-- Результат: 4 записи, 9001–9004:
--   9001 — нет группы
--   9002 — age = −5
--   9003 — age = 150
--   9004 — нет города


/* ---------- 6. ДУБЛИКАТЫ ---------- */

-- @block 6.1 Дубликаты user_id
SELECT
    user_id,
    COUNT(*) AS rows_cnt
FROM users
GROUP BY user_id
HAVING COUNT(*) > 1;
-- Результат: дубликатов нет, все user_id уникальны.


/* ---------- 7. СОСТАВ АУДИТОРИИ ---------- */

-- @block 7.1 Доли по устройствам
SELECT
    device_type,
    COUNT(*) AS users_cnt,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS dolya_pct
FROM users
GROUP BY device_type
ORDER BY device_type;
-- Результат: android = 51.7%, ios = 48.3%.

-- @block 7.2 Доли по городам
SELECT
    city,
    COUNT(*) AS users_cnt,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS dolya_pct
FROM users
GROUP BY city
ORDER BY city;
-- Результат: Москва = 39.6%, Регион = 34.2%, СПб = 26.2%, NULL = 0.1%.


/* ---------- 8. ПРЕДВАРИТЕЛЬНЫЙ ВЗГЛЯД НА ГРУППЫ (сырые данные) ---------- */

-- @block 8.1 Устройства по группам
SELECT
    "group",
    COUNT(*) FILTER (WHERE device_type = 'ios') AS ios_cnt,
    COUNT(*) FILTER (WHERE device_type = 'android') AS android_cnt,
    COUNT(*) AS total_cnt
FROM users
GROUP BY "group"
ORDER BY "group";
-- Результат: A: ios 344 / android 408; B: ios 382 / android 369; NULL: ios 1.

-- @block 8.2 Города по группам
SELECT
    "group",
    COUNT(*) FILTER (WHERE city = 'Москва') AS moscow_cnt,
    COUNT(*) FILTER (WHERE city = 'СПб') AS spb_cnt,
    COUNT(*) FILTER (WHERE city = 'Регион') AS region_cnt,
    COUNT(*) FILTER (WHERE city IS NULL) AS null_city_cnt,
    COUNT(*) AS total_cnt
FROM users
GROUP BY "group"
ORDER BY "group";
-- Результат: A: 288 / 195 / 268 / NULL 1; B: 306 / 199 / 246; группа NULL: Москва 1.


/* ============================================================
   Анализ payments таблицы (этап 2 EDA)
   Одна строка = одна попытка оплаты.
   Шаги воронки: step1_opened → step2_entered → step3_confirmed → step4_success.
   NULL в step2–step4 — это НЕ ошибка, а отвал клиента на шаге (данные для метрики, не чистим).

   Структура:
     9.  Обзор
     10. Пропуски (NULL) и категории
     11. payment_id: непрерывность и разрывы
     12. Дубли
     13. Даты и логика воронки
   ============================================================ */


/* ---------- 9. ОБЗОР ---------- */

-- @block 9.1 Размер таблицы payments
-- Вопрос: сколько попыток, уникальны ли payment_id, сколько клиентов платили?
SELECT
    COUNT(*)                   AS payments_cnt,
    COUNT(DISTINCT payment_id) AS payment_id_unique,
    COUNT(DISTINCT user_id)    AS users_with_payments
FROM payments;
-- Результат: 2661 попытка, payment_id уникальных тоже 2661 → повторов payment_id нет.

-- @block 9.2 Повторные попытки: сколько попыток на клиента
-- Вопрос: как часто клиенты возвращаются к оплате?
SELECT
    attempts_cnt,
    COUNT(*) AS users_cnt
FROM (
    SELECT
        user_id,
        COUNT(*) AS attempts_cnt
    FROM payments
    WHERE user_id IS NOT NULL
    GROUP BY user_id
) t
GROUP BY attempts_cnt
ORDER BY attempts_cnt;
-- Результат: 1 попытка — 740 клиентов, 2 — 443, 3 — 238, 4 — 80.


/* ---------- 10. ПРОПУСКИ (NULL) И КАТЕГОРИИ ---------- */

-- @block 10.1 NULL в обязательных колонках
-- Вопрос: есть ли пропуски там, где их быть не может?
SELECT
    COUNT(*) FILTER (WHERE payment_id IS NULL)   AS null_payment_id,
    COUNT(*) FILTER (WHERE user_id IS NULL)      AS null_user_id,
    COUNT(*) FILTER (WHERE "group" IS NULL)      AS null_group,
    COUNT(*) FILTER (WHERE step1_opened IS NULL) AS null_step1
FROM payments;
-- Результат: payment_id = 0, user_id = 1, group = 0, step1 = 0.

-- @block 10.2 Строка без user_id
SELECT *
FROM payments
WHERE user_id IS NULL;
-- Результат: payment_id 99003, группа A, отвал на шаге 1.

-- @block 10.3 NULL в шагах воронки (нормальные пропуски = отвал)
-- Вопрос: сколько попыток не дошли до каждого шага? Первый взгляд на воронку.
SELECT
    COUNT(*)                                        AS payments_cnt,
    COUNT(*) FILTER (WHERE step2_entered IS NULL)   AS null_step2,
    COUNT(*) FILTER (WHERE step3_confirmed IS NULL) AS null_step3,
    COUNT(*) FILTER (WHERE step4_success IS NULL)   AS null_step4
FROM payments;
-- Результат: из 2661 попытки не дошли до шага 2 — 405, до шага 3 — 942, до шага 4 — 1139.

-- @block 10.4 Значения group
SELECT
    "group",
    COUNT(*) AS payments_cnt
FROM payments
GROUP BY "group"
ORDER BY "group" NULLS LAST;
-- Результат: A = 1309, B = 1352, NULL нет.


/* ---------- 11. payment_id ---------- */

-- @block 11.1 Непрерывность payment_id
-- Вопрос: идут ли payment_id подряд, без разрывов?
SELECT
    MIN(payment_id)                       AS min_payment_id,
    MAX(payment_id)                       AS max_payment_id,
    COUNT(*)                              AS payments_cnt,
    MAX(payment_id) - MIN(payment_id) + 1 AS expected_if_continuous
FROM payments;
-- Результат: min = 5001, max = 99003, строк 2661, а при непрерывной нумерации было бы 94003.

-- @block 11.2 Где разрывы
SELECT *
FROM (
    SELECT
        payment_id,
        LAG(payment_id) OVER (ORDER BY payment_id)              AS prev_id,
        payment_id - LAG(payment_id) OVER (ORDER BY payment_id) AS gap
    FROM payments
) t
WHERE gap > 1;
-- Результат: один разрыв — после 7658 сразу идёт 99001 (gap = 91343, сильно большой).

-- @block 11.3 Записи после разрыва
SELECT *
FROM payments
WHERE payment_id > 7658
ORDER BY payment_id;
-- Результат: 3 записи, 99001–99003:
--   99001 — user 1005, группа A;
--   99002 — user 1010, группа B;
--   99003 — user_id NULL (см. 10.2).

-- @block 11.4 Все попытки клиентов 1005 и 1010
-- Вопрос: как записи из пачки соотносятся с остальными попытками этих клиентов?
SELECT
    p.*,
    u."group" AS user_group
FROM payments p
JOIN users u ON u.user_id = p.user_id
WHERE p.user_id IN (1005, 1010)
ORDER BY p.user_id, p.payment_id;
-- Результат:
--   1005 (в users группа A): 5007 — отвал на шаге 2; 99001 — успешная оплата.
--   1010 (в users группа A): 5015 — отвал на шаге 1; 99002 — успешная оплата, но в группе B.


/* ---------- 12. ДУБЛИ ---------- */

-- @block 12.1 Дубли payment_id
SELECT
    payment_id,
    COUNT(*) AS rows_cnt
FROM payments
GROUP BY payment_id
HAVING COUNT(*) > 1;
-- Результат: дублей нет (совпадает с 9.1: 2661 = 2661).

-- @block 12.2 Точные дубли попыток (одна попытка записана дважды)
-- Вопрос: нет ли разных payment_id с тем же клиентом и тем же временем открытия формы?
SELECT
    user_id,
    step1_opened,
    COUNT(*) AS rows_cnt
FROM payments
GROUP BY user_id, step1_opened
HAVING COUNT(*) > 1;
-- Результат: 0 строк → двойных записей одной и той же попытки нет.


/* ---------- 13. ДАТЫ И ЛОГИКА ВОРОНКИ ---------- */

-- @block 13.1 Даты шагов: в пределах теста?
-- Вопрос: все ли события внутри периода теста 1–30 апреля 2024?
SELECT
    MIN(step1_opened)    AS step1_min,
    MAX(step1_opened)    AS step1_max,
    MIN(step2_entered)   AS step2_min,
    MAX(step2_entered)   AS step2_max,
    MIN(step3_confirmed) AS step3_min,
    MAX(step3_confirmed) AS step3_max,
    MIN(step4_success)   AS step4_min,
    MAX(step4_success)   AS step4_max
FROM payments;
-- Результат: самое раннее событие 2024-04-01 00:19, самое позднее 2024-04-30 23:30.

-- @block 13.2 Пропущенные шаги
-- Вопрос: нет ли попыток, где следующий шаг есть, а предыдущего нет?
SELECT
    COUNT(*) FILTER (WHERE step2_entered IS NULL   AND step3_confirmed IS NOT NULL) AS step3_without_step2,
    COUNT(*) FILTER (WHERE step3_confirmed IS NULL AND step4_success IS NOT NULL)   AS step4_without_step3,
    COUNT(*) FILTER (WHERE step2_entered IS NULL   AND step4_success IS NOT NULL)   AS step4_without_step2
FROM payments;
-- Результат: 0 / 0 / 0.

-- @block 13.3 Порядок времени шагов
-- Вопрос: не идёт ли время назад (следующий шаг раньше предыдущего)?
SELECT
    COUNT(*) FILTER (WHERE step2_entered   < step1_opened)    AS step2_before_step1,
    COUNT(*) FILTER (WHERE step3_confirmed < step2_entered)   AS step3_before_step2,
    COUNT(*) FILTER (WHERE step4_success   < step3_confirmed) AS step4_before_step3
FROM payments;
-- Результат: 0 / 0 / 0.

-- @block 13.4 Длительность оплаты (шаг 1 → шаг 4), минуты
-- Вопрос: нет ли отрицательных или неправдоподобно долгих оплат?
SELECT
    COUNT(*)                                                    AS success_cnt,
    ROUND(MIN(duration_min), 1)                                 AS min_min,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_min)  AS q1_min,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_min)  AS median_min,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_min)  AS q3_min,
    ROUND(MAX(duration_min), 1)                                 AS max_min
FROM (
    SELECT EXTRACT(EPOCH FROM (step4_success - step1_opened)) / 60 AS duration_min
    FROM payments
    WHERE step4_success IS NOT NULL
) t;
-- Результат: успешных 1522, от 5 до 24 минут, Q1 = 10, медиана = 12, Q3 = 14.

-- @block 13.5 Медиана длительности по группам (предварительно, сырые данные)
-- Вопрос: ускоряет ли новая форма оплату? (дополнительная продуктовая метрика)
SELECT
    "group",
    COUNT(*)                                                    AS success_cnt,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_min)  AS median_min,
    ROUND(AVG(duration_min), 1)                                 AS avg_min
FROM (
    SELECT
        "group",
        EXTRACT(EPOCH FROM (step4_success - step1_opened)) / 60 AS duration_min
    FROM payments
    WHERE step4_success IS NOT NULL
) t
GROUP BY "group"
ORDER BY "group";
-- Результат: A — медиана 12 мин (среднее 12.4), B — медиана 12 мин (среднее 12.4).


/* Соединяем 2 таблицы для анализа */

-- @block 14.1. Платежи без клиента в users
SELECT p.*
FROM payments AS p
    LEFT JOIN users AS u ON p.user_id = u.user_id
WHERE u.user_id IS NULL;
-- Результат: 1 строка — 99003 (user_id NULL, уже найден в 10.2).

-- @block 14.2. Users которые не 1 не открыли форму
SELECT u.*
FROM users AS u
    LEFT JOIN payments AS p ON u.user_id = p.user_id
WHERE p.payment_id IS NULL;
-- Результат 14.2: клиентов без платежей 3 — ровно 9001, 9002, 9003.

-- @block 14.3 Расхождение групп платежа и клиента
-- Вопрос: совпадает ли группа в payments с группой клиента в users?
SELECT
    p.*,
    u."group" AS user_group
FROM payments AS p
    JOIN users AS u ON p.user_id = u.user_id
WHERE p."group" <> u."group";


-- @block 14.4 Клиенты с платежами в обеих группах
-- Вопрос: есть ли клиент, у которого платежи и в A, и в B (нарушение сплита)?
SELECT
    user_id,
    COUNT(DISTINCT "group") AS groups_cnt,
    STRING_AGG(DISTINCT "group", ', ') AS groups_list,
    COUNT(*) AS payments_cnt
FROM payments
WHERE user_id IS NOT NULL
GROUP BY user_id
HAVING COUNT(DISTINCT "group") > 1;
-- Результат: 1 клиент — 1010 (группы A, B; 2 платежа).


-- @block 14.5 Платежи клиентов 9001–9004
-- Вопрос: есть ли у подозрительных клиентов платежи и влияют ли они на метрику?
SELECT
    u.user_id,
    u."group" AS user_group,
    u.age,
    u.city,
    p.payment_id,
    p."group" AS payment_group,
    p.step1_opened,
    p.step2_entered,
    p.step3_confirmed,
    p.step4_success
FROM users AS u
    LEFT JOIN payments AS p ON p.user_id = u.user_id
WHERE u.user_id > 2500
ORDER BY u.user_id, p.payment_id;
-- Результат: 4 строки:
--   9001, 9002, 9003 — платежей нет (все колонки payments = NULL);
--   9004 — 1 платёж 7658, группа A (совпадает), дошёл до шага 4 (успешная оплата).

/* ---------- 14.6–14.7 ИТОГ СВЯЗКИ: ЧТО УДАЛЯЕМ ---------- */

-- @block 14.6 Итог: список записей на удаление
-- Вопрос: что именно удаляем на этапе очистки и почему?
SELECT 
    'users' AS table_name, 
    user_id AS record_id, 
    'нет группы, нет платежей' AS reason
FROM users 
WHERE user_id = 9001
UNION ALL

SELECT 
    'users' AS table_name,
    user_id AS record_id,
    'age = -5, нет платежей' AS reason
FROM users 
WHERE user_id = 9002
UNION ALL

SELECT 
    'users' AS table_name,
    user_id AS record_id,
    'age = 150, нет платежей' AS reason
FROM users 
WHERE user_id = 9003
UNION ALL

SELECT 
    'payments' AS table_name,
    payment_id AS record_id,
    'id вне нумерации (пачка 99xxx)' AS reason
FROM payments 
WHERE payment_id = 99001
UNION ALL

SELECT 
    'payments' AS table_name,
    payment_id AS record_id,
    'группа B у клиента из A — нарушение сплита' AS reason
FROM payments 
WHERE payment_id = 99002
UNION ALL

SELECT 
    'payments' AS table_name,
    payment_id AS record_id,
    'нет user_id' AS reason
FROM payments 
WHERE payment_id = 99003
ORDER BY table_name DESC, record_id;
-- Результат: 6 записей — 3 в users (9001–9003), 3 в payments (99001–99003).

-- @block 14.7 Итог: сколько останется после очистки
-- Вопрос: как изменятся таблицы и баланс групп?
SELECT
    'users' AS table_name,
    COUNT(*) AS before_cnt,
    COUNT(*) FILTER (WHERE user_id NOT IN (9001, 9002, 9003)) AS after_cnt,
    COUNT(*) FILTER (WHERE user_id NOT IN (9001, 9002, 9003)
        AND "group" = 'A') AS after_a,
    COUNT(*) FILTER (WHERE user_id NOT IN (9001, 9002, 9003)
        AND "group" = 'B') AS after_b
FROM users
UNION ALL
SELECT
    'payments' AS table_name,
    COUNT(*) AS before_cnt,
    COUNT(*) FILTER (WHERE payment_id < 99000) AS after_cnt,
    COUNT(*) FILTER (WHERE payment_id < 99000 AND "group" = 'A') AS after_a,
    COUNT(*) FILTER (WHERE payment_id < 99000 AND "group" = 'B') AS after_b
FROM payments;
-- Результат:
--   users:    1504 → 1501 (A = 751, B = 750)
--   payments: 2661 → 2658 (A = 1307, B = 1351)
