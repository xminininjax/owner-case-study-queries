-- 12  Slide 3: average of each metric across everyone in the data
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
loc_mo AS (   -- orders per restaurant per month since joining. k = 0 is month 1, k = 1 is month 2 ...
  SELECT o.location_id, FLOOR(DATEDIFF(day, f.first_d, o.ts::DATE) / 30) AS k,
         COUNT(DISTINCT o.order_id) AS orders,
         SUM(CASE WHEN o.order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
         SUM(o.gmv) AS gmv
  FROM orders o JOIN loc_first f ON f.location_id = o.location_id
  GROUP BY 1, 2
),
nums AS (   -- 0, 1, 2 ... 99
  SELECT ROW_NUMBER() OVER (ORDER BY order_id) - 1 AS n FROM demo_db.public.product_analytics_case_v2 QUALIFY n < 100
),
loc_age AS (   -- every full month since joining, up to Jun 30 2025, zero-filled
  SELECT f.location_id, nums.n AS k,
         COALESCE(lp.orders, 0) AS orders, COALESCE(lp.app_orders, 0) AS app_orders, COALESCE(lp.gmv, 0) AS gmv
  FROM loc_first f
  JOIN nums ON DATEADD(day, 30 * (nums.n + 1), f.first_d) <= DATE '2025-07-01'
  LEFT JOIN loc_mo lp ON lp.location_id = f.location_id AND lp.k = nums.n
),
r AS (   -- every full month since joining in which a restaurant had orders
  SELECT COUNT(DISTINCT location_id) AS restaurants,                                       -- 294
         ROUND(AVG(orders)) AS avg_orders_a_month,                                     -- 279
         ROUND(AVG(gmv)) AS avg_gmv_a_month,                                           -- ~$12.8K
         ROUND(AVG(CASE WHEN k = 11 THEN orders END)) AS avg_orders_month_12             -- 294
  FROM loc_age WHERE orders > 0
),
gf AS (SELECT location_id, guest_id, MIN(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2),
g AS (   -- every guest whose first order was Jan 2023 to Dec 2024, first 6 months (180 days)
  SELECT COUNT(*) AS guests, ROUND(AVG(n), 2) AS orders_per_guest_180d, ROUND(AVG(value), 2) AS value_per_guest_180d
  FROM (SELECT gf.location_id, gf.guest_id, COUNT(*) AS n, SUM(o.gmv) AS value
        FROM gf JOIN orders o ON o.location_id = gf.location_id AND o.guest_id = gf.guest_id AND o.ts < gf.first_ts + INTERVAL '180 days'
        WHERE gf.first_ts >= '2023-01-01' AND gf.first_ts < '2025-01-01'
        GROUP BY 1, 2)
)
SELECT r.*, g.*      -- guests 444,047 | 1.78 orders | $82.76 (guest window = first 6 months, 180 days)
FROM r CROSS JOIN g;
