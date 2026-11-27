-- 01_slide4_growth_cohort.sql  (slides 2 and 4)
-- The 147 restaurants: ordered in the same month (Jan-Jun) of both 2024 and 2025,
-- with the 2024 month at least 3 months after joining.
CREATE OR REPLACE TABLE cohort147 AS
SELECT DISTINCT cur.location_id
FROM loc_month cur
JOIN loc_month prev ON prev.location_id = cur.location_id AND prev.m = cur.m - INTERVAL 1 YEAR
JOIN loc_first f ON f.location_id = cur.location_id
WHERE cur.m >= '2025-01-01' AND cur.m < '2025-07-01'
  AND datediff('month', f.first_month, prev.m) >= 3;

SELECT count(*) AS restaurants FROM cohort147;                       -- 147

-- Average monthly Owner orders per restaurant by month since joining (chart on slide 4)
SELECT k AS month_on_owner, count(*) AS restaurants, round(avg(orders), 1) AS avg_orders
FROM loc_age JOIN cohort147 USING (location_id)
WHERE k BETWEEN 0 AND 12 GROUP BY 1 ORDER BY 1;                     -- k=0 ~60, k=1 197, k=3 249, k=12 320

-- Growth rate after the ramp: compound monthly growth from month 3 to month 12
WITH a AS (SELECT k, avg(orders) v FROM loc_age JOIN cohort147 USING (location_id) GROUP BY 1)
SELECT round(100 * (pow((SELECT v FROM a WHERE k = 12) / (SELECT v FROM a WHERE k = 3), 1.0 / 9) - 1), 1)
       AS monthly_growth_pct_m3_to_m12;                              -- 2.8
