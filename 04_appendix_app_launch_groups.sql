-- 04  Appendix slide 10: when restaurants launched the App, and the 42 in the test
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
nums AS (   -- 0, 1, 2 ... 99
  SELECT ROW_NUMBER() OVER (ORDER BY order_id) - 1 AS n FROM demo_db.public.product_analytics_case_v2 QUALIFY n < 100
),
loc_age AS (   -- every month from joining to Jun 2025, zero-filled. k = months since joining (k = 0 is the partial join month)
  SELECT f.location_id, nums.n AS k, DATEADD(month, nums.n, f.first_month) AS m,
         COALESCE(lm.orders, 0) AS orders, COALESCE(lm.app_orders, 0) AS app_orders
  FROM loc_first f
  JOIN nums ON DATEADD(month, nums.n, f.first_month) <= DATE '2025-06-01'
  LEFT JOIN loc_month lm ON lm.location_id = f.location_id AND lm.m = DATEADD(month, nums.n, f.first_month)
),
launch AS (   -- App launch = first month with 10+ App orders. la = months since joining at launch
  SELECT f.location_id, f.first_month,
         MIN(CASE WHEN a.app_orders >= 10 THEN a.k END) AS la,
         DATEDIFF(month, f.first_month, DATE '2025-06-01') AS max_age
  FROM loc_first f JOIN loc_age a ON a.location_id = f.location_id
  GROUP BY 1, 2
),
app_group AS (   -- the 42: launched 3+ months after joining, 12 months of data after, orders every month from 3 before to 12 after
  SELECT l.location_id, l.la
  FROM launch l
  JOIN loc_age a ON a.location_id = l.location_id AND a.k BETWEEN l.la - 3 AND l.la + 11
  WHERE l.la >= 3 AND l.la + 11 <= l.max_age
  GROUP BY 1, 2
  HAVING MIN(a.orders) > 0
)
SELECT CASE WHEN l.la IS NULL THEN '5 Never launched'
            WHEN l.first_month < DATE '2023-01-01' AND l.la >= 3 THEN '1 Joined before the App existed (pre-2023)'
            WHEN l.la <= 2 THEN '2 At onboarding (0 to 2 months)'
            WHEN l.la <= 5 THEN '3 3 to 5 months after joining'
            ELSE '4 6+ months after joining' END AS launch_group,
       COUNT(*) AS restaurants,                                                  -- 17 / 130 / 55 / 18 / 75
       SUM(CASE WHEN g.location_id IS NOT NULL THEN 1 ELSE 0 END) AS in_test     -- 5 / 0 / 35 / 2 / 0 = 42
FROM launch l
LEFT JOIN app_group g ON g.location_id = l.location_id
GROUP BY 1
ORDER BY 1;
