-- =====================================================
-- 03_ctes.sql
-- Multi-step CTEs and recursive CTEs
-- =====================================================

-- 1. Multi-step CTE: customer segments by order count and spend
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(p.payment_value)       AS total_spent
    FROM orders o
    JOIN customers c      ON c.customer_id = o.customer_id
    JOIN order_payments p ON p.order_id = o.order_id
    GROUP BY 1
),
segmented AS (
    SELECT *,
           CASE
               WHEN orders >= 3 THEN 'loyal'
               WHEN orders = 2  THEN 'repeat'
               ELSE 'one-time'
           END AS segment
    FROM customer_orders
)
SELECT segment,
       COUNT(*) AS customers,
       ROUND(AVG(total_spent), 2) AS avg_spent,
       ROUND(SUM(total_spent), 2) AS total_spent
FROM segmented
GROUP BY segment
ORDER BY customers DESC;

-- 2. Recursive CTE: generate a month calendar and find months with zero orders
WITH RECURSIVE months AS (
    SELECT DATE '2016-09-01' AS month
    UNION ALL
    SELECT (month + INTERVAL '1 month')::date
    FROM months
    WHERE month < DATE '2018-10-01'
),
monthly AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           COUNT(*) AS orders
    FROM orders
    GROUP BY 1
)
SELECT m.month,
       COALESCE(mo.orders, 0) AS orders
FROM months m
LEFT JOIN monthly mo ON mo.month = m.month
ORDER BY m.month;

-- 3. Recursive CTE: organisation hierarchy (self-contained example)
WITH RECURSIVE employees(id, name, boss_id) AS (
    VALUES (1, 'CEO', NULL::int),
           (2, 'Manager A', 1),
           (3, 'Manager B', 1),
           (4, 'Analyst', 2),
           (5, 'Intern', 4)
),
org AS (
    SELECT id, name, boss_id, 1 AS level, name::text AS path
    FROM employees
    WHERE boss_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.boss_id, o.level + 1, o.path || ' > ' || e.name
    FROM employees e
    JOIN org o ON e.boss_id = o.id
)
SELECT level, path
FROM org
ORDER BY path;
