-- 06  Slides 7, 8 and 12: stopped restaurants, active restaurants without the App, how they stopped
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
),
x AS (   -- stopped restaurants: orders in the 3 months before the final month vs the 3 months before that
  SELECT s.location_id, DATEDIFF(day, s.first_d, s.last_d) AS age_days,
         SUM(CASE WHEN FLOOR(DATEDIFF(day, o.ts::DATE, s.last_d) / 30) BETWEEN 1 AND 3 THEN 1 ELSE 0 END) / 3.0 AS recent,
         SUM(CASE WHEN FLOOR(DATEDIFF(day, o.ts::DATE, s.last_d) / 30) BETWEEN 4 AND 6 THEN 1 ELSE 0 END) / 3.0 AS earlier
  FROM loc_status s JOIN orders o ON o.location_id = s.location_id
  WHERE s.stopped
  GROUP BY 1, 2
)
SELECT CASE WHEN age_days < 180 THEN 'Stopped within 6 months of joining'
            WHEN recent < 0.7 * earlier THEN 'Declined 30% or more first'
            WHEN recent > 1.3 * earlier THEN 'Still growing'
            ELSE 'Flat right up to the end' END AS stop_pattern,
       COUNT(*) AS stopped_restaurants,                                                             -- 53 / 21 / 16 / 5
       (SELECT COUNT(*) FROM loc_status) AS all_restaurants,                                         -- 295
       (SELECT SUM(CASE WHEN stopped THEN 1 ELSE 0 END) FROM loc_status) AS total_stopped,           -- 95
       (SELECT SUM(CASE WHEN NOT stopped AND NOT launched_app THEN 1 ELSE 0 END) FROM loc_status) AS active_without_app,   -- 43
       (SELECT ROUND(100 * AVG(CASE WHEN launched_app THEN 1 ELSE 0 END)) FROM loc_status WHERE stopped) AS pct_stopped_with_app,      -- 63
       (SELECT ROUND(100 * AVG(CASE WHEN launched_app THEN 1 ELSE 0 END)) FROM loc_status WHERE NOT stopped) AS pct_active_with_app   -- 79
FROM x
GROUP BY 1
ORDER BY 2 DESC;
