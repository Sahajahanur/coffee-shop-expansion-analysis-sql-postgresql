-- Monday Coffee -- Data Analysis 

SELECT * FROM city;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM sales;

-- Reports & Data Analysis

-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT 
   city_name,
   round((population*0.25)/1000000,2) AS coffee_consumers_in_million,
   city_rank 
FROM city
ORDER BY 2 DESC;


-- -- Q.2
-- Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?


SELECT 
	SUM(total) as total_revenue
FROM sales
WHERE 
	EXTRACT(YEAR FROM sale_date)  = 2023
	AND
	EXTRACT(quarter FROM sale_date) = 4;



SELECT 
	ci.city_name,
	SUM(s.total) as total_revenue
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON ci.city_id = c.city_id
WHERE 
	EXTRACT(YEAR FROM s.sale_date)  = 2023
	AND
	EXTRACT(quarter FROM s.sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC;


-- Q.3
-- Sales Count for Each Product
-- How many units of each coffee product have been sold?


SELECT 
	p.product_name,
	COUNT(s.sale_id) as total_orders
FROM products as p
LEFT JOIN
sales as s
ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC;


-- Q.4
-- Average Sales Amount per City
-- What is the average sales amount per customer in each city?

-- city and total sale
-- no cx in each these city

select
     ci.city_name,
	 sum(s.total) AS total_revenue,
	 count(distinct c.customer_id) as total_customer,

	 round(sum(s.total)::numeric/ count(distinct c.customer_id)::numeric,2) AS avg_sale_pr_cx
	 


FROM customers c
join city  ci
using (city_id)
join sales s
using (customer_id)

group by ci.city_name
order by sum(s.total) desc;


-- -- Q.5
-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)


WITH cte1 AS (
    SELECT
        city_name,
        ROUND((population * 0.25) / 1000000, 2) AS coffee_consumer_million
    FROM city
),

cte2 AS (
    SELECT
        ci.city_name,
        COUNT(DISTINCT c.customer_id)            AS unique_customer
    FROM       sales      AS s
    JOIN       customers  AS c  USING (customer_id)
    JOIN       city       AS ci USING (city_id)
    GROUP BY 1
)

SELECT
    c1.city_name,
    c1.coffee_consumer_million,
    c2.unique_customer
FROM      cte1 AS c1
JOIN      cte2 AS c2 USING (city_name);



-- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

with cte as (
SELECT 

    ci.city_name,
	p.product_name,
	count(s.sale_id) AS total_orders,
	dense_rank() over(partition by ci.city_name order by count(s.sale_id) desc) as rnk

FROM sales as s
JOIN products as p
USING (product_id)
JOIN customers as c
USING (customer_id)
JOIN city as ci
USING (city_id)
GROUP BY 1,2)

SELECT * FROM cte 
where rnk<=3;


-- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?


SELECT 
      ci.city_name,
	  count(DISTINCT c.customer_id) AS unique_cx

FROM  customers as c
JOIN city as ci
USING (city_id)
JOIN sales as s
ON s.customer_id = c.customer_id

WHERE 
  s.product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY 1
ORDER BY 2 DESC;
 

-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer


with cte1 AS (

select
     ci.city_name,
	 
	 count(distinct c.customer_id) as total_customer,

	 round(sum(s.total)::numeric/ count(distinct c.customer_id)::numeric,2) AS avg_sale_pr_cx
	 


FROM customers c
join city  ci
using (city_id)
join sales s
using (customer_id)

group by ci.city_name
order by sum(s.total) desc),

 cte2 as (
select city_name, estimated_rent  FROM city)


SELECT 
      c2.city_name, c2.estimated_rent,c1.total_customer, c1.avg_sale_pr_cx, round((c2.estimated_rent::numeric/c1.total_customer::numeric),2) AS avg_rent_per_cx
FROM cte2  as c2
JOIN cte1  as c1
using (city_name)
ORDER BY 4 DESC;



-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city
with cte1 as (
select 
    ci.city_name,
	extract(month from sale_date) as month,
	extract(year from sale_date) as year,
	sum(s.total) as total_sale

FROM sales as s 

join customers as c 
using (customer_id)
join city as ci 
using (city_id)
group by 1,2,3
order by 1,3,2),

