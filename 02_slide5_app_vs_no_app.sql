-- 02_slide5_app_vs_no_app.sql  (slide 5, slide 2 "+33 pts")
-- App launch = first month with 10+ App orders. la = restaurant age (months since first order month) at launch.
CREATE OR REPLACE TABLE launch AS
SELECT f.location_id,
       min(CASE WHEN a.app_orders >= 10 THEN a.k END) AS la,
       datediff('month', f.first_month, DATE '2025-06-01') AS max_age
FROM loc_first f JOIN loc_age a USING (location_id)
GROUP BY f.location_id, f.first_month;

-- Window: 3 months before launch to 11 months after the launch month (chart points -2 ... +12).
-- "Still ordering" rule: the restaurant has orders in EVERY month of that window.
CREATE OR REPLACE TABLE app_group AS
SELECT l.location_id, l.la
FROM launch l
WHERE l.la >= 3 AND l.la + 11 <= l.max_age
  AND (SELECT min(orders) FROM loc_age a WHERE a.location_id = l.location_id AND a.k BETWEEN l.la - 3 AND l.la + 11) > 0;

-- Comparison restaurants: same age, no App launch through the window, still ordering through the window.
-- One comparison row per (App restaurant age, comparison restaurant).
-- Note: a comparison restaurant is counted once for each App restaurant of the same launch age.
CREATE OR REPLACE TABLE comparison_pairs AS
SELECT p.location_id, g.la
FROM app_group g JOIN launch p ON p.location_id <> g.location_id
WHERE (p.la IS NULL OR p.la > g.la + 11) AND p.max_age >= g.la + 11
  AND (SELECT min(orders) FROM loc_age a WHERE a.location_id = p.location_id AND a.k BETWEEN g.la - 3 AND g.la + 11) > 0;

SELECT (SELECT count(*) FROM app_group) AS app_launches,
       (SELECT count(DISTINCT location_id) FROM comparison_pairs) AS comparison_restaurants;   -- 42, 58

-- Curves: total orders at each month relative to launch / total pre-launch monthly average, then rebased so Launch = 100%
CREATE OR REPLACE TABLE curves AS
WITH grp AS (
  SELECT 'App' AS grp, location_id, la FROM app_group
  UNION ALL SELECT 'No App', location_id, la FROM comparison_pairs),
pts AS (
  SELECT g.grp, a.k - g.la AS j, sum(a.orders) AS orders
  FROM grp g JOIN loc_age a ON a.location_id = g.location_id AND a.k BETWEEN g.la - 3 AND g.la + 11
  GROUP BY 1, 2)
SELECT grp, j, orders / max(CASE WHEN j = -1 THEN orders END) OVER (PARTITION BY grp) AS idx FROM pts;

-- Chart table: label -2, -1, Launch (= month before the first 10+ App-order month), +1 ... +12
SELECT CASE WHEN j = -1 THEN 'Launch' WHEN j < -1 THEN CAST(j + 1 AS VARCHAR) ELSE '+' || CAST(j + 1 AS VARCHAR) END AS month,
       round(100 * max(CASE WHEN grp = 'App' THEN idx END), 1) AS app_pct,
       round(100 * max(CASE WHEN grp = 'No App' THEN idx END), 1) AS no_app_pct,
       round(100 * (max(CASE WHEN grp = 'App' THEN idx END) - max(CASE WHEN grp = 'No App' THEN idx END)), 1) AS gap_pts
FROM curves GROUP BY j ORDER BY j;                                  -- gap +4 at +1, +33 at +12 (153% vs 120%)
