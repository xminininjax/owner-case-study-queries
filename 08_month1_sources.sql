-- 08  Slide 4 talk track: where the first months' orders come from
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM demo_db.public.product_analytics_case_v2
  WHERE gmv > 0 AND number_of_items > 0
    AND order_created_at_pt::TIMESTAMP >= '2020-05-01' AND order_created_at_pt::TIMESTAMP < '2025-07-01'
),
ord_age AS (   -- k = months since the restaurant's first order month
  SELECT o.*, DATEDIFF(month, DATE_TRUNC('month', fo.first_ts), DATE_TRUNC('month', o.ts)) AS k
  FROM orders o JOIN (SELECT location_id, MIN(ts) AS first_ts FROM orders GROUP BY 1) fo ON fo.location_id = o.location_id
),
guests AS (
  SELECT k, location_id, guest_id, COUNT(*) AS n FROM ord_age WHERE k BETWEEN 0 AND 12 GROUP BY 1, 2, 3
),
g AS (
  SELECT k, ROUND(COUNT(*) / COUNT(DISTINCT location_id), 1) AS guests_per_restaurant,
         ROUND(AVG(n), 2) AS orders_per_guest
  FROM guests GROUP BY 1
)
SELECT a.k AS month_on_owner,
       COUNT(*) AS orders,
       ROUND(AVG(CASE WHEN a.has_coupon THEN 1 ELSE 0 END), 3) AS coupon_share,          -- ~8% throughout
       ROUND(AVG(CASE WHEN a.utm_source = 'google' THEN 1 ELSE 0 END), 3) AS google_share,   -- ~54% in month 1
       ROUND(AVG(CASE WHEN a.order_source = 'App' THEN 1 ELSE 0 END), 3) AS app_share,
       MAX(g.guests_per_restaurant) AS guests_per_restaurant,                           -- month 1: ~173
       MAX(g.orders_per_guest) AS orders_per_guest                                      -- month 1: 1.19
FROM ord_age a JOIN g ON g.k = a.k
WHERE a.k BETWEEN 0 AND 12
GROUP BY 1
ORDER BY 1;
