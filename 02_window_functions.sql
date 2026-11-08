-- =====================================================
-- 02_window_functions.sql
-- ROW_NUMBER, RANK, LAG, LEAD, NTILE, running totals
-- =====================================================

-- 1. ROW_NUMBER: most recent order for every customer
WITH cust_orders AS (
    SELECT c.customer_unique_id,
           o.order_id,
           o.order_purchase_timestamp,
           ROW_NUMBER() OVER (
               PARTITION BY c.customer_unique_id
               ORDER BY o.order_purchase_timestamp DESC
           ) AS rn
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
)
SELECT *
FROM cust_orders
WHERE rn = 1
LIMIT 20;

-- 2. RANK: top 3 product categories by revenue in each customer state
WITH rev AS (
    SELECT c.customer_state,
           COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o    ON o.order_id = oi.order_id
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN products p  ON p.product_id = oi.product_id
    LEFT JOIN product_category_name_translation t
           ON t.product_category_name = p.product_category_name
    WHERE o.order_status <> 'canceled'
    GROUP BY 1, 2
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY customer_state ORDER BY revenue DESC) AS rnk
    FROM rev
)
SELECT *
FROM ranked
WHERE rnk <= 3
ORDER BY customer_state, rnk;

-- 3. LAG: monthly revenue and month-over-month growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS prev_month,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS growth_pct
FROM monthly
ORDER BY month;

-- 4. LEAD: days until each customer's next order
WITH seq AS (
    SELECT c.customer_unique_id,
           o.order_id,
           o.order_purchase_timestamp AS purchased_at,
           LEAD(o.order_purchase_timestamp) OVER (
               PARTITION BY c.customer_unique_id
               ORDER BY o.order_purchase_timestamp
           ) AS next_purchase
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
)
SELECT customer_unique_id,
       order_id,
       purchased_at::date AS purchased_on,
       next_purchase::date AS next_purchase_on,
       next_purchase::date - purchased_at::date AS days_to_next_order
FROM seq
WHERE next_purchase IS NOT NULL
ORDER BY days_to_next_order
LIMIT 20;

-- 5. NTILE: split customers into spending quartiles
WITH spend AS (
    SELECT c.customer_unique_id,
           SUM(p.payment_value) AS total_spent
    FROM orders o
    JOIN customers c      ON c.customer_id = o.customer_id
    JOIN order_payments p ON p.order_id = o.order_id
    GROUP BY 1
),
bucketed AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY total_spent DESC) AS quartile
    FROM spend
)
SELECT quartile,
       COUNT(*) AS customers,
       ROUND(MIN(total_spent), 2) AS min_spent,
       ROUND(MAX(total_spent), 2) AS max_spent,
       ROUND(AVG(total_spent), 2) AS avg_spent
FROM bucketed
GROUP BY quartile
ORDER BY quartile;

-- 6. Running total and 3-month moving average of revenue
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total,
       ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly
ORDER BY month;
