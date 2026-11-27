-- 01  Slides 2 and 4: the 147 restaurants, 0 to 320 orders a month, +2.8% a month from month 3 to 12
-- Snowflake. Paste this whole file into a worksheet and click Run All (Ctrl+Shift+Enter). The table is set on the next line.
SET orders_table = 'demo_db.public.product_analytics_case_v2';   -- <-- the Owner orders table (one row per order)

WITH
orders AS (   -- clean orders: GMV > 0, 1+ items, May 2020 to Jun 2025
  SELECT order_id, location_id, guest_id, order_created_at_pt::TIMESTAMP AS ts, order_source, order_type,
         delivery_type, has_coupon::BOOLEAN AS has_coupon, utm_source, number_of_items, gmv
  FROM IDENTIFIER($orders_table)
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
  SELECT ROW_NUMBER() OVER (ORDER BY order_id) - 1 AS n FROM IDENTIFIER($orders_table) QUALIFY n < 100
),
loc_age AS (   -- every month from joining to Jun 2025, zero-filled. k = months since joining (k = 0 is the partial join month)
  SELECT f.location_id, nums.n AS k, DATEADD(month, nums.n, f.first_month) AS m,
         COALESCE(lm.orders, 0) AS orders, COALESCE(lm.app_orders, 0) AS app_orders
  FROM loc_first f
  JOIN nums ON DATEADD(month, nums.n, f.first_month) <= DATE '2025-06-01'
  LEFT JOIN loc_month lm ON lm.location_id = f.location_id AND lm.m = DATEADD(month, nums.n, f.first_month)
),
cohort AS (   -- the 147: ordered in the same month (Jan to Jun) of 2024 and 2025, 2024 month 3+ months after joining
  SELECT DISTINCT cur.location_id
  FROM loc_month cur
  JOIN loc_month prev ON prev.location_id = cur.location_id AND prev.m = DATEADD(year, -1, cur.m)
  JOIN loc_first f ON f.location_id = cur.location_id
  WHERE cur.m >= DATE '2025-01-01' AND cur.m < DATE '2025-07-01'
    AND DATEDIFF(month, f.first_month, prev.m) >= 3
),
curve AS (
  SELECT a.k, COUNT(*) AS restaurants, AVG(a.orders) AS avg_orders
  FROM loc_age a JOIN cohort c ON c.location_id = a.location_id
  WHERE a.k BETWEEN 0 AND 12 GROUP BY 1
)
SELECT k AS month_on_owner,
       restaurants,                                   -- 147
       ROUND(avg_orders, 1) AS avg_orders,            -- month 0 ~60, month 1 197, month 3 249, month 12 320
       ROUND(100 * (POWER(MAX(CASE WHEN k = 12 THEN avg_orders END) OVER ()
                        / MAX(CASE WHEN k = 3 THEN avg_orders END) OVER (), 1 / 9) - 1), 1)
         AS monthly_growth_pct_m3_to_m12              -- 2.8
FROM curve
ORDER BY k;
