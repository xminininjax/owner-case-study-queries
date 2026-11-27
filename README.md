# Owner case study: queries behind the deck

Every number in the deck comes from one file: the Owner order export `Untitled_2026-11-22-2124.csv`
(1,514,681 orders, 295 restaurant locations, May 2020 to Jul 2025). It holds **Owner Web and App orders only**
(plus under 900 POS and Phone orders): no in-store, third-party phone or delivery-app sales.

**The data file is not in this repo.** Point the run script at your own copy.

## How to run
```
pip install duckdb pandas
python run_all.py /path/to/Untitled_2026-11-22-2124.csv
```
`run_all.py` runs every `.sql` file in name order (DuckDB SQL) and prints each result. Later files reuse
tables built by earlier ones (`00_base.sql` first; `04` needs the `launch` table from `02`).

Shared rules (`00_base.sql`): orders with GMV > 0 and 1+ items, May 2020 to Jun 2025. A "restaurant" is one location.
Month 0 = the partial month a restaurant joins; month 1 = its first full month. App launch = first month with 10+ App orders.

## Slide-by-slide map

| Slide | Figures | File |
|---|---|---|
| 2, 4 | 147 restaurants; ~60 orders in month 0, 197 in month 1, 320 in month 12; +2.8% a month from month 3 to 12 | 01_slide4_growth_cohort.sql |
| 2, 5, 7, 10 | 42 App launches vs 58 comparison restaurants, still ordering every month; gap +4 pts at month 1 to +33 pts at month 12 (153% vs 120%) | 02_slide5_app_vs_no_app.sql |
| 3 | Averages across everyone: 289 orders a month, 297 in month 12, $13.2K GMV a month (294 restaurants); 1.78 orders and $82.76 per guest in 180 days (444K guests) | 12_slide3_metric_averages.sql |
| 4 (talk track) | Month-1 sources: ~8% coupon share, ~54% Google-tagged, 173 guests at 1.19 orders | 08_month1_sources.sql |
| 6, 11 | First 180 days: Web 237,293 guests, 1.46 orders x $47.61 = $69.60; App 42,537 guests, 2.53 x $40.92 = $103.56 (+49%, 1.7x, -14%) | 03_slide6_guest_value.sql |
| 7 row 1, 11 | ~$125K a month: 41 restaurants without the App make ~$461K a month x 27% (153% / 120%) | 11_slide7_app_gap_sizing.sql |
| 7 row 2, 11 | +$34 per guest moving from Web to App: $103.56 - $69.60 | 11_slide7_app_gap_sizing.sql |
| 7 row 3, 11 | 185 App restaurants, 83 App guests and 128 App orders a month at $39 (~$5,000); +14% = ~$700 a month; guest value $104 to $118 | 10_slide7_order_size.sql |
| 7, 8, 12 | 95 stopped restaurants; 41 active restaurants without the App | 06_appendix_stopped_restaurants.sql |
| 8 | 6,486 negative-GMV orders (0.43%); 246 catering orders (20+ items, 0.02%); 468 incomplete orders (443 delivery orders with no delivery type + 25 with 0 items or $0, 0.03%) | 07_data_issues.sql |
| 10 | App launch groups 17 / 130 / 55 / 18 / 75; in the test 5 + 35 + 2 = 42 | 04_appendix_app_launch_groups.sql |
| 12 | Weekly orders before stopping: ~57 a week, 49 in the final week, then 0 (all 95); 90 of 95 had 5+ orders in their final week; stops spread 2023 to 2025, at most 3 on one day | 09_appendix_stopped_weekly.sql |

Every figure above reproduces exactly from the queries.

## Not on the current deck
- `05_appendix_expected_orders.sql`: an earlier draft's 4-month method ($64K sizing). Replaced by `02` and `11`. Kept for reference.
- Two figures from earlier drafts did not reproduce and were removed: "Web guests who switched to the App ordered 54% more" (switcher definition not saved) and "about 45% of App orders are new" (re-run gives about 40%).
