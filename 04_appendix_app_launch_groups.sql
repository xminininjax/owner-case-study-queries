-- 04  Appendix slide 10: when each restaurant launched the App, and how many are in the slide 5 test
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
launch AS (   -- App launch = first month with 10+ App orders. la = months since joining at launch (0 = month 1)
  SELECT f.location_id, f.first_d,
         MIN(CASE WHEN a.app_orders >= 10 THEN a.k END) AS la,
         MAX(a.k) AS max_age
  FROM loc_first f LEFT JOIN loc_age a ON a.location_id = f.location_id
  GROUP BY 1, 2
),
app_group AS (   -- launched 3+ months after joining, 12 full months of data after, orders in every month from 3 before to 12 after
  SELECT l.location_id, l.la
  FROM launch l
  JOIN loc_age a ON a.location_id = l.location_id AND a.k BETWEEN l.la - 3 AND l.la + 11
  WHERE l.la >= 3 AND l.la + 11 <= l.max_age
  GROUP BY 1, 2
  HAVING MIN(a.orders) > 0
)
SELECT CASE WHEN l.la IS NULL THEN '5 Never launched'
            WHEN l.first_d < DATE '2023-01-01' AND l.la >= 3 THEN '1 Joined before the App existed (pre-2023)'
            WHEN l.la <= 2 THEN '2 At onboarding (months 1 to 3)'
            WHEN l.la <= 5 THEN '3 Months 4 to 6 after joining'
            ELSE '4 Month 7 or later' END AS launch_group,
       COUNT(*) AS restaurants,                                                  -- 17 / 142 / 44 / 13 / 79
       SUM(CASE WHEN g.location_id IS NOT NULL THEN 1 ELSE 0 END) AS in_test     -- 5 / 0 / 22 / 2 / 0 = 29
FROM launch l
LEFT JOIN app_group g ON g.location_id = l.location_id
GROUP BY 1
ORDER BY 1;
