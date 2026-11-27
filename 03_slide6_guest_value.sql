-- 03  Slides 6 and 11: guest value in the first 6 months (180 days), Web-only vs App-only guests
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
app_launch AS (   -- App launch date = start of the first month with 10+ App orders
  SELECT a.location_id, DATEADD(day, 30 * MIN(a.k), f.first_d) AS launch_d
  FROM loc_age a JOIN loc_first f ON f.location_id = a.location_id
  WHERE a.app_orders >= 10 GROUP BY a.location_id, f.first_d
),
guest_first AS (
  SELECT location_id, guest_id, MIN(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2
),
guest_180 AS (   -- guests whose first order was Jan 2023 to Dec 2024, after their restaurant launched the App
  SELECT g.location_id, g.guest_id, COUNT(*) AS n, SUM(o.gmv) AS value,
         COUNT(DISTINCT o.order_source) AS n_sources, MIN(o.order_source) AS source
  FROM guest_first g
  JOIN app_launch l ON l.location_id = g.location_id AND g.first_ts >= l.launch_d
  JOIN orders o ON o.location_id = g.location_id AND o.guest_id = g.guest_id AND o.ts < g.first_ts + INTERVAL '180 days'
  WHERE g.first_ts >= '2023-01-01' AND g.first_ts < '2025-01-01'
  GROUP BY 1, 2
)
SELECT source AS channel,
       COUNT(*) AS guests,                                  -- Web 235,579 | App 42,481
       ROUND(AVG(n), 2) AS orders_per_guest,                -- 1.46 | 2.53
       ROUND(SUM(value) / SUM(n), 2) AS avg_order,          -- $47.51 | $40.91
       ROUND(AVG(value), 2) AS value_per_guest              -- $69.53 | $103.52
FROM guest_180
WHERE n_sources = 1 AND source IN ('App', 'Web')            -- guests who used just one channel
GROUP BY 1
ORDER BY 1;
