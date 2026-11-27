-- 00_base.sql
-- Base tables used by every other query. Run first.
-- Source: Owner order export (one row per order). Only Owner Web and App orders
-- (plus a few hundred Phone/POS) are in the file: no in-store, phone or delivery-app sales.

CREATE OR REPLACE TABLE raw AS
SELECT * FROM read_csv_auto('{CSV}', header = true);

-- Clean orders: drop refunds/zero-value (GMV <= 0) and empty orders (0 items)
CREATE OR REPLACE TABLE orders AS
SELECT order_id, location_id, guest_id, order_created_at_pt AS ts,
       order_source, has_coupon, coupon_type, utm_source, utm_medium, number_of_items, gmv
FROM raw
WHERE gmv > 0 AND number_of_items > 0
  AND order_created_at_pt >= '2020-05-01' AND order_created_at_pt < '2025-07-01';

-- Orders per restaurant (location) per calendar month
CREATE OR REPLACE TABLE loc_month AS
SELECT location_id, date_trunc('month', ts)::DATE AS m,
       count(DISTINCT order_id) AS orders,
       sum(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,
       sum(gmv) AS gmv
FROM orders GROUP BY 1, 2;

-- First and last order month per restaurant
CREATE OR REPLACE TABLE loc_first AS
SELECT location_id, min(m) AS first_month, max(m) AS last_month FROM loc_month GROUP BY 1;

-- Zero-filled monthly series by age (k = months since first order month, k = 0 is the partial join month)
CREATE OR REPLACE TABLE loc_age AS
SELECT f.location_id, datediff('month', f.first_month, s.m::DATE)::INT AS k, s.m::DATE AS m,
       coalesce(lm.orders, 0) AS orders, coalesce(lm.app_orders, 0) AS app_orders
FROM loc_first f,
     unnest(generate_series(f.first_month, DATE '2025-06-01', INTERVAL 1 MONTH)) AS s(m)
LEFT JOIN loc_month lm ON lm.location_id = f.location_id AND lm.m = s.m::DATE;
