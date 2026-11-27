-- 03_slide6_guest_value.sql  (slide 6 and appendix slide 11)
-- Guest = a guest ID at one restaurant. Only guests whose first order came after that restaurant
-- launched the App (first calendar month with 10+ App orders), first order Jan 2023 - Dec 2024
-- (so every guest has a full 180 days before the data ends in Jun 2025).
-- Web only / App only = guests who ordered on just one of the two channels in their first 180 days.
CREATE OR REPLACE TABLE app_launch_month AS
SELECT location_id, min(m) AS launch_month FROM loc_month WHERE app_orders >= 10 GROUP BY 1;

CREATE OR REPLACE TABLE guest_first AS
SELECT location_id, guest_id, min(ts) AS first_ts FROM orders WHERE guest_id IS NOT NULL GROUP BY 1, 2;

CREATE OR REPLACE TABLE guest_180 AS
SELECT g.location_id, g.guest_id, count(*) AS n, sum(o.gmv) AS value,
       count(DISTINCT o.order_source) AS n_sources, min(o.order_source) AS source
FROM guest_first g
JOIN app_launch_month l ON l.location_id = g.location_id AND g.first_ts >= l.launch_month
JOIN orders o ON o.location_id = g.location_id AND o.guest_id = g.guest_id AND o.ts < g.first_ts + INTERVAL 180 DAY
WHERE g.first_ts >= '2023-01-01' AND g.first_ts < '2025-01-01'
GROUP BY 1, 2;

SELECT source AS channel, count(*) AS guests, round(avg(n), 2) AS orders_per_guest,
       round(sum(value) / sum(n), 2) AS avg_order, round(avg(value), 2) AS value_per_guest
FROM guest_180 WHERE n_sources = 1 AND source IN ('App', 'Web') GROUP BY 1 ORDER BY 1;
-- Web 237k guests, 1.46 orders, $47.61, $69.60 | App ~42.5k guests, 2.53 orders, ~$40.9, ~$103.5

-- Sensitivity: 90-day window (same guests) and 365-day window (first order Jan 2023 - Jun 2024)
WITH w AS (
  SELECT '90 days' AS window_, g.location_id, g.guest_id, count(*) n, sum(o.gmv) v, count(DISTINCT o.order_source) ns, min(o.order_source) s
  FROM guest_first g JOIN app_launch_month l ON l.location_id = g.location_id AND g.first_ts >= l.launch_month
  JOIN orders o ON o.location_id = g.location_id AND o.guest_id = g.guest_id AND o.ts < g.first_ts + INTERVAL 90 DAY
  WHERE g.first_ts >= '2023-01-01' AND g.first_ts < '2025-01-01' GROUP BY 1, 2, 3
  UNION ALL
  SELECT '365 days', g.location_id, g.guest_id, count(*), sum(o.gmv), count(DISTINCT o.order_source), min(o.order_source)
  FROM guest_first g JOIN app_launch_month l ON l.location_id = g.location_id AND g.first_ts >= l.launch_month
  JOIN orders o ON o.location_id = g.location_id AND o.guest_id = g.guest_id AND o.ts < g.first_ts + INTERVAL 365 DAY
  WHERE g.first_ts >= '2023-01-01' AND g.first_ts < '2024-07-01' GROUP BY 1, 2, 3)
SELECT window_, s AS channel, count(*) AS guests, round(avg(n), 2) AS orders_per_guest,
       round(sum(v) / sum(n), 2) AS avg_order, round(avg(v), 2) AS value_per_guest
FROM w WHERE ns = 1 AND s IN ('App', 'Web') GROUP BY 1, 2 ORDER BY 1, 2;
-- App vs Web value: +31% at 90 days, +64% at 365 days
