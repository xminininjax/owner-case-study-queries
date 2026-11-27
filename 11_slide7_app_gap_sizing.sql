-- 11  Slide 7 rows 1 and 2, and slide 11: ~$125K a month and +$34 per guest
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
)
SELECT COUNT(DISTINCT lm.location_id) AS restaurants,                         -- 41 active restaurants without the App
       ROUND(SUM(lm.gmv) / 3) AS monthly_owner_gmv,                           -- ~$461K (Apr to Jun 2025 average)
       ROUND(SUM(lm.gmv) / 3 * (1.5286 / 1.2024 - 1)) AS gain_a_month,        -- ~$125K (slide 5: 152.9% / 120.2% = +27%)
       ROUND(103.56 - 69.60, 2) AS value_per_guest_moved_web_to_app           -- ~$34 (file 03)
FROM loc_month lm
JOIN loc_status s ON s.location_id = lm.location_id
WHERE NOT s.stopped AND NOT s.launched_app AND lm.m >= DATE '2025-04-01';
