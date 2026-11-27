-- 08  Slide 4 talk track: where orders come from in each 30-day period after joining
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.
-- Time is counted in 30-day periods from each restaurant's first order (period 1 = days 1 to 30), not calendar months.

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
ord_age AS (   -- period = 30-day period since the restaurant's first order (1 = days 1 to 30)
  SELECT o.*, FLOOR(DATEDIFF(day, f.first_d, o.ts::DATE) / 30) + 1 AS period
  FROM orders o JOIN loc_first f ON f.location_id = o.location_id
),
guests AS (
  SELECT period, location_id, guest_id, COUNT(*) AS n FROM ord_age WHERE period BETWEEN 1 AND 12 GROUP BY 1, 2, 3
),
g AS (
  SELECT period, ROUND(COUNT(*) / COUNT(DISTINCT location_id), 1) AS guests_per_restaurant,
         ROUND(AVG(n), 2) AS orders_per_guest
  FROM guests GROUP BY 1
)
SELECT a.period,
       COUNT(*) AS orders,
       ROUND(AVG(CASE WHEN a.has_coupon THEN 1 ELSE 0 END), 3) AS coupon_share,          -- ~8% throughout
       ROUND(AVG(CASE WHEN a.utm_source = 'google' THEN 1 ELSE 0 END), 3) AS google_share,   -- 56% in period 1
       ROUND(AVG(CASE WHEN a.order_source = 'App' THEN 1 ELSE 0 END), 3) AS app_share,
       MAX(g.guests_per_restaurant) AS guests_per_restaurant,                           -- period 1: ~140
       MAX(g.orders_per_guest) AS orders_per_guest                                      -- period 1: 1.16
FROM ord_age a JOIN g ON g.period = a.period
WHERE a.period BETWEEN 1 AND 12
GROUP BY 1
ORDER BY 1;
