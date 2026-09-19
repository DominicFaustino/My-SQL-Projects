/*
===============================================================================
SALES & CUSTOMER ANALYTICS
===============================================================================
Purpose:
    Exploratory analysis of sales, products, and customer behavior.

Database:
    SQL Server

Analysis Sections:
    1. Change-Over-Time Analysis
    2. Cumulative Analysis
    3. Product Performance Analysis
    4. Category Analysis
    5. Product Segmentation
    6. Customer Segmentation
    7. Customer Report
=============================================================================*/




/*=============================================================================
1. CHANGE-OVER-TIME ANALYSIS
===============================================================================
Purpose:
    Analyze sales, customers, and quantity sold over time.
=============================================================================*/


-- 1.1 Yearly Sales, Customers, and Quantity
select 
Year(order_date) AS Order_Year,
SUM(sales_amount) AS Total_Sales,
Count(DISTINCT customer_key) AS Total_Customers,
SUM(quantity) AS Total_Quantity
from gold.fact_sales
where order_date is not null 
group by Year(order_date)
order by Year(order_date)


-- 1.2 Monthly Seasonality
Select
Month(order_date) AS Monthly_Order,
SUM(sales_amount) AS Total_Sales,
Count(customer_key) AS Total_Customers,
SUM(quantity) AS Total_Quantity
from gold.fact_sales
where order_date is not null 
group by Month(order_date)
order by Month(order_date)


-- 1.3 Monthly Sales Performance per Year
Select
Year(order_date) AS Year_Order,
Month(order_date) AS Monthly_Order,
SUM(sales_amount) AS Total_Sales,
Count(DISTINCT customer_key) AS Total_Customers,
SUM(quantity) AS Total_Quantity
from gold.fact_sales
where order_date is not null
group by Year(order_date) , Month(order_date)
order by Year(order_date) , Month(order_date)

/*=============================================================================
2. CUMULATIVE ANALYSIS
===============================================================================
Purpose:
    Analyze sales accumulation and growth trends over time.
=============================================================================*/


-- 2.2 Running Total of Monthly Sales by Year
SELECT 
DATETRUNC(month, order_date) AS Month_Order,
SUM(sales_amount) As Total_Sales
From gold.fact_sales
where order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date) 
ORDER BY DATETRUNC(month, order_date) 

-- 2.3 Cumulative Sales Across Months
Select
Monthly_Order,
Total_Sales,
SUM(Total_Sales) OVER (PARTITION BY YEAR(Monthly_Order) ORDER BY Monthly_Order) AS Running_Total_Sales
FROM
	(
	SELECT 
	DATETRUNC(month, order_date) AS Monthly_Order,
	SUM(sales_amount) As Total_Sales
	FROM gold.fact_sales
	where order_date IS NOT NULL
	GROUP BY DATETRUNC(month, order_date)	
	) Monthly_Sales

-- 2.4 Cumulative Sales Across Years
Select
Yearly_Order,
Total_Sales,
SUM(Total_Sales) OVER ( ORDER BY Yearly_Order) AS Running_Total_Sales
FROM
	(
	SELECT 
	DATETRUNC(YEAR, order_date) AS Yearly_Order,
	SUM(sales_amount) As Total_Sales
	FROM gold.fact_sales
	where order_date IS NOT NULL
	GROUP BY DATETRUNC(YEAR, order_date)	
	) Yearly_Sales

/*=============================================================================
3. PRODUCT PERFORMANCE ANALYSIS
===============================================================================
Purpose:
    Analyze product sales performance and identify changes over time.
=============================================================================*/


-- 3.1 Yearly Sales Performance by Product
SELECT 
YEAR(sal.order_date) AS order_year,
pro.product_name,
SUM(sal.sales_amount) AS current_sales
FROM gold.fact_sales AS sal
JOIN gold.dim_products AS pro
ON sal.product_key = pro.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(sal.order_date),pro.product_name;


-- 3.2 Product Performance Compared to Historical Average
WITH Yearly_Product_Sales As 
(
SELECT 
YEAR(sal.order_date) AS order_year,
pro.product_name,
SUM(sal.sales_amount) AS current_sales
FROM gold.fact_sales AS sal
JOIN gold.dim_products AS pro
ON sal.product_key = pro.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(sal.order_date),pro.product_name
)
SELECT	
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'above avg' 
	 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'below avg' 
	 ELSE 'avg'
