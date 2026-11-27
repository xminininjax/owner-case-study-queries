-- 10  Slide 7 row 3: App order size, per restaurant per month with the App live
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
lp AS (   -- per restaurant per month since joining, keeping only full months that fall between Jul 1 2024 and Jun 30 2025
  SELECT * FROM (
    SELECT o.location_id, FLOOR(DATEDIFF(day, f.first_d, o.ts::DATE) / 30) AS k, f.first_d,
           SUM(CASE WHEN o.order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
           SUM(CASE WHEN o.order_source = 'App' THEN o.gmv ELSE 0 END) AS app_gmv,
           COUNT(DISTINCT CASE WHEN o.order_source = 'App' THEN o.guest_id END) AS app_guests,
           SUM(o.gmv) AS gmv
    FROM orders o JOIN loc_first f ON f.location_id = o.location_id
    GROUP BY 1, 2, 3
  ) x
  WHERE DATEADD(day, 30 * k, first_d) >= DATE '2024-07-01'
    AND DATEADD(day, 30 * (k + 1), first_d) <= DATE '2025-07-01'
)
SELECT COUNT(DISTINCT location_id) AS restaurants,                 -- 182
       ROUND(AVG(app_guests)) AS app_guests_a_month,            -- 82
       ROUND(AVG(app_orders)) AS app_orders_a_month,            -- 126
       ROUND(SUM(app_gmv) / SUM(app_orders), 2) AS app_order_value,   -- $39.03
       ROUND(AVG(app_gmv)) AS app_gmv_a_month,                  -- ~$4,900
       ROUND(AVG(app_gmv) * 0.14) AS gain_if_14pct_bigger,         -- ~$700
       ROUND(AVG(gmv)) AS owner_gmv_a_month                     -- ~$16.4K
FROM lp
WHERE app_orders >= 10;                                            -- months with the App live
-- Guest value: App value per guest (file 03) x 1.14 = $103.52 x 1.14 = ~$118
