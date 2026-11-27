-- 08  Slide 4 talk track: where orders come from in each month after joining
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.
-- A month here = 30 days since the event (joining Owner or App launch), not a calendar month. Month 1 = the first 30 days.

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM demo_db.public.product_analytics_case_v2
  WHERE gmv > 0 AND number_of_items > 0
    AND order_created_at_pt::TIMESTAMP >= '2020-05-01' AND order_created_at_pt::TIMESTAMP < '2025-07-01'
),
loc_first AS (   -- each restaurant's first and last order date
  SELECT location_id, MIN(ts)::DATE AS first_d, MAX(ts)::DATE AS last_d FROM orders GROUP BY 1
),
ord_age AS (   -- months since joining (1 = month 1)
  SELECT o.*, FLOOR(DATEDIFF(day, f.first_d, o.ts::DATE) / 30) + 1 AS month_num
  FROM orders o JOIN loc_first f ON f.location_id = o.location_id
),
guests AS (
  SELECT month_num, location_id, guest_id, COUNT(*) AS n FROM ord_age WHERE month_num BETWEEN 1 AND 12 GROUP BY 1, 2, 3
),
g AS (
  SELECT month_num, ROUND(COUNT(*) / COUNT(DISTINCT location_id), 1) AS guests_per_restaurant,
         ROUND(AVG(n), 2) AS orders_per_guest
  FROM guests GROUP BY 1
)
SELECT a.month_num,
       COUNT(*) AS orders,
       ROUND(AVG(CASE WHEN a.has_coupon THEN 1 ELSE 0 END), 3) AS coupon_share,          -- ~8% throughout
       ROUND(AVG(CASE WHEN a.utm_source = 'google' THEN 1 ELSE 0 END), 3) AS google_share,   -- 56% in month 1
       ROUND(AVG(CASE WHEN a.order_source = 'App' THEN 1 ELSE 0 END), 3) AS app_share,
       MAX(g.guests_per_restaurant) AS guests_per_restaurant,                           -- month 1: ~140
       MAX(g.orders_per_guest) AS orders_per_guest                                      -- month 1: 1.16
FROM ord_age a JOIN g ON g.month_num = a.month_num
WHERE a.month_num BETWEEN 1 AND 12
GROUP BY 1
ORDER BY 1;