END AS avg_change,
-- Year-over-year Analysis -- 
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_year,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_year,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'rising' 
	 WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'decreasing' 
	 ELSE 'no change'
END AS py_change
FROM Yearly_Product_Sales
ORDER BY product_name, order_year

/*=============================================================================
4. CATEGORY ANALYSIS
===============================================================================
Purpose:
    Analyze how different product categories contribute to overall sales.
=============================================================================*/


-- 4.1 Sales Contribution by Category
WITH category_sales AS
(
SELECT 
category,
SUM(sales_amount) AS total_sales
From gold.dim_products AS pro
JOIN gold.fact_sales AS sal
	ON pro.product_key = sal.product_key
GROUP BY category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER() AS overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER())*100,2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC

/*=============================================================================
5. PRODUCT SEGMENTATION
===============================================================================
Purpose:
    Segment products based on their cost ranges.
=============================================================================*/


-- 5.1 Product Cost Segmentation
WITH product_segment AS (
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	 WHEN cost < 500 THEN '100-500'
	 WHEN cost <= 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT
cost_range,
COUNT(product_key) AS total_product
FROM product_segment
GROUP BY cost_range
ORDER BY total_product DESC

/*=============================================================================
6. CUSTOMER SEGMENTATION
===============================================================================
Purpose:
    Segment customers based on spending behavior and customer lifespan.
=============================================================================*/


-- 6.1 Customer Segmentation
WITH customer_spending AS (
SELECT 
cus.customer_key,
SUM(sal.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales AS sal
JOIN gold.dim_customers AS cus
	ON sal.customer_key = cus.customer_key
GROUP BY cus.customer_key)
-- 2nd CTE, creating customer segments -- 
,customer_segments AS (
SELECT 
customer_key,
total_spending,
lifespan,
CASE WHEN lifespan >= 12 AND total_spending >5000 THEN 'VIP'
	 WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment
FROM customer_spending)
-- Finding the total of customers per segment --
SELECT 
customer_segment,
COUNT(customer_key) AS total_customers
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_customers DESC



/*
=============================================================================
Customer Report
=============================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	1. Gather essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregate customer - level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products 
		- lifespan (in months)
	4. Calculate valueble KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
==============================================================================
*/

WITH base_query AS (
/*----------------------------------------------------------------------------
1) Basic Query: Retrieves core columns from tables
----------------------------------------------------------------------------*/
SELECT 
cus.customer_key,
cus.customer_number,
CONCAT(cus.first_name, ' ', cus.last_name) AS customer_name,
DATEDIFF(YEAR, cus.birthdate,GETDATE ()) AS age,
sal.order_number,
sal.product_key,
sal.order_date,
sal.sales_amount,
sal.quantity
FROM gold.dim_customers AS cus
JOIN gold.fact_sales AS sal
	ON cus.customer_key = sal.customer_key)
/*----------------------------------------------------------------------------
2) Customer Aggregation: Summarize key metrics at the customer level
----------------------------------------------------------------------------*/
, customer_aggregation AS (
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_product,
MAX(order_date) AS last_order_date,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY
	customer_key,
	customer_number,
	customer_name,
	age)

SELECT 
customer_key,
customer_number,
customer_name,
age,
CASE WHEN age < 20 THEN 'Under 20'
	 WHEN age BETWEEN 20 AND 29  THEN '20-29'
	 WHEN age BETWEEN 30 AND 39  THEN '30-39'
	 WHEN age BETWEEN 40 AND 49  THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE WHEN lifespan >= 12 AND total_sales >5000 THEN 'VIP'
	 WHEN lifespan >= 12 AND total_sales <=5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment,
last_order_date,
-- Compute recency --
DATEDIFF(MONTH, last_order_date, GETDATE ()) AS recency,
total_orders,
total_sales,
-- Compute average order value (AVO) --
CASE WHEN total_orders = 0 THEN 0
	 ELSE total_sales / total_orders
END AS avg_order_value,
total_quantity,
total_product,
lifespan,
-- Compute average monthly spend -- 
CASE WHEN lifespan = 0 THEN total_sales
	 ELSE total_sales / lifespan
END AS avg_monthly_spend
FROM customer_aggregation