-- =====================================================
-- 01_data_quality_audit.sql
-- Olist Brazilian E-Commerce: data quality checks
-- Run each query separately and record the result.
-- =====================================================

-- 1. Orders marked 'delivered' but with no delivery date
SELECT COUNT(*) AS delivered_without_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 2. Delivery date earlier than purchase date (impossible)
SELECT COUNT(*) AS delivered_before_purchase
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- 3. Order items that point to a non-existent order (orphans)
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- 4. Orders that have no items
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL;

-- 5. Orders that have no payment record
SELECT COUNT(*) AS orders_without_payment
FROM orders o
LEFT JOIN order_payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL;

-- 6. Orders where total paid differs from items + freight
--    (some differences are legitimate, e.g. vouchers; review before calling them errors)
WITH paid AS (
    SELECT order_id, SUM(payment_value) AS total_paid
    FROM order_payments
    GROUP BY order_id
),
items AS (
    SELECT order_id, SUM(price + freight_value) AS total_items
    FROM order_items
    GROUP BY order_id
)
SELECT COUNT(*) AS mismatched_orders
FROM paid
JOIN items USING (order_id)
WHERE ABS(total_paid - total_items) > 0.01;

-- 7. Duplicate review_id values
SELECT review_id, COUNT(*) AS cnt
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 10;

-- 8. Orders with more than one review
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT order_id
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;

-- 9. Products with no category
SELECT COUNT(*) AS products_without_category
FROM products
WHERE product_category_name IS NULL;

-- 10. Product categories with no English translation
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- 11. Suspicious payments (zero value or undefined type)
SELECT payment_type, COUNT(*) AS cnt
FROM order_payments
WHERE payment_value = 0 OR payment_type = 'not_defined'
GROUP BY payment_type;

-- 12. Duplicate rows in geolocation
SELECT COUNT(*) - COUNT(DISTINCT (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng))
       AS duplicate_geo_rows
FROM geolocation;
