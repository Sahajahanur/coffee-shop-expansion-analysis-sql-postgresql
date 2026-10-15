# ☕ Monday Coffee Expansion — SQL Market Analysis

<img width="1606" height="906" alt="image" src="https://github.com/user-attachments/assets/3ef71c04-a71f-4088-8940-3e8135f418ad" />


**Which 3 of 14 Indian cities should Monday Coffee open its first physical stores in? A PostgreSQL analysis of 10,388 online orders recommends Pune, Delhi and Jaipur.**

---

## Table of Contents

- [Project at a Glance](#project-at-a-glance)
- [Overview](#overview)
- [Business Problem](#business-problem)
- [Dataset](#dataset)
- [Tools & Methods](#tools--methods)
- [Business Questions, SQL & Answers](#business-questions-sql--answers)
- [Additional Checks](#additional-checks)
- [Key Insights](#key-insights)
- [Recommendation](#recommendation)
- [KPI & Expected Impact](#kpi--expected-impact)
- [How to Run This Project](#how-to-run-this-project)
- [Limitations](#limitations)
- [Future Work](#future-work)
- [Author & Contact](#author--contact)

---

## Project at a Glance

| # | Question | Answer |
|---|----------|--------|
| 1 | **Business problem** | Pick the 3 best cities for new coffee shops, balancing revenue, market size and rent |
| 2 | **Tools & methods** | PostgreSQL · multi-table joins · CTEs · window functions (`DENSE_RANK`, `LAG`) · data-quality checks |
| 3 | **Insights** | Pune earns the most from the smallest market; Delhi is the biggest market but still under-penetrated; Jaipur is the cheapest to operate |
| 4 | **Recommendation** | 🥇 Pune · 🥈 Delhi · 🥉 Jaipur |
| 5 | **KPI affected** | Revenue per ₹ of rent, customer penetration |
| 6 | **Impact** | Not forecast (no store cost data). Measured benchmark: Pune earns **82×** and Jaipur **74×** their estimated rent in revenue, vs **7.5×** in Mumbai |

---

## Overview

Monday Coffee has sold coffee products online since January 2023. This project uses its sales, customer, product and city data to decide where to open physical outlets. Ten business questions are answered in SQL, then combined into a ranked city recommendation.

---

## Business Problem

Opening a store in the wrong city is expensive. Monday Coffee needs to know **where demand is already proven, where the market is large enough to grow, and where rent will not eat the margin.**

---

## Dataset

| Table | Rows | Description |
|-------|-----:|-------------|
| `city` | 14 | City name, population, estimated rent, city rank |
| `products` | 28 | Coffee products and merchandise with list price (₹200–₹1,800) |
| `customers` | 497 | Customers linked to a city |
| `sales` | 10,388 | One row per order: date, product, customer, total (₹), rating |

- **Period:** 1 Jan 2023 – 1 Oct 2024
- **Total revenue:** ₹6,070,190 (₹60.7 lakh) · **Cities:** 14 · **Average rating:** 3.99 / 5
- CSV files are included in [`data/`](data/).

---

## Tools & Methods

**Tools:** PostgreSQL, SQL

**Steps**
1. **Validated the data** (10,388 orders, 497 customers, 14 cities, 28 products). No nulls, duplicate `sale_id`s or orphan keys; every customer has at least one order. Every order has quantity 1 (`total` = list price), so order count = units sold. The checks are in [Additional Checks](#additional-checks).
2. **Joined** `sales → customers → city` to attach every order to a city.
3. **Built city metrics** with CTEs: revenue, customers, average sale per customer, rent per customer, estimated coffee consumers.
4. **Ranked and compared** with window functions (`DENSE_RANK` for top products per city, `LAG` for month-over-month growth).
5. **Combined the metrics** to shortlist the top 3 cities.

**Assumptions**
- 25% of each city's population drinks coffee (given in the brief).
- `estimated_rent` is the city-level cost of a new outlet; the period is not specified in the data.
- Online sales are a proxy for offline demand.
- Rent per customer under ₹500 is treated as acceptable (analyst screening threshold).

**Excluded / handled**
- Revenue is not profit: the data has no cost or margin.
- October 2024 has only 8 orders (1 day), so its month-over-month growth is not meaningful and is ignored.

---

## Business Questions, SQL & Answers

Full script: [`coffee_project.sql`](coffee_project.sql)

### Q1. Coffee Consumers Count
**Business question:** How many people in each city are estimated to consume coffee, given that 25% of the population does?

```sql
SELECT 
   city_name,
   ROUND((population * 0.25) / 1000000, 2) AS coffee_consumers_in_million,
   city_rank 
FROM city
ORDER BY 2 DESC;
```

> **Answer:** Delhi has the largest estimated coffee-consumer base (7.75M), followed by Mumbai (5.10M) and Kolkata (3.73M). Pune has only 1.88M and Jaipur 1.00M.

---

### Q2. Total Revenue from Coffee Sales
**Business question:** What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

```sql
-- Overall Revenue
SELECT 
    SUM(total) AS total_revenue
FROM sales
WHERE 
    EXTRACT(YEAR FROM sale_date) = 2023
    AND EXTRACT(QUARTER FROM sale_date) = 4;

-- Revenue by City
SELECT 
    ci.city_name,
    SUM(s.total) AS total_revenue
FROM sales AS s
JOIN customers AS c ON s.customer_id = c.customer_id
JOIN city AS ci ON ci.city_id = c.city_id
WHERE 
    EXTRACT(YEAR FROM s.sale_date) = 2023
    AND EXTRACT(QUARTER FROM s.sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC;
```

> **Answer:** Q4 2023 revenue was **₹1,963,300** (32.3% of all revenue). Pune led with ₹434,330, followed by Chennai (₹302,500), Bangalore (₹270,780), Jaipur (₹248,580) and Delhi (₹238,490).

---

### Q3. Sales Count for Each Product
**Business question:** How many units of each coffee product have been sold?

```sql
SELECT 
    p.product_name,
    COUNT(s.sale_id) AS total_orders
FROM products AS p
LEFT JOIN sales AS s ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC;
```

> **Answer:** Four products dominate: Cold Brew Pack (1,326 orders), Ground Espresso (1,271), Instant Coffee (1,226) and Coffee Beans (1,218). Together they are 48.5% of orders and 44.1% of revenue. The 12 slowest products sell 73–96 orders each (about 8% of revenue together), so the menu can be trimmed.

---

### Q4. Average Sales Amount per City
**Business question:** What is the average sales amount per customer in each city?

```sql
SELECT
    ci.city_name,
    SUM(s.total) AS total_revenue,
    COUNT(DISTINCT c.customer_id) AS total_customer,
    ROUND(SUM(s.total)::NUMERIC / COUNT(DISTINCT c.customer_id)::NUMERIC, 2) AS avg_sale_pr_cx
FROM customers AS c
JOIN city AS ci USING (city_id)
JOIN sales AS s USING (customer_id)
GROUP BY ci.city_name
ORDER BY SUM(s.total) DESC;
```

> **Answer:** Pune has the highest spend per customer (₹24,198), followed by Chennai (₹22,479) and Bangalore (₹22,054). Jaipur (₹11,644) and Delhi (₹11,036) are about half of that. The average *order* is ₹554–₹612 in every city, so the gap comes from how often customers buy: 41 orders per customer in Pune vs 20 in Jaipur and 19 in Delhi.

---

### Q5. City Population and Coffee Consumers (25%)
**Business question:** Provide a list of cities along with their populations and estimated coffee consumers. Return city name, total current customers, and estimated coffee consumers (25%).

```sql
WITH cte1 AS (
    SELECT
        city_name,
        ROUND((population * 0.25) / 1000000, 2) AS coffee_consumer_million
    FROM city
),
cte2 AS (
    SELECT
        ci.city_name,
        COUNT(DISTINCT c.customer_id) AS unique_customer
    FROM sales AS s
    JOIN customers AS c USING (customer_id)
    JOIN city AS ci USING (city_id)
    GROUP BY 1
)
SELECT
    c1.city_name,
    c1.coffee_consumer_million,
    c2.unique_customer
FROM cte1 AS c1
JOIN cte2 AS c2 USING (city_name);
```

> **Answer:** The biggest markets are the least tapped. Delhi has 68 customers for 7.75M estimated consumers (about 9 per million), Mumbai 27 for 5.10M (about 5 per million) and Kolkata 28 for 3.73M. Jaipur, in contrast, has 69 customers for 1.00M (about 69 per million).

---

### Q6. Top Selling Products by City
**Business question:** What are the top 3 selling products in each city based on sales volume?

```sql
WITH cte AS (
    SELECT 
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders,
        DENSE_RANK() OVER (
            PARTITION BY ci.city_name 
            ORDER BY COUNT(s.sale_id) DESC
        ) AS rnk
    FROM sales AS s
    JOIN products AS p USING (product_id)
    JOIN customers AS c USING (customer_id)
    JOIN city AS ci USING (city_id)
    GROUP BY 1, 2
)
SELECT * FROM cte
WHERE rnk <= 3;
```

> **Answer:** Only four products ever appear in a city's top 3: Cold Brew Pack (top 3 in 13 of 14 cities, #1 in 6), Instant Coffee (11 cities), Ground Espresso (11) and Coffee Beans (10). These are universal bestsellers, so a standard core menu works in every new store.

---

### Q7. Customer Segmentation by City
**Business question:** How many unique customers are there in each city who have purchased coffee products?

```sql
SELECT 
    ci.city_name,
    COUNT(DISTINCT c.customer_id) AS unique_cx
FROM customers AS c
JOIN city AS ci USING (city_id)
JOIN sales AS s ON s.customer_id = c.customer_id
WHERE s.product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY 1
ORDER BY 2 DESC;
```

> **Answer:** Jaipur has the most coffee buyers (69), followed by Delhi (68), Pune (52), Chennai (42) and Bangalore (39). Product IDs 1–14 are the coffee products; 15–28 are merchandise.

---

### Q8. Average Sale vs Rent
**Business question:** Find each city and their average sale per customer and average rent per customer.

```sql
WITH cte1 AS (
    SELECT
        ci.city_name,
        COUNT(DISTINCT c.customer_id) AS total_customer,
        ROUND(SUM(s.total)::NUMERIC / COUNT(DISTINCT c.customer_id)::NUMERIC, 2) AS avg_sale_pr_cx
    FROM customers AS c
    JOIN city AS ci USING (city_id)
    JOIN sales AS s USING (customer_id)
    GROUP BY ci.city_name
    ORDER BY SUM(s.total) DESC
),
cte2 AS (
    SELECT city_name, estimated_rent FROM city
)
SELECT 
    c2.city_name,
    c2.estimated_rent,
    c1.total_customer,
    c1.avg_sale_pr_cx,
    ROUND(c2.estimated_rent::NUMERIC / c1.total_customer::NUMERIC, 2) AS avg_rent_per_cx
FROM cte2 AS c2
JOIN cte1 AS c1 USING (city_name)
ORDER BY 4 DESC;
```

> **Answer:** Rent per customer is lowest in Jaipur (₹156.52), Kanpur (₹231.43) and Pune (₹294.23); Delhi is ₹330.88. It is highest in Mumbai (₹1,166.67), Hyderabad (₹1,071.43) and Bangalore (₹761.54). Pune (82×) and Jaipur (74×) earn the most revenue per ₹1 of estimated rent, vs 33× in Delhi.

---

### Q9. Monthly Sales Growth
**Business question:** Calculate the percentage growth (or decline) in sales month-over-month by each city.

```sql
WITH cte1 AS (
    SELECT 
        ci.city_name,
        EXTRACT(MONTH FROM sale_date) AS month,
        EXTRACT(YEAR FROM sale_date) AS year,
        SUM(s.total) AS total_sale
    FROM sales AS s
    JOIN customers AS c USING (customer_id)
    JOIN city AS ci USING (city_id)
    GROUP BY 1, 2, 3
    ORDER BY 1, 3, 2
),
cte2 AS (
    SELECT 
        city_name,
        month,
        year,
        total_sale AS current_month_sale,
        LAG(total_sale, 1) OVER (
            PARTITION BY city_name 
            ORDER BY year, month
        ) AS last_month_sale
    FROM cte1
)
SELECT *,
    ROUND(
        (current_month_sale - last_month_sale)::NUMERIC / last_month_sale::NUMERIC * 100,
    2) AS growth_ratio
FROM cte2
WHERE last_month_sale IS NOT NULL;
```

> **Answer:** Growth is not steady. Across all cities, sales jumped 169% from Aug to Sep 2023 and stayed high until Mar 2024 (peak: Nov 2023, ₹709,200), then fell 75% in Apr 2024. Seven months (Sep 2023–Mar 2024) produced 61.5% of all revenue. In each city the median month-over-month change is close to zero (−10% to +11%). Ignore the Oct 2024 rows: that month has only 8 orders.

---

### Q10. Market Potential Analysis
**Business question:** Identify the top 3 cities based on highest sales. Return city name, total sale, total rent, total customers, estimated coffee consumers.

```sql
WITH cte1 AS (
    SELECT
        ci.city_name,
        SUM(s.total) AS total_revenue,
        COUNT(DISTINCT c.customer_id) AS total_customer,
        ROUND(
            SUM(s.total)::NUMERIC / COUNT(DISTINCT c.customer_id)::NUMERIC
        , 2) AS avg_sale_pr_cx
    FROM customers AS c
    JOIN city AS ci USING (city_id)
    JOIN sales AS s USING (customer_id)
    GROUP BY ci.city_name
    ORDER BY SUM(s.total) DESC
),
cte2 AS (
    SELECT
        city_name,
        estimated_rent,
        ROUND(population * 0.25 / 1000000, 2) AS est_coffee_consumer_million
    FROM city
)
SELECT
    c2.city_name,
    c1.total_revenue,
    c2.estimated_rent AS total_rent,
    c2.est_coffee_consumer_million,
    c1.total_customer,
    c1.avg_sale_pr_cx,
    ROUND(c2.estimated_rent::NUMERIC / c1.total_customer::NUMERIC, 2) AS avg_rent_per_cx
FROM cte2 AS c2
JOIN cte1 AS c1 USING (city_name)
ORDER BY c1.total_revenue DESC;
```

| City | Revenue (₹) | Rent (₹) | Est. consumers (M) | Customers | Avg sale / customer (₹) | Rent / customer (₹) |
|------|------------:|---------:|-------------------:|----------:|------------------------:|--------------------:|
| Pune | 1,258,290 | 15,300 | 1.88 | 52 | 24,197.88 | 294.23 |
| Chennai | 944,120 | 17,100 | 2.77 | 42 | 22,479.05 | 407.14 |
| Bangalore | 860,110 | 29,700 | 3.08 | 39 | 22,054.10 | 761.54 |
| Jaipur | 803,450 | 10,800 | 1.00 | 69 | 11,644.20 | 156.52 |
| Delhi | 750,420 | 22,500 | 7.75 | 68 | 11,035.59 | 330.88 |

> **Answer:** By revenue alone the top 3 are Pune, Chennai and Bangalore. Bangalore fails the ₹500 rent-per-customer screen (₹762). Delhi (largest market, 68 customers) and Jaipur (most customers, lowest rent) add what revenue alone misses, so the shortlist is **Pune, Delhi and Jaipur**, with Chennai as the first alternate.

---

## Additional Checks

Data-quality checks and supporting metrics used in this README (also in [`coffee_project.sql`](coffee_project.sql)).

```sql
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
```

| City | Avg rating | Orders per customer | Revenue per ₹1 rent |
|------|-----------:|--------------------:|--------------------:|
| Pune | 4.47 | 41.1 | 82.2× |
| Chennai | 4.52 | 38.1 | 55.2× |
| Bangalore | 4.48 | 37.5 | 29.0× |
| Jaipur | 3.51 | 20.0 | 74.4× |
| Delhi | 3.51 | 19.2 | 33.4× |
| Mumbai | 3.45 | 15.7 | 7.5× |

> **Result:** The three quality checks return 0 null rows, no duplicate `sale_id`s and 0 orphan sales. Pune, Chennai and Bangalore are rated about 4.5, while most other cities (including Delhi and Jaipur) are around 3.5.

---

## Key Insights

1. **Market size is not the same as sales.** Delhi has the largest estimated consumer base (7.75M) but ranks 5th in revenue. Pune has only 1.88M and ranks 1st with ₹1,258,290.
2. **Sales are concentrated.** Five cities (Pune, Chennai, Bangalore, Jaipur, Delhi) generate 76.1% of revenue.
3. **Frequency, not basket size, drives spend.** The average order is ₹554–₹612 everywhere, but Pune customers order 41 times vs 19–20 in Delhi and Jaipur.
4. **Rent changes the picture.** Jaipur (₹157) and Pune (₹294) are cheap per customer; Bangalore (₹762), Hyderabad (₹1,071) and Mumbai (₹1,167) are expensive.
5. **Demand is volatile.** One surge (Sep 2023) and one drop (Apr 2024) shape the dataset; the cause is not in the data.
6. **Delhi and Jaipur have lower ratings** (3.51) than Pune, Chennai and Bangalore (about 4.5), so service quality needs a check before launch.

---

## Recommendation

Based on the Q10 Market Potential Analysis, the top 3 recommended cities for expansion are:

### 🥇 Pune
1. Highest total revenue (₹1,258,290) and highest in Q4 2023 (₹434,330)
2. Highest average sale per customer (₹24,198)
3. Average rent per customer is low (₹294), and the rating is high (4.47)

### 🥈 Delhi
1. Highest estimated coffee consumers at **7.75 million**, with the most room to grow
2. Second-highest number of customers (68)
3. Average rent per customer is ₹331 (under the ₹500 screen)

### 🥉 Jaipur
1. Highest number of customers (69)
2. Lowest average rent per customer (₹157)
3. 74× revenue per ₹1 of estimated rent

**Actions for the business**
- Open the first store in **Pune**, where demand is proven.
- Launch every new store with the **four core products** first (Cold Brew Pack, Ground Espresso, Instant Coffee, Coffee Beans), then add slower items only if local demand supports them.
- **Review the 3.5 ratings** in Delhi and Jaipur before launch.
- Plan stock and staffing for **demand swings**, not steady growth.

**Watch-out:** Delhi's case rests on market size, not current sales (5th in revenue, 33× revenue per ₹ of rent). **Chennai** is the strongest alternate: 2nd in revenue (₹944,120), rent per customer ₹407, rating 4.52, but a smaller market (2.77M estimated consumers).

---

## KPI & Expected Impact

**KPIs this analysis targets:** revenue per ₹ of rent and customer penetration (customers per million estimated consumers).

**Measured on historical online sales (not forecast)**

| City | Revenue per ₹1 of estimated rent |
|------|-------------------------------:|
| Pune | 82× |
| Jaipur | 74× |
| Delhi | 33× |
| Mumbai | 7.5× |
| Hyderabad | 5.8× |

The three recommended cities generated **46.3% of revenue from 38.0% of customers**.

**Not quantified:** the expected uplift from opening stores. The data has no store costs, margins or pilot results, so any impact figure would be a guess.

---

## How to Run This Project

**Project structure**

```
monday-coffee-expansion-sql-postgresql/
├── data/
│   ├── city.csv
│   ├── customers.csv
│   ├── products.csv
│   └── sales.csv
├── coffee_project.sql    # 10 analysis queries + additional checks
└── README.md
```

**Steps**

1. Clone the repository:
   ```bash
   git clone https://github.com/Sahajahanur/Monday-Coffee-Expansion-SQL-Project.git
   ```
2. In PostgreSQL, create the database and tables:
   ```sql
   CREATE TABLE city (
       city_id INT PRIMARY KEY, city_name VARCHAR(50),
       population INT, estimated_rent INT, city_rank INT
   );
   CREATE TABLE products (
       product_id INT PRIMARY KEY, product_name VARCHAR(100), price INT
   );
   CREATE TABLE customers (
       customer_id INT PRIMARY KEY, customer_name VARCHAR(100),
       city_id INT REFERENCES city(city_id)
   );
   CREATE TABLE sales (
       sale_id INT PRIMARY KEY, sale_date DATE,
       product_id INT REFERENCES products(product_id),
       customer_id INT REFERENCES customers(customer_id),
       total INT, rating INT
   );
   ```
3. Import the CSVs from `data/` in this order: `city`, `products`, `customers`, `sales` (pgAdmin Import/Export, or `\copy`).
4. Run `coffee_project.sql` query by query.

**SQL concepts used:** `JOIN` (inner, left), `SUM` / `COUNT` / `ROUND`, `EXTRACT`, `DENSE_RANK`, `LAG`, CTEs, `::NUMERIC` casting.

---

## Limitations

- Online sales may not match walk-in store demand.
- 497 customers is a small sample, so city-level counts can shift with a few customers.
- Revenue, not profit: there is no cost or margin data.
- The cause of the Sep 2023 surge and Apr 2024 drop is not in the data.

---

## Future Work

- Add a weighted city score (revenue, rent efficiency, market size, rating) so the ranking is fully data-driven.
- Exclude partial months (Oct 2024) from the growth query (Q9).
- Add cost and margin data to move from revenue to profit.
- Build a Power BI dashboard for the city comparison.
- Investigate the Sep 2023 surge and Apr 2024 drop (campaigns, pricing, stock).

---

## Author & Contact

**Sahajahanur Rahman Laskar**

- 📧 Email: connectingsrl@gmail.com
- 💼 LinkedIn: [linkedin.com/in/sahajahanur-laskar](https://www.linkedin.com/in/sahajahanur-laskar/)
- 🐙 GitHub: [github.com/Sahajahanur](https://github.com/Sahajahanur)
