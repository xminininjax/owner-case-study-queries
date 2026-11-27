-- 01b  Slide 4: average growth a month from month 3 to month 12 (one number)
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
loc_month AS (   -- calendar months are used only to pick the cohort (still ordering a year apart)
  SELECT location_id, DATE_TRUNC('month', ts)::DATE AS m FROM orders GROUP BY 1, 2
),
cohort AS (   -- ordered in the same month (Jan to Jun) of 2024 and 2025, and the 2024 month was 3+ months after joining
  SELECT DISTINCT cur.location_id
  FROM loc_month cur
  JOIN loc_month prev ON prev.location_id = cur.location_id AND prev.m = DATEADD(year, -1, cur.m)
  JOIN (SELECT location_id, MIN(m) AS first_month FROM loc_month GROUP BY 1) fm ON fm.location_id = cur.location_id
  WHERE cur.m >= DATE '2025-01-01' AND cur.m < DATE '2025-07-01'
    AND DATEDIFF(month, fm.first_month, prev.m) >= 3
),
curve AS (
  SELECT a.k + 1 AS month_num, COUNT(*) AS restaurants, AVG(a.orders) AS avg_orders
  FROM loc_age a JOIN cohort c ON c.location_id = a.location_id
  WHERE a.k BETWEEN 0 AND 11 GROUP BY 1
)
SELECT ROUND(100 * (POWER(MAX(CASE WHEN month_num = 12 THEN avg_orders END)
                         / MAX(CASE WHEN month_num = 3 THEN avg_orders END), 1 / 9) - 1), 1)
         AS growth_pct_a_month_3_to_12       -- 3.3
FROM curve;
