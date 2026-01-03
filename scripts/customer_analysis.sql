/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    This report creates a customer-level summary using Gold layer data.

What this report includes:
    - Basic customer details such as name and age.
    - Order and transaction information linked to each customer.
    - Customer grouping based on:
        * age range
        * customer type (VIP, Regular, New)
    - Customer metrics:
        * total orders
        * total sales
        * total quantity purchased
        * total products purchased
        * customer lifespan in months
    - Key KPIs:
        * recency (months since last order)
        * average order value
        * average monthly spend
Usage:
    Use this report for customer analysis, segmentation, and reporting.
===============================================================================
*/

CREATE VIEW gold.report_customers
AS
WITH customer_orders AS (
    /*---------------------------------------------------------------------------
    1) Customer Orders: Get the main columns needed for the report
    ---------------------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales               AS sales_amount,
        f.sales_quantity      AS quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birth_date, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_aggregation AS (
    /*---------------------------------------------------------------------------
    2) Customer Aggregation: Calculate customer totals and dates
    ---------------------------------------------------------------------------*/
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount)            AS total_sales,
        SUM(quantity)                AS total_quantity,
        COUNT(DISTINCT product_key)  AS total_products,
        MAX(order_date)              AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM customer_orders
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,

    -- KPI: Recency (months since the last order)
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,

    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,

    -- KPI: Average Order Value (AOV) = total_sales / total_orders
    CASE
        WHEN total_orders = 0 OR total_sales = 0 THEN 0
        ELSE total_sales * 1.0 / total_orders
    END AS avg_order_value,

    -- KPI: Average Monthly Spend = total_sales / lifespan (months)
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales * 1.0 / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;

