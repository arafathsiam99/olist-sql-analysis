# Olist E-Commerce: SQL Data Quality Audit and Analysis

SQL project on the public [Brazilian E-Commerce dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(9 related tables, about 100K orders), built in PostgreSQL. It has two parts:

1. A **data quality audit** that looks for missing, inconsistent and duplicate records.
2. **Analysis queries** using window functions, CTEs (including recursive) and
   `ROLLUP` / `CUBE` / `GROUPING SETS`.

## Tools

PostgreSQL 18, pgAdmin 4, SQL

## Repository contents

| File | Purpose |
|---|---|
| `schema.sql` | Creates the 9 tables |
| `01_data_quality_audit.sql` | Validation checks (missing dates, orphans, duplicates, mismatches) |
| `02_window_functions.sql` | `ROW_NUMBER`, `RANK`, `LAG`, `LEAD`, `NTILE`, running totals and moving averages |
| `03_ctes.sql` | Multi-step CTEs and recursive CTEs |
| `04_rollup_cube.sql` | `ROLLUP`, `CUBE`, `GROUPING SETS` |

## How to reproduce

1. Download the dataset from Kaggle (the CSV files are not stored in this repo).
2. Create a database and run `schema.sql`.
3. Import each CSV into the table with the matching name
   (pgAdmin: right-click the table, Import/Export Data, header on).
4. Run the numbered `.sql` files in order.

## Data quality audit findings

| Check | Result |
|---|---|
| Orders marked `delivered` with no delivery date | 8 |
| Delivery date earlier than purchase date | 0 |
| Order items with no matching order | 0 |
| Orders with no items | 775 (about 0.78%) |
| Delivered orders with no payment record | 1 |
| Repeated `review_id` values in `order_reviews` | 814 extra rows |
| Orders that received more than one review | 551 extra rows |

**Orders with no items (775):** 603 are `unavailable` and 164 are `canceled`, which is
expected (767 of 775, about 99%). The remaining 8 (5 `created`, 2 `invoiced`,
1 `shipped`) are worth manual review, especially the shipped order, because an
order cannot ship without items.

**Reviews:** `review_id` is not unique in the source file, so it cannot be used as a
primary key. Duplicates should be resolved with `ROW_NUMBER()` before analysis
(see `02_window_functions.sql`).

### Recommended fixes

- Add a validation rule that a `delivered` order must have a delivery date and at
  least one payment record.
- Flag `shipped` orders with no items for manual review.
- Deduplicate reviews by keeping the latest answer per order.

## Notes

- Data source: Olist public dataset (Kaggle). All rights belong to the original publisher.
- Some mismatches between paid amount and item totals can be legitimate
  (vouchers, installments), so they were reviewed before being treated as errors.
