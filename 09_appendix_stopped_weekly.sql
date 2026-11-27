-- 09_appendix_stopped_weekly.sql  (appendix slide 12: stopped restaurants' orders over time)
-- Needs 00_base.sql. Stopped = last order before May 2025 (same 95 as 06_appendix_stopped_restaurants.sql).
CREATE OR REPLACE TABLE loc_days AS
SELECT location_id, min(ts)::DATE AS first_d, max(ts)::DATE AS last_d FROM orders GROUP BY 1;

-- Chart: all 95 stopped restaurants. Week 0 = the 7 days ending on the last order.
-- Each week averages the restaurants already on Owner that week (74 at week -25, all 95 from week -4).
WITH s AS (SELECT * FROM loc_days WHERE last_d < DATE '2025-05-01'),
wk AS (SELECT s.location_id, w.week FROM s, range(-25, 1) AS w(week)
       WHERE s.first_d <= s.last_d + (7 * w.week - 6)::INT),
o AS (SELECT o.location_id, -(datediff('day', o.ts::DATE, s.last_d) // 7) AS week, count(*) AS n
      FROM orders o JOIN s USING (location_id) WHERE datediff('day', o.ts::DATE, s.last_d) < 182 GROUP BY 1, 2)
SELECT wk.week, count(*) AS restaurants, round(avg(coalesce(o.n, 0)), 1) AS orders_per_restaurant
FROM wk LEFT JOIN o USING (location_id, week) GROUP BY 1 ORDER BY 1;   -- about 57 a week, 49.1 in week 0, then 0

-- How many of the 95 still had 5+ orders in their final 7 days
WITH s AS (SELECT * FROM loc_days WHERE last_d < DATE '2025-05-01')
SELECT count(*) AS stopped,
       sum(CASE WHEN (SELECT count(*) FROM orders o WHERE o.location_id = s.location_id AND o.ts::DATE > s.last_d - 7) >= 5 THEN 1 ELSE 0 END) AS busy_final_week
FROM s;                                                             -- 95, 90

-- When they stopped: by quarter, and the most stops on a single day
SELECT year(last_d) AS yr, quarter(last_d) AS qtr, count(*) AS stops
FROM loc_days WHERE last_d < DATE '2025-05-01' GROUP BY 1, 2 ORDER BY 1, 2;
SELECT max(n) AS most_stops_one_day FROM (
  SELECT last_d, count(*) AS n FROM loc_days WHERE last_d < DATE '2025-05-01' GROUP BY 1);  -- 3
