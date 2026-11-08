-- =====================================================
-- 04_rollup_cube.sql
-- ROLLUP, CUBE, GROUPING SETS
-- Run the view first.
-- =====================================================

CREATE OR REPLACE VIEW sales_flat AS
SELECT o.order_id,
       o.order_status,
       EXTRACT(YEAR  FROM o.order_purchase_timestamp)::int AS yr,
       EXTRACT(MONTH FROM o.order_purchase_timestamp)::int AS mth,
       c.customer_state,
       COALESCE(t.product_category_name_english, 'unknown') AS category,
       oi.price
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN customers c    ON c.customer_id = o.customer_id
JOIN products p     ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name;

-- 1. ROLLUP: revenue by year and month, with year subtotals and a grand total
SELECT yr,
       mth,
       ROUND(SUM(price), 2) AS revenue,
       GROUPING(yr, mth)    AS grouping_level   -- 0 = detail, 1 = year subtotal, 3 = grand total
FROM sales_flat
WHERE order_status = 'delivered'
GROUP BY ROLLUP (yr, mth)
ORDER BY yr, mth;

-- 2. CUBE: revenue for every combination of year and state (top 3 states)
SELECT yr,
       customer_state,
       ROUND(SUM(price), 2) AS revenue,
       GROUPING(yr, customer_state) AS grouping_level
FROM sales_flat
WHERE order_status = 'delivered'
  AND customer_state IN ('SP', 'RJ', 'MG')
GROUP BY CUBE (yr, customer_state)
ORDER BY yr, customer_state;

-- 3. GROUPING SETS: by category, by state, and overall in one query
SELECT CASE WHEN GROUPING(category) = 0 THEN category ELSE 'ALL' END AS category,
       CASE WHEN GROUPING(customer_state) = 0 THEN customer_state ELSE 'ALL' END AS state,
       ROUND(SUM(price), 2) AS revenue
FROM sales_flat
WHERE order_status = 'delivered'
GROUP BY GROUPING SETS ((category), (customer_state), ())
ORDER BY revenue DESC;
