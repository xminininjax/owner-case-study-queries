-- 07_data_issues.sql  (data issues slide 8)
SELECT count(*) AS all_rows,
       sum(CASE WHEN gmv < 0 THEN 1 ELSE 0 END) AS negative_gmv,
       round(100.0 * sum(CASE WHEN gmv < 0 THEN 1 ELSE 0 END) / count(*), 2) AS negative_gmv_pct,
       sum(CASE WHEN gmv = 0 OR number_of_items = 0 THEN 1 ELSE 0 END) AS zero_value_or_zero_items,
       count(*) - count(DISTINCT order_id) AS duplicate_order_ids
FROM raw;                                                           -- 1,514,681 rows, 6,486 negative (0.43%), 0 duplicates

-- What channels the file covers (it is Owner online ordering, not total restaurant sales)
SELECT order_source, count(*) AS orders FROM raw GROUP BY 1 ORDER BY 2 DESC;
SELECT order_type, count(*) AS orders FROM raw GROUP BY 1 ORDER BY 2 DESC;

-- Catering orders (slide 8 row 3): orders with 20 or more items
SELECT count(*) AS catering_orders, round(100.0 * count(*) / (SELECT count(*) FROM raw), 2) AS pct
FROM raw WHERE number_of_items >= 20;                               -- 246 (0.02%)

-- Incomplete orders (slide 8 row 4): delivery orders with no delivery type, or 0 items, or $0 GMV
SELECT count(*) AS incomplete_orders, round(100.0 * count(*) / (SELECT count(*) FROM raw), 2) AS pct
FROM raw WHERE (order_type = 'delivery' AND delivery_type IS NULL)
            OR number_of_items = 0 OR gmv = 0;                      -- 468 (0.03%): 443 no delivery type + 25 with 0 items or $0
