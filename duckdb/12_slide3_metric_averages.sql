-- 12_slide3_metric_averages.sql  (slide 3: average of each metric across everyone in the data)
-- Needs 00_base.sql.
-- Restaurant metrics: every restaurant-month from month 1 (first full month) to the restaurant's last month.
WITH rm AS (
  SELECT lm.location_id, lm.m, lm.orders, lm.gmv, datediff('month', f.first_month, lm.m) AS k
  FROM loc_month lm JOIN loc_first f USING (location_id))
SELECT count(DISTINCT location_id) AS restaurants,
       round(avg(orders)) AS avg_monthly_orders,
       round(avg(gmv)) AS avg_monthly_gmv,
       round(avg(CASE WHEN k = 12 THEN orders END)) AS avg_orders_month_12,
       count(CASE WHEN k = 12 THEN 1 END) AS restaurants_with_month_12
FROM rm WHERE k >= 1;

-- Guest metrics: every guest (all restaurants, all channels) whose first order was Jan 2023 to Dec 2024
WITH gf AS (SELECT location_id, guest_id, min(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2),
g AS (
  SELECT gf.location_id, gf.guest_id, count(*) AS n, sum(o.gmv) AS value
  FROM gf JOIN orders o ON o.location_id = gf.location_id AND o.guest_id = gf.guest_id AND o.ts < gf.first_ts + INTERVAL 180 DAY
  WHERE gf.first_ts >= '2023-01-01' AND gf.first_ts < '2025-01-01'
  GROUP BY 1, 2)
SELECT count(*) AS guests, round(avg(n), 2) AS orders_per_guest_180d, round(avg(value), 2) AS value_per_guest_180d
FROM g;
