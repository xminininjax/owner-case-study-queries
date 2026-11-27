-- 11  Slide 7 rows 1 and 2: sizing the App gap for active restaurants without the App
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
loc_status AS (   -- stopped = no orders after Apr 30 2025. launched_app = ever had a month with 10+ App orders
  SELECT f.location_id, f.first_d, f.last_d,
         f.last_d < DATE '2025-05-01' AS stopped,
         MAX(lp.app_orders) >= 10 AS launched_app
  FROM loc_first f JOIN loc_mo lp ON lp.location_id = f.location_id
  GROUP BY 1, 2, 3
)
SELECT COUNT(DISTINCT o.location_id) AS restaurants,                         -- 43 active restaurants without the App
       ROUND(SUM(o.gmv) / 3) AS owner_gmv_a_month,                           -- ~$476K (last 3 months, Apr 2 to Jun 30 2025, divided by 3)
       ROUND(SUM(o.gmv) / 3 * (1.489 / 1.158 - 1)) AS gain_a_month,      -- ~$136K, 148.9% / 115.8% = +29% (slide 5 gap at +12)
       ROUND(103.52 - 69.53, 2) AS value_per_guest_moved_web_to_app           -- ~$34 (file 03)
FROM orders o
JOIN loc_status s ON s.location_id = o.location_id
WHERE NOT s.stopped AND NOT s.launched_app AND o.ts >= '2025-04-02';
