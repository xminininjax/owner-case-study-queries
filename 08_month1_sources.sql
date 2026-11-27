-- 08_month1_sources.sql  (slide 4: where the first month's orders come from)
CREATE OR REPLACE TABLE ord_age AS
SELECT o.*, datediff('day', fo.first_ts, o.ts) AS day_n,
       datediff('month', date_trunc('month', fo.first_ts), date_trunc('month', o.ts)) AS k
FROM orders o JOIN (SELECT location_id, min(ts) AS first_ts FROM orders GROUP BY 1) fo USING (location_id);

-- Orders per restaurant per day, by days since the restaurant's first order (gradual ramp, no launch spike)
WITH b AS (
  SELECT CASE WHEN day_n < 1 THEN 0 WHEN day_n < 7 THEN 1 WHEN day_n < 14 THEN 7 WHEN day_n < 30 THEN 14
              WHEN day_n < 60 THEN 30 WHEN day_n < 90 THEN 60 ELSE 90 END AS from_day
  FROM ord_age WHERE day_n < 180)
SELECT from_day, round(count(*) * 1.0 / (SELECT count(DISTINCT location_id) FROM orders)
       / CASE from_day WHEN 0 THEN 1 WHEN 1 THEN 6 WHEN 7 THEN 7 WHEN 14 THEN 16 WHEN 30 THEN 30 WHEN 60 THEN 30 ELSE 90 END, 2)
       AS orders_per_restaurant_per_day
FROM b GROUP BY 1 ORDER BY 1;                                       -- 2.5, 3.5, 5.2, 6.4, 7.3, 7.8, 8.2

-- Coupon share, Google/UTM-tagged share and App share by month on Owner
SELECT k AS month_on_owner, count(*) AS orders,
       round(avg(CASE WHEN has_coupon THEN 1 ELSE 0 END), 3) AS coupon_share,
       round(avg(CASE WHEN utm_source = 'google' THEN 1 ELSE 0 END), 3) AS google_share,
       round(avg(CASE WHEN utm_source IS NOT NULL THEN 1 ELSE 0 END), 3) AS any_utm_share,
       round(avg(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END), 3) AS app_share
FROM ord_age WHERE k BETWEEN 0 AND 12 GROUP BY 1 ORDER BY 1;

-- Month-1 guests: distinct guests per restaurant, orders per guest, share ordering twice
WITH m AS (SELECT location_id, guest_id, count(*) n FROM ord_age WHERE k = 1 GROUP BY 1, 2)
SELECT round(count(*) * 1.0 / count(DISTINCT location_id), 1) AS guests_per_restaurant,
       round(avg(n), 2) AS orders_per_guest,
       round(avg(CASE WHEN n >= 2 THEN 1 ELSE 0 END), 3) AS share_2plus
FROM m;                                                             -- ~173, 1.19, 12%
