-- Test Questions:
-- *please exclude tips unless specify otherwise

-- Q-1: What are the top 10 sub categories by revenue?
SELECT 
	sc_id,
	SUM(amount) as total_amount
FROM orders
WHERE is_tip = 0
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

--Q-2: What are the top 5 sub categories by SPB and OPB (SPB = spend per buyer, OPB = orders per buyer)
SELECT 
	sc_id,
	SUM(amount) / COUNT(DISTINCT buyer_id) as SPB,
	ROUND(COUNT(DISTINCT order_id) / COUNT(DISTINCT buyer_id), 2) as OPB
FROM orders
WHERE is_tip = 0
GROUP BY 1
ORDER BY 2,3
LIMIT 5;

-- Q-3: What is our avg daily revenue and avg number of orders? 
WITH daily_activity AS(
	SELECT 
		date,
		amount,
		SUM(amount) OVER func_window  as daily_revenue,
		COUNT(order_id) OVER func_window as daily_orders
	FROM orders
	WHERE is_tip = 0
	WINDOW func_window as (PARTITION BY date)
)
SELECT 
	AVG(daily_revenue) as avg_daily_revenue,
	AVG(daily_orders) as avg_daily_orders
FROM daily_activity;

-- Q-4: How much daily revenue & orders we get from first time buyers? 
WITH first_time_byers AS(
	SELECT 
		DISTINCT order_id,
		date,
		amount
	FROM orders
	WHERE is_ftb = 1 AND is_tip = 0
)
SELECT 
	date,
	SUM(amount) OVER func_window  as daily_revenue,
	COUNT(order_id) OVER func_window as daily_orders
FROM orders
WINDOW func_window as (PARTITION BY date);
	
-- Q-5: What are the top 3 countries that our buyers are coming from?
SELECT 
	u.country as buyers_country,
	COUNT(DISTINCT o.buyer_id)  as num_buyers	
FROM orders o
JOIN users u
ON o.buyer_id = u.user_id
WHERE is_tip = 0
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;

-- Q-6: What is the difference in average sale price for first_time_buyers vs. Repeat buyer(not first time buyers)?
-- please provide just the diff [(ftb revenue / not_ftb revenue) -1]
WITH buyers AS(
	SELECT 
		is_ftb,
		SUM(amount) / COUNT(DISTINCT order_id) avg_sale_price
	FROM orders
	WHERE is_tip = 0
	GROUP BY 1
)
SELECT 
	MAX(CASE WHEN is_ftb = 1 THEN avg_sale_price END) / MAX(CASE WHEN is_ftb = 0 THEN avg_sale_price END) - 1
		as diff_avg_sale_price
FROM buyers;
	
-- Q-7: What are the top 5 sellers’ countries with the highest gap in spend per buyer (revenue / buyers)  between FTB and Repeat buyers?
WITH spend_on_buyers AS (
	SELECT 
		u.country as seller_country,
		o.is_ftb,
		SUM(o.amount) / COUNT(DISTINCT o.buyer_id) as spend_per_buyer
	FROM orders o
	JOIN users u
	ON o.seller_id = u.user_id
	WHERE is_tip = 0
	GROUP BY 1,2
)
SELECT seller_country,
	MAX(CASE WHEN is_ftb = 1 THEN spend_per_buyer END) / MAX(CASE WHEN is_ftb = 0 THEN spend_per_buyer END) - 1
		as diff_spend_per_buyer
FROM spend_on_buyers
GROUP BY 1
ORDER BY 2
LIMIT 5;

-- Q-8: What are the top 5 categories with the higher % of tip?
SELECT 
	category_id,		
	SUM(CASE WHEN is_tip = 1 THEN amount END) / SUM(amount) as rate_tip	
FROM orders
WHERE category_id IS NOT NULL
GROUP BY 1
ORDER BY 2
LIMIT 5;

-- Q-9: How does the daily revenue & orders distribute between the platforms? (please provide your answer in %)
SELECT 
	SUM(CASE WHEN platform = 'web' THEN amount END) / SUM(amount) as revenue_web_ratio,
	SUM(CASE WHEN platform = 'app' THEN amount END) / SUM(amount) as app,
	SUM(CASE WHEN platform = 'mobile_web' THEN amount END) / SUM(amount) as revenue_mobile_web_ratio,	
	
	COUNT(DISTINCT CASE WHEN platform = 'web' THEN order_id END) / COUNT(DISTINCT order_id) as orders_web_ratio,
	COUNT(DISTINCT CASE WHEN platform = 'app' THEN order_id END) / COUNT(DISTINCT order_id) as orders_app_ratio,
	COUNT(DISTINCT CASE WHEN platform = 'mobile_web' THEN order_id END) / COUNT(DISTINCT order_id) as orders_mobile_web_ratio
FROM orders
WHERE is_tip = 0;

-- Q-10: What are the top 5 categories with the higher absolut diff (Subtraction) between the average of unique SC per buyer 
-- and median of unique SC per buyer.
WITH sub_categories AS(
	SELECT 
		category_id,
		buyer_id,
		COUNT(DISTINCT sc_id) as num_sub_categories
	FROM orders
	WHERE is_tip = 0
	GROUP BY 1,2
)
SELECT 
	DISTINCT category_id,
	AVG(num_sub_categories) OVER (PARTITION BY category_id) - 
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY num_sub_categories) 
			as avg_median_diff
FROM sub_categories
GROUP BY 1, num_sub_categories
ORDER BY 2 DESC
LIMIT 5;

-- Q-11: Out of  the revenue of 2021 what is the distribution of revenue by buyer cohorts (by “age”/ “seniority”)? 
-- show the distribution by the year of the FTB order. Results should look something like this:
/*
FTB year | % revenue
2021 | 0.6
2020 | 0.3
2019 | 0.1
*/
WITH total_revenue AS(
	SELECT 
		SUM(amount) as revenue
	FROM orders
	WHERE is_tip = 0
),
	years_cohort AS(
	SELECT 
		DATE_PART('year', ftb_created_at) as ftb_cohort,
		SUM(amount) as revenue
	FROM orders
	WHERE is_tip = 0
	GROUP BY 1
)
SELECT
	y.ftb_cohort,
	y.revenue / t.revenue as revenue_rate
FROM years_cohort y
CROSS JOIN total_revenue t
ORDER BY 1 DESC;
/*
PostgreSQL Cross Join By Example:
https://www.postgresqltutorial.com/postgresql-cross-join/
*/