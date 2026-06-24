🇷🇺 [Русская версия](README.md)

# E-commerce SQL Analysis (PostgreSQL)

12 business questions answered on an e-commerce database in pure SQL - from
basic aggregates to window functions. Goal: turn data into insights and
recommendations.

## Database
Normalized schema of 4 related tables:

```
| Table | Description | Rows |
|---|---|---|
| `customers` | customers: country, segment, signup date | 300 |
| `products` | products: category, price | 40 |
| `orders` | orders: date, status (completed / cancelled / returned) | 4,000 |
| `order_items` | order line items: quantity, price, discount | 10,049 |

Recreate the whole database with one script - [`build_db.sql`](build_db.sql).

## SQL techniques used
`JOIN` (multiple tables) · `GROUP BY` / `HAVING` · aggregates (`SUM`, `COUNT`) ·
`CTE` (`WITH`, multi-layer) · **window functions** (`LAG`, `RANK`, `ROW_NUMBER`,
`AVG`/`SUM` `OVER`) · filtering a window via a CTE · `PARTITION BY` ·
`WHERE` / `HAVING` · sorting · `LIMIT`.

## Business questions & findings
All queries are in [`queries.sql`](queries.sql).

| # | Question | Finding |
|---|---|---|
| 1 | Total revenue | 6.36M (gross, all line items) |
| 2 | Orders by status | ~19% cancelled/returned - lost revenue |
| 3 | Revenue by category | Electronics ≈ 47% of all revenue |
| 4 | Revenue by month | peaks in Nov–Dec (pre-holiday seasonality) |
| 5 | Top-10 customers | top customer ≈ 0.7% of revenue → no reliance on "whales" |
| 6 | Real revenue (completed only) | 5.12M; ~1.24M (20%) lost to cancellations |
| 7 | Month-over-month change | +315K in Nov, −167K in Jan |
| 8 | Product rank within category | electronics dominate |
| 9 | Category share of revenue | top-2 categories = 72% (concentration) |
| 10 | Loyal customers | many customers with 5+ orders — retention base |
| 11 | Top-3 products per category | sales leaders within each category |
| 12 | Products above category average | over-performers vs their category |


