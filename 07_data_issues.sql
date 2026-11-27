-- 07  Slide 8: data issues (uses every row, before any cleaning)
-- Snowflake. Paste into a worksheet and click Run (or Run All). Reads demo_db.public.product_analytics_case_v2.

WITH raw AS (SELECT * FROM demo_db.public.product_analytics_case_v2)
SELECT COUNT(*) AS all_rows,                                                                  -- 1,514,681
       SUM(CASE WHEN gmv < 0 THEN 1 ELSE 0 END) AS negative_gmv,                              -- 6,486
       ROUND(100 * SUM(CASE WHEN gmv < 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS negative_gmv_pct,   -- 0.43
       SUM(CASE WHEN number_of_items >= 20 THEN 1 ELSE 0 END) AS catering_orders,             -- 246 (20+ items)
       ROUND(100 * SUM(CASE WHEN number_of_items >= 20 THEN 1 ELSE 0 END) / COUNT(*), 2) AS catering_pct,   -- 0.02
       SUM(CASE WHEN (order_type = 'delivery' AND delivery_type IS NULL) OR number_of_items = 0 OR gmv = 0
                THEN 1 ELSE 0 END) AS incomplete_orders,                                      -- 468 (443 delivery with no type + 25 with 0 items or $0)
       ROUND(100 * SUM(CASE WHEN (order_type = 'delivery' AND delivery_type IS NULL) OR number_of_items = 0 OR gmv = 0
                THEN 1 ELSE 0 END) / COUNT(*), 2) AS incomplete_pct,                          -- 0.03
       COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids,                            -- 0
       SUM(CASE WHEN order_source = 'Web' THEN 1 ELSE 0 END) AS web_orders,                   -- channels in the file: Owner online
       SUM(CASE WHEN order_source = 'App' THEN 1 ELSE 0 END) AS app_orders,                   -- ordering only, plus a few hundred
       SUM(CASE WHEN order_source IN ('POS', 'Phone') THEN 1 ELSE 0 END) AS pos_or_phone_orders   -- POS / Phone
FROM raw;
