-- 04_appendix_app_launch_groups.sql  (appendix slide 10)
-- When each of the 295 restaurants launched the App (first month with 10+ App orders), by age at launch.
-- "In the test" (original 4-month test) = launched 3+ months after joining and has 3+ months of data after launch.
WITH x AS (
  SELECT l.location_id, f.first_month, l.la, l.max_age
  FROM launch l JOIN loc_first f USING (location_id))
SELECT CASE WHEN la IS NULL THEN '5 Never launched'
            WHEN first_month < DATE '2023-01-01' AND la >= 3 THEN '1 Joined before the App existed (pre-2023)'
            WHEN la <= 2 THEN '2 At onboarding (0 to 2 months)'
            WHEN la <= 5 THEN '3 3 to 5 months after joining'
            ELSE '4 6+ months after joining' END AS launch_group,
       count(*) AS restaurants,
       sum(CASE WHEN la >= 3 AND la + 3 <= max_age THEN 1 ELSE 0 END) AS in_test
FROM x GROUP BY 1 ORDER BY 1;                                       -- 17/16, 130/0, 55/55, 18/14, 75
