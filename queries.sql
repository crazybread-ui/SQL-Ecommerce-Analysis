-- ============================================================
-- E-commerce SQL analysis — business questions
-- Database: PostgreSQL. Run build_db.sql first to create & load.
-- Tables: customers, products, orders, order_items
-- ============================================================

-- Q1. Total revenue (gross — across all order items)
SELECT SUM(quantity * unit_price * (1 - discount)) AS total_revenue
FROM order_items;
-- → 6 359 161  (total gross revenue)


-- Q2. Orders by status (how much work actually completes)
SELECT status, COUNT(*) AS orders
FROM orders
GROUP BY status;
-- → completed 3224, cancelled 412, returned 364  (~19% don't complete — lost revenue)


-- Q3. Revenue by product category (JOIN order_items + products)
SELECT p.category,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
FROM order_items AS oi
JOIN products AS p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;
-- → Electronics 3.01M, Sports 1.57M, Home 1.19M, Toys 0.45M, Books 0.14M
--   Electronics ≈ 47% of revenue — heavily skewed to expensive electronics.


-- Q4. Revenue by month (JOIN orders + order_items, TO_CHAR for month)
SELECT TO_CHAR(o.order_date, 'YYYY-MM') AS month,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY month
ORDER BY revenue DESC;   -- sorted by revenue so the seasonal spikes surface at the top
-- → Top 4 months are Nov & Dec of BOTH years (525K, 466K, 434K, 408K) — strong pre-holiday seasonality.


-- Q5. Top-10 customers by total revenue (2 JOINs + LIMIT)
SELECT c.customer_id, c.name, c.country,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total_spent
FROM order_items AS oi
JOIN orders    AS o ON oi.order_id   = o.order_id
JOIN customers AS c ON c.customer_id = o.customer_id
GROUP BY c.customer_id          -- customer_id is the PK, so Postgres allows selecting name/country too
ORDER BY total_spent DESC
LIMIT 10;
-- → top customer ~44.7K (≈0.7% of total) across Brazil/USA/France/India/Germany — revenue not concentrated in a few whales.


-- Q6. Real revenue — completed orders only (WHERE on joined orders.status)
SELECT SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue_completed
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.status = 'completed';
-- → 5 116 825 vs gross 6 359 161 → ~1.24M (≈20%) lost to cancelled/returned (matches the ~19% of orders in Q2).


-- Q7. Month-over-month revenue change (CTE + LAG window function)
WITH monthly AS (
    SELECT TO_CHAR(o.order_date, 'YYYY-MM') AS month,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items AS oi
    JOIN orders AS o ON oi.order_id = o.order_id
    GROUP BY month
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       revenue - LAG(revenue) OVER (ORDER BY month) AS mom_change
FROM monthly
ORDER BY month;
-- → biggest jump +315K into Nov 2024 (holiday ramp); biggest drop -167K in Jan 2025 (post-holiday crash).


-- Q8. Product revenue rank within each category (CTE + RANK + PARTITION BY)
WITH product_rev AS (
    SELECT p.category, p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.product_id
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, revenue,
       RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
FROM product_rev
ORDER BY category, rank_in_category;
-- → ranks products inside each category; Electronics #1 ≈ 823K vs Books #1 ≈ 41K — electronics products dwarf the rest.


-- Q9. Each category's share of total revenue (% — window SUM over the whole table)
WITH category_rev AS (
    SELECT p.category,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.product_id
    GROUP BY p.category
)
SELECT category,
       revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total
FROM category_rev
ORDER BY revenue DESC;
-- → Electronics 47.3%, Sports 24.7%, Home 18.7%, Toys 7.0%, Books 2.2%. Top-2 categories ≈ 72% of revenue (concentration risk).


-- Q10. Loyal customers — 5+ orders (HAVING filters on the aggregate, not WHERE)
SELECT c.customer_id, c.name, COUNT(*) AS order_count
FROM customers AS c
JOIN orders AS o ON c.customer_id = o.customer_id
GROUP BY c.customer_id          -- PK → name allowed without listing it
HAVING COUNT(*) >= 5
ORDER BY order_count DESC;
-- → many loyal customers (top ~23 orders) — solid repeat-purchase base.
-- Note: WHERE filters rows BEFORE grouping; HAVING filters groups AFTER aggregation.


-- Q11. Top 3 products per category (ROW_NUMBER + filter the window in an outer query)
WITH product_rev AS (
    SELECT p.category,
           p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue,
           ROW_NUMBER() OVER (
               PARTITION BY p.category
               ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) DESC
           ) AS rn
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.product_id
    GROUP BY p.product_id
)
SELECT category, product_name, revenue, rn
FROM product_rev
WHERE rn <= 3
ORDER BY category, rn;
-- → top 3 products per category. Key: a window function can't be filtered in WHERE → compute it in a CTE, filter outside.


-- Q12. Products above their category's average revenue (window AVG as baseline + wrap-and-filter)
WITH product_rev AS (                       -- layer 1: revenue per product (SUM once)
    SELECT p.category, p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.product_id
    GROUP BY p.product_id
),
with_avg AS (                               -- layer 2: attach category average via window (no nesting)
    SELECT category, product_name, revenue,
           AVG(revenue) OVER (PARTITION BY category) AS category_avg
    FROM product_rev
)
SELECT category, product_name, revenue, category_avg,   -- layer 3: filter on the window result
       revenue - category_avg AS diff
FROM with_avg
WHERE revenue > category_avg
ORDER BY category, revenue DESC;
-- → only products beating their category average. Rule: never nest aggregates (AGG(AGG())) — SUM in one layer, AVG OVER in the next.
