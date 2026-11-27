-- 09  Appendix slide 12: weekly orders of the 95 stopped restaurants before they stopped
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM demo_db.public.product_analytics_case_v2
  WHERE gmv > 0 AND number_of_items > 0
    AND order_created_at_pt::TIMESTAMP >= '2020-05-01' AND order_created_at_pt::TIMESTAMP < '2025-07-01'
),
loc_days AS (
  SELECT location_id, MIN(ts)::DATE AS first_d, MAX(ts)::DATE AS last_d FROM orders GROUP BY 1
),
s AS (SELECT * FROM loc_days WHERE last_d < DATE '2025-05-01'),
nums AS (SELECT ROW_NUMBER() OVER (ORDER BY location_id) - 1 AS n FROM loc_days QUALIFY n <= 25),
wk AS (   -- one row per restaurant per week it was already on Owner. Week 0 = the 7 days ending on the last order
  SELECT s.location_id, -nums.n AS week
  FROM s JOIN nums ON s.first_d <= DATEADD(day, -7 * nums.n - 6, s.last_d)
),
o AS (
  SELECT o.location_id, -FLOOR(DATEDIFF(day, o.ts::DATE, s.last_d) / 7) AS week, COUNT(*) AS n
  FROM orders o JOIN s ON s.location_id = o.location_id
  WHERE DATEDIFF(day, o.ts::DATE, s.last_d) < 182
  GROUP BY 1, 2
),
busy AS (   -- stopped restaurants with 5+ orders in their final 7 days
  SELECT COUNT(*) AS busy_final_week FROM (
    SELECT s.location_id FROM s JOIN orders o ON o.location_id = s.location_id AND o.ts::DATE > DATEADD(day, -7, s.last_d)
    GROUP BY 1 HAVING COUNT(*) >= 5)
),
spread AS (
  SELECT MIN(last_d) AS first_stop, MAX(last_d) AS last_stop,
         (SELECT MAX(c) FROM (SELECT last_d, COUNT(*) AS c FROM s GROUP BY 1)) AS most_stops_one_day
  FROM s
)
SELECT wk.week,
       COUNT(*) AS restaurants,                                       -- 74 at week -25, all 95 from week -4
       ROUND(AVG(COALESCE(o.n, 0)), 1) AS orders_per_restaurant,      -- about 57 a week, 49.1 in week 0, then 0
       (SELECT COUNT(*) FROM s) AS stopped_restaurants,               -- 95
       MAX(busy.busy_final_week) AS busy_final_week,                  -- 90
       MAX(spread.first_stop) AS first_stop,                          -- Apr 2023
       MAX(spread.last_stop) AS last_stop,                            -- Apr 2025
       MAX(spread.most_stops_one_day) AS most_stops_one_day           -- 3
FROM wk
LEFT JOIN o ON o.location_id = wk.location_id AND o.week = wk.week
CROSS JOIN busy
CROSS JOIN spread
GROUP BY 1
ORDER BY 1;
