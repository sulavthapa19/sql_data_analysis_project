/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report analyzes product performance using sales data from the Gold layer..

Highlights:
    1. Pulls core product details (name, category, subcategory, cost).
    2. Segments products by revenue (High-Performer, Mid-Range, Low-Performer).
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/

-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products
AS
WITH product_sales AS (
    /*---------------------------------------------------------------------------
    1) Product Sales: Get the main columns needed for the report
    ---------------------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales          AS sales_amount,
        f.sales_quantity AS quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_cost   AS cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL  -- only consider valid sales dates
),
product_aggregations AS (
    /*---------------------------------------------------------------------------
    2) Product Aggregations: Summarize metrics at the product level
    ---------------------------------------------------------------------------*/
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(
            AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),
            1
        ) AS avg_selling_price
    FROM product_sales
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

    /*---------------------------------------------------------------------------
    3) Final Output: Product report with segments and KPIs
    ---------------------------------------------------------------------------*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,

    -- KPI: Recency (months since last sale)
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,

    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,

    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,

    -- KPI: Average Order Revenue (AOR)
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales * 1.0 / total_orders
    END AS avg_order_revenue,

    -- KPI: Average Monthly Revenue
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales * 1.0 / lifespan
    END AS avg_monthly_revenue
FROM product_aggregations;
GO
