-- 02  Slide 5 (and slide 2 "+33 pts", slide 7 row 1): App vs no-App, 12 months, 42 launches vs 58 restaurants
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
),
comparison_pairs AS (   -- same-age restaurants with no App through the window and orders every month (one row per App restaurant they are compared with)
  SELECT p.location_id, g.location_id AS app_location_id, g.la
  FROM app_group g
  JOIN launch p ON p.location_id <> g.location_id
  JOIN loc_age a ON a.location_id = p.location_id AND a.k BETWEEN g.la - 3 AND g.la + 11
  WHERE (p.la IS NULL OR p.la > g.la + 11) AND p.max_age >= g.la + 11
  GROUP BY 1, 2, 3
  HAVING MIN(a.orders) > 0
),
grp AS (
  SELECT 'App' AS grp, location_id, la FROM app_group
  UNION ALL
  SELECT 'No App', location_id, la FROM comparison_pairs
),
pts AS (
  SELECT g.grp, a.k - g.la AS j, SUM(a.orders) AS orders
  FROM grp g JOIN loc_age a ON a.location_id = g.location_id AND a.k BETWEEN g.la - 3 AND g.la + 11
  GROUP BY 1, 2
),
curves AS (   -- rebased so the launch month = 100%
  SELECT grp, j, orders / MAX(CASE WHEN j = -1 THEN orders END) OVER (PARTITION BY grp) AS idx FROM pts
)
SELECT CASE WHEN j = -1 THEN 'Launch' WHEN j < -1 THEN CAST(j + 1 AS VARCHAR) ELSE '+' || CAST(j + 1 AS VARCHAR) END AS month,
       ROUND(100 * MAX(CASE WHEN grp = 'App' THEN idx END), 1) AS app_pct,          -- 152.9 at +12
       ROUND(100 * MAX(CASE WHEN grp = 'No App' THEN idx END), 1) AS no_app_pct,    -- 120.2 at +12
       ROUND(100 * (MAX(CASE WHEN grp = 'App' THEN idx END) - MAX(CASE WHEN grp = 'No App' THEN idx END)), 1) AS gap_pts,   -- +4 at +1, +33 at +12
       (SELECT COUNT(*) FROM app_group) AS app_launches,                                         -- 42
       (SELECT COUNT(DISTINCT location_id) FROM comparison_pairs) AS comparison_restaurants      -- 58
FROM curves
GROUP BY j
ORDER BY j;
