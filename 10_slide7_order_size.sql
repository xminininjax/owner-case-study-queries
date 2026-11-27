-- 10_slide7_order_size.sql  (slide 7, row 3 impact and footnote)
-- Needs 00_base.sql. Restaurant-months from Jul 2024 to Jun 2025 with the App live (10+ App orders that month).
WITH lm AS (
  SELECT location_id, date_trunc('month', ts) AS m,
         sum(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
         sum(CASE WHEN order_source = 'App' THEN gmv ELSE 0 END) AS app_gmv,
         count(DISTINCT CASE WHEN order_source = 'App' THEN guest_id END) AS app_guests,
         sum(gmv) AS gmv
  FROM orders WHERE ts >= '2024-07-01' GROUP BY 1, 2)
SELECT count(DISTINCT location_id) AS restaurants,               -- 185
       round(avg(app_guests)) AS app_guests_a_month,              -- 83
       round(avg(app_orders)) AS app_orders_a_month,              -- 128
       round(sum(app_gmv) / sum(app_orders), 2) AS app_order_value, -- 39.01
       round(avg(app_gmv)) AS app_gmv_a_month,                    -- 4,992
       round(avg(app_gmv) * 0.14) AS gain_if_14pct_bigger,        -- ~699
       round(avg(gmv)) AS owner_gmv_a_month                       -- 16,614 (so +4%)
FROM lm WHERE app_orders >= 10;
-- Guest value: 180-day App guest value $103.52 (03_slide6_guest_value.sql) x 1.14 = ~$118
