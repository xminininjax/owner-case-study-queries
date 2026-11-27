-- 03  Slides 6 and 11: guest value in the first 180 days, Web-only vs App-only guests
-- Snowflake. Paste this whole file into a worksheet and click Run All (Ctrl+Shift+Enter). The table is set on the next line.
SET orders_table = 'demo_db.public.product_analytics_case_v2';   -- <-- the Owner orders table (one row per order)

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM IDENTIFIER($orders_table)
  WHERE gmv > 0 AND number_of_items > 0
    AND order_created_at_pt::TIMESTAMP >= '2020-05-01' AND order_created_at_pt::TIMESTAMP < '2025-07-01'
),
loc_month AS (   -- orders per restaurant per calendar month
  SELECT location_id, DATE_TRUNC('month', ts)::DATE AS m,
         COUNT(DISTINCT order_id) AS orders,
         SUM(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
         SUM(gmv) AS gmv
  FROM orders GROUP BY 1, 2
),
app_launch_month AS (   -- first calendar month with 10+ App orders
  SELECT location_id, MIN(m) AS launch_month FROM loc_month WHERE app_orders >= 10 GROUP BY 1
),
guest_first AS (
  SELECT location_id, guest_id, MIN(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2
),
guest_180 AS (   -- guests whose first order was Jan 2023 to Dec 2024, after their restaurant launched the App
  SELECT g.location_id, g.guest_id, COUNT(*) AS n, SUM(o.gmv) AS value,
         COUNT(DISTINCT o.order_source) AS n_sources, MIN(o.order_source) AS source
  FROM guest_first g
  JOIN app_launch_month l ON l.location_id = g.location_id AND g.first_ts >= l.launch_month
  JOIN orders o ON o.location_id = g.location_id AND o.guest_id = g.guest_id AND o.ts < g.first_ts + INTERVAL '180 days'
  WHERE g.first_ts >= '2023-01-01' AND g.first_ts < '2025-01-01'
  GROUP BY 1, 2
)
SELECT source AS channel,
       COUNT(*) AS guests,                                  -- Web 237,293 | App 42,537
       ROUND(AVG(n), 2) AS orders_per_guest,                -- 1.46 | 2.53
       ROUND(SUM(value) / SUM(n), 2) AS avg_order,          -- $47.61 | $40.92
       ROUND(AVG(value), 2) AS value_per_guest              -- $69.60 | $103.56
FROM guest_180
WHERE n_sources = 1 AND source IN ('App', 'Web')            -- guests who used just one channel
GROUP BY 1
ORDER BY 1;
