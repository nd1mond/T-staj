-- @block 1. ab_data: чистая таблица для анализа (попытка + данные клиента)
DROP TABLE IF EXISTS ab_data;

CREATE TABLE ab_data AS
SELECT
    p.payment_id,
    p.user_id,
    u."group",
    u.age,
    u.city,
    u.device_type,
    p.step1_opened,
    p.step2_entered,
    p.step3_confirmed,
    p.step4_success
FROM payments AS p
JOIN users AS u ON u.user_id = p.user_id   -- 99003 (нет user_id) отсеется сам: ему не с кем соединиться
WHERE u."group" IS NOT NULL                -- 9001: неизвестна группа
  AND u.age BETWEEN 14 AND 100             -- 9002 (−5), 9003 (150): некорректный возраст
  AND p.payment_id < 99000                 -- пачка 99001–99003 вне основной нумерации 5001–7658
  AND p."group" = u."group";               -- группа платежа = группа клиента (99002 нарушал сплит)

-- @block 2.1 Проверка: было → стало
SELECT 'users' AS table_name,
       (SELECT COUNT(*) FROM users) AS before_cnt,
       (SELECT COUNT(DISTINCT user_id) FROM ab_data) AS after_cnt
UNION ALL
SELECT 'payments',
       (SELECT COUNT(*) FROM payments),
       (SELECT COUNT(*) FROM ab_data);
-- Результат: users 1504 → 1501, payments 2661 → 2658

-- @block 2.2 Проверка: какие клиенты из users не попали в ab_data
SELECT u.*
FROM users AS u
LEFT JOIN (SELECT DISTINCT user_id FROM ab_data) AS a ON a.user_id = u.user_id
WHERE a.user_id IS NULL;
-- Результат: ровно 3 клиента — 9001, 9002, 9003. 9004 остался.


-- @block 2.3 Проверка: баланс групп
SELECT
    "group",
    COUNT(DISTINCT user_id) AS users_cnt,
    COUNT(*) AS payments_cnt
FROM ab_data
GROUP BY "group"
ORDER BY "group";
-- Результат: A — 751 клиент / 1307 попыток, B — 750 / 1351.

-- @block 2.4 Проверка: проблем больше нет
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM ab_data WHERE "group" IS NULL OR age < 14 OR age > 100) AS bad_users,
    (SELECT COUNT(*) FROM ab_data WHERE payment_id > 7658 OR user_id IS NULL)  AS bad_payments,
    (SELECT COUNT(*) FROM (
        SELECT user_id FROM ab_data GROUP BY user_id HAVING COUNT(DISTINCT "group") > 1
     ) t) AS users_in_both_groups;
-- Результат: 0 / 0 / 0.
