-- 11_slide7_app_gap_sizing.sql  (slide 7 rows 1 and 2, appendix slide 11)
-- Needs 00_base.sql.
-- Row 1: the 41 active restaurants without the App (06_appendix_stopped_restaurants.sql), their average
-- monthly Owner GMV over Apr to Jun 2025, times the slide 5 gap at month 12: 152.9% / 120.2% - 1 = ~27%.
WITH st AS (
  SELECT f.location_id, f.last_month < DATE '2025-05-01' AS stopped,
         EXISTS (SELECT 1 FROM loc_month m WHERE m.location_id = f.location_id AND m.app_orders >= 10) AS app
  FROM loc_first f),
t AS (SELECT location_id FROM st WHERE NOT stopped AND NOT app)
SELECT count(DISTINCT location_id) AS restaurants,                              -- 41
       round(sum(gmv) / 3) AS monthly_owner_gmv,                                -- ~461K
       round(sum(gmv) / 3 * (1.5286 / 1.2024 - 1)) AS gain_a_month              -- ~125K
FROM loc_month JOIN t USING (location_id) WHERE m >= DATE '2025-04-01';
-- Row 2: value of moving one guest from Web to App, first 180 days (03_slide6_guest_value.sql):
-- $103.56 - $69.60 = ~$34.
