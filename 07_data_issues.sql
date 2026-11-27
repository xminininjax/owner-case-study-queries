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
