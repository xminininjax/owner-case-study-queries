-- 10  Slide 7 row 3 and slide 11: average App restaurant, and the +14% order-size math
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM demo_db.public.product_analytics_case_v2
  WHERE gmv > 0 AND number_of_items > 0
    AND order_created_at_pt::TIMESTAMP >= '2020-05-01' AND order_created_at_pt::TIMESTAMP < '2025-07-01'
),
lm AS (   -- restaurant-months from Jul 2024 to Jun 2025
  SELECT location_id, DATE_TRUNC('month', ts) AS m,
         SUM(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
         SUM(CASE WHEN order_source = 'App' THEN gmv ELSE 0 END) AS app_gmv,
         COUNT(DISTINCT CASE WHEN order_source = 'App' THEN guest_id END) AS app_guests,
         SUM(gmv) AS gmv
  FROM orders WHERE ts >= '2024-07-01' GROUP BY 1, 2
)
SELECT COUNT(DISTINCT location_id) AS restaurants,                 -- 185
       ROUND(AVG(app_guests)) AS app_guests_a_month,               -- 83
       ROUND(AVG(app_orders)) AS app_orders_a_month,               -- 128
       ROUND(SUM(app_gmv) / SUM(app_orders), 2) AS app_order_value,   -- $39.01
       ROUND(AVG(app_gmv)) AS app_gmv_a_month,                     -- ~$5,000
       ROUND(AVG(app_gmv) * 0.14) AS gain_if_14pct_bigger,         -- ~$700
       ROUND(AVG(gmv)) AS owner_gmv_a_month                        -- $16.6K (so +4%)
FROM lm
WHERE app_orders >= 10;                                            -- months with the App live
-- Guest value: $103.56 (file 03) x 1.14 = ~$118
