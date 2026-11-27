# Owner case study: queries behind the deck

Every number in the deck comes from one file: the Owner order export `Untitled_2026-11-22-2124.csv`
(1,514,681 orders, 295 restaurant locations, May 2020 to Jul 2025). It holds **Owner Web and App orders only**:
no in-store, phone or delivery-app sales.

## How to run
```
pip install duckdb pandas
python run_all.py /path/to/Untitled_2026-11-22-2124.csv
```
`run_all.py` runs the `.sql` files in order (DuckDB SQL) and prints each result. `00_base.sql` must run first.

Shared rules (00_base.sql): orders with GMV > 0 and 1+ items, May 2020 to Jun 2025. A "restaurant" is one location.
Month 0 = the partial month a restaurant joins. App launch = first month with 10+ App orders.

## Slide-by-slide map

| Slide | Figure | File | Status |
|---|---|---|---|
| 2, 4 | 147 restaurants; 197 orders in month 1 to 320 in month 12; ~60 in month 0; +2.8% a month after month 3 | 01_slide4_growth_cohort.sql | Exact |
| 2, 5, 7 | App vs no-App over 12 months, restaurants still ordering: 42 launches, 58 comparison restaurants, gap +4 pts at +1 to +33 pts at +12 (153% vs 120%) | 02_slide5_app_vs_no_app.sql | Exact |
| 6, 12 | Guest value, first 180 days: Web 1.46 x $47.61 = $69.60; App 2.53 x ~$40.9 = ~$103.5 (+49%); 90 and 365-day checks | 03_slide6_guest_value.sql | Web values exact. Guest counts and App value within 0.5% of the slide (42,537 vs 42,647 App guests, $103.56 vs $103.52) |
| 10 | App launch groups: 17 / 130 / 55 / 18 / 75; in test 16 + 55 + 14 = 85 | 04_appendix_app_launch_groups.sql | Exact |
| 11, 7 | Expected-orders method (original 4-month, 85 launches): 216 / 242 / 277 orders, +15%, +$1,553 a month, $64K sizing | 05_appendix_expected_orders.sql | Within ~1 to 2%: re-run gives 216 / 242 / 280, +16%, +$1,532, $62.8K |
| 13, 8, 7 | 95 stopped restaurants; 58 / 19 / 13 / 5 stop patterns; 64% vs 80% launched the App; 41 active restaurants without the App | 06_appendix_stopped_restaurants.sql | Exact |
| 8 | 6,486 negative-GMV orders (0.43%); no duplicate order IDs; channel mix | 07_data_issues.sql | Exact |
| 4 (talk track) | Month-1 sources: gradual daily ramp, ~8% coupon share throughout, Google-tagged ~54% of month-1 orders, 173 guests at 1.19 orders | 08_month1_sources.sql | Exact |

## Not reproduced (original scripts were not kept)
- Slide 6 / 12: "Web guests who switched to the App ordered 54% more afterwards, vs 28%". The exact switcher definition wasn't saved.
- Slide 11: "About 45% of App orders are new (14.3 pts / 31.4%)". Re-run on the same basis gives about 40%. Same file as slide 11: 05_appendix_expected_orders.sql.
- Slide 8: catering (246 orders) and incomplete orders (468) counts. The exact flag rules weren't saved.
