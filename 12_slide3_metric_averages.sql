-- 12  Slide 3: average of each metric across everyone in the data
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM demo_db.public.product_analytics_case_v2
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
loc_first AS (   -- first and last order month per restaurant
  SELECT location_id, MIN(m) AS first_month, MAX(m) AS last_month FROM loc_month GROUP BY 1
),
r AS (   -- every restaurant-month from month 1 (first full month) to the restaurant's last month
  SELECT COUNT(DISTINCT lm.location_id) AS restaurants,                                   -- 294
         ROUND(AVG(lm.orders)) AS avg_monthly_orders,                                    -- 289
         ROUND(AVG(lm.gmv)) AS avg_monthly_gmv,                                          -- $13.2K
         ROUND(AVG(CASE WHEN DATEDIFF(month, f.first_month, lm.m) = 12 THEN lm.orders END)) AS avg_orders_month_12   -- 297
  FROM loc_month lm JOIN loc_first f ON f.location_id = lm.location_id
  WHERE DATEDIFF(month, f.first_month, lm.m) >= 1
),
gf AS (SELECT location_id, guest_id, MIN(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2),
g AS (   -- every guest whose first order was Jan 2023 to Dec 2024, first 180 days
  SELECT COUNT(*) AS guests, ROUND(AVG(n), 2) AS orders_per_guest_180d, ROUND(AVG(value), 2) AS value_per_guest_180d
  FROM (SELECT gf.location_id, gf.guest_id, COUNT(*) AS n, SUM(o.gmv) AS value
        FROM gf JOIN orders o ON o.location_id = gf.location_id AND o.guest_id = gf.guest_id AND o.ts < gf.first_ts + INTERVAL '180 days'
        WHERE gf.first_ts >= '2023-01-01' AND gf.first_ts < '2025-01-01'
        GROUP BY 1, 2)
)
SELECT r.*, g.*      -- guests 444,047 | 1.78 orders | $82.76
FROM r CROSS JOIN g;