cte2 as(
select 
     city_name,
	 month,
	 year,
	 total_sale as current_month_sale,
	 LAG(total_sale,1) over(partition by city_name order by year, month) as last_month_sale
	 from cte1)

select *,

     round((current_month_sale-last_month_sale)::numeric/last_month_sale::numeric*100,2) as growth_ratio

from cte2	 
	 where last_month_sale is not null;


-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer


WITH cte1 AS (
    SELECT
        ci.city_name,
        SUM(s.total)                                                               AS total_revenue,
        COUNT(DISTINCT c.customer_id)                                              AS total_customer,
        ROUND(
            SUM(s.total)::NUMERIC / COUNT(DISTINCT c.customer_id)::NUMERIC
        , 2)                                                                       AS avg_sale_pr_cx
    FROM       customers  AS c
    JOIN       city       AS ci  USING (city_id)
    JOIN       sales      AS s   USING (customer_id)
    GROUP BY   ci.city_name
    ORDER BY   SUM(s.total) DESC
),

cte2 AS (
    SELECT
        city_name,
        estimated_rent,
        ROUND(population * 0.25 / 1000000, 2)                                     AS est_coffee_consumer_million
    FROM city
)

SELECT
    c2.city_name,
    c1.total_revenue,
    c2.estimated_rent                                                              AS total_rent,
    c2.est_coffee_consumer_million,
    c1.total_customer,
    c1.avg_sale_pr_cx,
    ROUND(c2.estimated_rent::NUMERIC / c1.total_customer::NUMERIC, 2)             AS avg_rent_per_cx
FROM       cte2  AS c2
JOIN       cte1  AS c1  USING (city_name)
ORDER BY   c1.total_revenue DESC;


-- =====================================================
-- ADDITIONAL CHECKS (data quality + supporting metrics)
-- =====================================================

-- Data quality: null rows in key columns (expected: 0)
SELECT COUNT(*) AS null_rows
FROM sales
WHERE sale_id IS NULL OR sale_date IS NULL OR product_id IS NULL
   OR customer_id IS NULL OR total IS NULL;

-- Data quality: duplicate sale_ids (expected: no rows)
SELECT sale_id, COUNT(*)
FROM sales
GROUP BY 1
HAVING COUNT(*) > 1;

-- Data quality: sales without a matching customer (expected: 0)
SELECT COUNT(*) AS orphan_sales
FROM sales s
LEFT JOIN customers c USING (customer_id)
WHERE c.customer_id IS NULL;

-- Average rating by city
SELECT ci.city_name, ROUND(AVG(s.rating), 2) AS avg_rating
FROM sales s
JOIN customers c USING (customer_id)
JOIN city ci USING (city_id)
GROUP BY 1
ORDER BY 2 DESC;

-- Orders per customer by city
SELECT ci.city_name,
       ROUND(COUNT(s.sale_id)::NUMERIC / COUNT(DISTINCT c.customer_id), 1) AS orders_per_cx
FROM sales s
JOIN customers c USING (customer_id)
JOIN city ci USING (city_id)
GROUP BY 1
ORDER BY 2 DESC;

-- Revenue per Rs 1 of estimated rent
SELECT ci.city_name,
       ROUND(SUM(s.total)::NUMERIC / ci.estimated_rent, 1) AS revenue_per_rent
FROM sales s
JOIN customers c USING (customer_id)
JOIN city ci USING (city_id)
GROUP BY ci.city_name, ci.estimated_rent
ORDER BY 2 DESC;


/*
-- Recommendation
City 1: Pune
	1.Average rent per customer is very low.
	2.Highest total revenue.
	3.Average sales per customer is also high.

City 2: Delhi
	1.Highest estimated coffee consumers at 7.75 million.
	2.Second-highest number of customers, which is 68.
	3.Average rent per customer is 330.88 (still under 500).

City 3: Jaipur
	1.Highest number of customers, which is 69.
	2.Lowest average rent per customer at 156.52.
	3.Average sales per customer is 11.6k.
*/
