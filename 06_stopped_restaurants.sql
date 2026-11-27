-- 06  Slides 7, 8 and 12: 95 stopped restaurants, 41 active restaurants without the App, how they stopped
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
loc_status AS (   -- stopped = last order month before May 2025. launched_app = ever had a month with 10+ App orders
  SELECT f.location_id, f.first_month, f.last_month,
         f.last_month < DATE '2025-05-01' AS stopped,
         MAX(lm.app_orders) >= 10 AS launched_app
  FROM loc_first f JOIN loc_month lm ON lm.location_id = f.location_id
  GROUP BY 1, 2, 3
),
x AS (   -- stopped restaurants: average orders in the 3 months before the last month vs the 3 before that
  SELECT s.location_id, DATEDIFF(month, s.first_month, s.last_month) AS age,
         SUM(CASE WHEN lm.m BETWEEN DATEADD(month, -3, s.last_month) AND DATEADD(month, -1, s.last_month) THEN lm.orders ELSE 0 END) / 3.0 AS recent,
         SUM(CASE WHEN lm.m BETWEEN DATEADD(month, -6, s.last_month) AND DATEADD(month, -4, s.last_month) THEN lm.orders ELSE 0 END) / 3.0 AS earlier
  FROM loc_status s JOIN loc_month lm ON lm.location_id = s.location_id
  WHERE s.stopped
  GROUP BY 1, 2
)
SELECT CASE WHEN age < 6 THEN 'Stopped within 6 months of joining'
            WHEN recent < 0.7 * earlier THEN 'Declined 30% or more first'
            WHEN recent > 1.3 * earlier THEN 'Still growing'
            ELSE 'Flat right up to the end' END AS stop_pattern,
       COUNT(*) AS stopped_restaurants,                                                             -- 58 / 19 / 13 / 5
       (SELECT COUNT(*) FROM loc_status) AS all_restaurants,                                         -- 295
       (SELECT SUM(CASE WHEN stopped THEN 1 ELSE 0 END) FROM loc_status) AS total_stopped,           -- 95
       (SELECT SUM(CASE WHEN NOT stopped AND NOT launched_app THEN 1 ELSE 0 END) FROM loc_status) AS active_without_app,   -- 41
       (SELECT ROUND(100 * AVG(CASE WHEN launched_app THEN 1 ELSE 0 END)) FROM loc_status WHERE stopped) AS pct_stopped_with_app,      -- 64
       (SELECT ROUND(100 * AVG(CASE WHEN launched_app THEN 1 ELSE 0 END)) FROM loc_status WHERE NOT stopped) AS pct_active_with_app   -- 80
FROM x
GROUP BY 1
ORDER BY 2 DESC;
