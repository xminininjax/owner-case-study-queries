-- 06_appendix_stopped_restaurants.sql  (slide 7 "41 restaurants", slide 8 row 5 and slide 12 "95 restaurants")
-- Stopped = last order month before May 2025.
CREATE OR REPLACE TABLE loc_status AS
SELECT f.location_id, f.first_month, f.last_month,
       f.last_month < DATE '2025-05-01' AS stopped,
       EXISTS (SELECT 1 FROM loc_month m WHERE m.location_id = f.location_id AND m.app_orders >= 10) AS launched_app
FROM loc_first f;

SELECT count(*) AS restaurants, sum(CASE WHEN stopped THEN 1 ELSE 0 END) AS stopped,
       sum(CASE WHEN NOT stopped AND NOT launched_app THEN 1 ELSE 0 END) AS active_without_app
FROM loc_status;                                                    -- 295, 95, 41

SELECT CASE WHEN stopped THEN 'Stopped' ELSE 'Active' END AS status,
       round(100 * avg(CASE WHEN launched_app THEN 1 ELSE 0 END), 0) AS pct_launched_app
FROM loc_status GROUP BY 1;                                         -- stopped 64%, active 80%

-- How the 95 stopped: average orders in the 3 months before the last month vs the 3 months before that
WITH s AS (SELECT * FROM loc_status WHERE stopped),
x AS (
  SELECT s.location_id, datediff('month', s.first_month, s.last_month) AS age,
    (SELECT coalesce(sum(orders), 0) FROM loc_month m WHERE m.location_id = s.location_id
       AND m.m BETWEEN s.last_month - INTERVAL 3 MONTH AND s.last_month - INTERVAL 1 MONTH) / 3.0 AS recent,
    (SELECT coalesce(sum(orders), 0) FROM loc_month m WHERE m.location_id = s.location_id
       AND m.m BETWEEN s.last_month - INTERVAL 6 MONTH AND s.last_month - INTERVAL 4 MONTH) / 3.0 AS earlier
  FROM s)
SELECT CASE WHEN age < 6 THEN 'Stopped within 6 months of joining'
            WHEN recent < 0.7 * earlier THEN 'Declined 30% or more first'
            WHEN recent > 1.3 * earlier THEN 'Still growing'
            ELSE 'Flat right up to the end' END AS pattern,
       count(*) AS restaurants
FROM x GROUP BY 1 ORDER BY 2 DESC;                                  -- 58, 19, 13, 5
