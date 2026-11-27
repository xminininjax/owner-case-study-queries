-- 05_appendix_expected_orders.sql  (appendix slide 11, slide 7 "$64K")
-- ORIGINAL 4-month method (85 launches). Restaurants that later went quiet are counted as zero here,
-- unlike slide 5. Expected = own pre-launch average x growth of same-age restaurants without the App.
CREATE OR REPLACE TABLE t85 AS
SELECT location_id, la FROM launch WHERE la >= 3 AND la + 3 <= max_age;

CREATE OR REPLACE TABLE loc_age_gmv AS
SELECT a.location_id, a.k, coalesce(lm.gmv, 0) AS gmv
FROM loc_age a LEFT JOIN loc_month lm ON lm.location_id = a.location_id AND lm.m = a.m;

CREATE OR REPLACE TABLE peers85 AS
SELECT t.location_id AS app_loc, t.la, p.location_id AS peer
FROM t85 t JOIN launch p ON p.location_id <> t.location_id
WHERE (p.la IS NULL OR p.la > t.la + 3) AND p.max_age >= t.la + 3
  AND (SELECT sum(orders) FROM loc_age a WHERE a.location_id = p.location_id AND a.k BETWEEN t.la - 3 AND t.la - 1) > 0;

CREATE OR REPLACE TABLE exp85 AS
WITH own AS (
  SELECT t.location_id, t.la,
    (SELECT avg(orders) FROM loc_age a WHERE a.location_id = t.location_id AND a.k BETWEEN t.la - 3 AND t.la - 1) AS pre_o,
    (SELECT orders FROM loc_age a WHERE a.location_id = t.location_id AND a.k = t.la + 3) AS act_o,
    (SELECT avg(gmv) FROM loc_age_gmv a WHERE a.location_id = t.location_id AND a.k BETWEEN t.la - 3 AND t.la - 1) AS pre_g,
    (SELECT gmv FROM loc_age_gmv a WHERE a.location_id = t.location_id AND a.k = t.la + 3) AS act_g
  FROM t85 t),
pg AS (
  SELECT p.app_loc, p.la,
    sum(CASE WHEN a.k = p.la + 3 THEN a.orders END) / (sum(CASE WHEN a.k BETWEEN p.la - 3 AND p.la - 1 THEN a.orders END) / 3.0) AS g_o,
    sum(CASE WHEN g.k = p.la + 3 THEN g.gmv END) / (sum(CASE WHEN g.k BETWEEN p.la - 3 AND p.la - 1 THEN g.gmv END) / 3.0) AS g_g
  FROM peers85 p
  JOIN loc_age a ON a.location_id = p.peer AND a.k BETWEEN p.la - 3 AND p.la + 3
  JOIN loc_age_gmv g ON g.location_id = p.peer AND g.k = a.k
  GROUP BY 1, 2)
SELECT own.*, own.pre_o * pg.g_o AS exp_o, own.pre_g * pg.g_g AS exp_g
FROM own JOIN pg ON pg.app_loc = own.location_id AND pg.la = own.la;

SELECT count(*) AS launches,
       round(avg(pre_o)) AS orders_pre, round(avg(exp_o)) AS orders_expected, round(avg(act_o)) AS orders_actual,
       round(100 * (sum(act_o) / sum(exp_o) - 1), 1) AS orders_gain_pct,
       round(avg(pre_g)) AS gmv_pre, round(avg(exp_g)) AS gmv_expected, round(avg(act_g)) AS gmv_actual,
       round(avg(act_g - exp_g)) AS gmv_gain_per_restaurant,
       41 * round(avg(act_g - exp_g)) AS rec1_sizing_41_restaurants
FROM exp85;      -- slide: 216 / 242 / 277, +15% | $10,053 / $10,980 / $12,533, +$1,553 | $63,673
