-- This file contains answers to tasks 3 - 8:

-- Q-3: What is the % of late orders for completed and canceled final status. 

WITH final_order_status AS(
	SELECT 
		DISTINCT order_id
		, MAX(created_at) as date_finish
		, type
		, is_late
		, COUNT(order_id) OVER() as total_finished_orders
	FROM orders_events
	WHERE 
		type IN ('completed', 'canceled')
	GROUP BY 1, 3,4		
)
  	, late_final_status AS (
	
		SELECT 
			type
			, total_finished_orders
			, COUNT(DISTINCT CASE WHEN is_late = true THEN order_id END) as late_orders
		FROM final_order_status
		GROUP BY 1,2
	)

SELECT 
	type
	, late_orders * 100 / total_finished_orders as "The % of late orders for final status"
FROM late_final_status;

-- Q-4: What is % of delivery’s rejection per price bucket 
-- (please create 5 price buckets accordingly 5, 5-15, 15-50, 50-100, >100] 
-- and notice that because of taxes the order about is a continuance value)

WITH price_bucket AS(
	SELECT 
		DISTINCT o.order_id,	 
		CASE 
			 WHEN o.amount > 100 THEN 'over 100'
			 WHEN o.amount > 50 AND o.amount <= 100 THEN '51 - 100'
			 WHEN o.amount > 15 AND o.amount <= 50 THEN '16 - 50'
			 WHEN o.amount > 5 AND o.amount <= 15 THEN '6 - 15'
			 WHEN o.amount > 0 AND o.amount <= 5 THEN '0 - 5'
				END as price,
		e.type
	FROM orders o
	JOIN orders_events e USING (order_id)
	WHERE is_tip = 0
)
SELECT 
	price,
	ROUND(
		COUNT(DISTINCT CASE WHEN type ='rejected' THEN order_id END) *100/ count(distinct order_id)
			) as "The % of delivery’s rejection per price bucket"
FROM price_bucket
GROUP BY 1;

-- Q-5: What is the average total_duration (in hours) of an order per category. 
-- Please ignore orders that were not finished
/*NOTE: we have only 2 final statuses possible for an order; order_completed, order_canceled*/

WITH orders_duration AS(
	SELECT 
		DISTINCT e.order_id,
		o.date as order_created_at,
		o.category_id,
 		e.type,
		MAX(e.created_at) as order_finished_at
	FROM orders o 
	JOIN orders_events e USING (order_id)
	WHERE e.type IN ('completed', 'canceled') 
		AND o.is_tip = 0
		AND o.category_id IS NOT NULL
	GROUP BY 1,2,3,4
)
SELECT
	DISTINCT category_id,
	AVG(order_finished_at - order_created_at) OVER (PARTITION BY category_id) as avg_order_duration
FROM orders_duration;

-- Q-6: For orders with ASP (average sale price) greater than 50$ that were finished: 
-- find the average number of deliveries per order by finish status (order.completed / order.canceled). 
/* NB! Every time the seller send something to the buyer it creates order_delivered event in our table.*/

WITH orders_asp_above_50 AS(
	SELECT 
		order_id
	FROM orders
	WHERE is_tip = 0 
	GROUP BY 1
	HAVING SUM(amount) / COUNT(DISTINCT order_id) > 50
)
	, finshed_orders AS (	
		SELECT 
			DISTINCT order_id,
			COUNT(type) OVER (PARTITION BY order_id ORDER BY created_at) as finish_type
		FROM orders_events
		WHERE type IN ('completed', 'canceled') 
		
	),
		filtered_finished_orders AS (		
			SELECT 
				e.order_id,
				b. finish_type,
				COUNT(DISTINCT e.created_at) as num_of_deliveries -- each delivery will have it's own created_at
		  	FROM  orders_events as e
			JOIN finished_orders as f 
			ON f.order_id = e.order_id -- this join is for filter purposes
		  	JOIN orders_asp_above_50 as asp
			ON asp.order_id = e.order_id -- this join is for filter purposes
		  	WHERE 
			-- after this condition with the joins above we get only orders with ASP >= 50 that were finished
				type = 'order.delivered'  
			GROUP BY 1,2			
		)	
SELECT 
      finish_type,
      AVG(num_of_deliveries) as avg_num_of_deliveries_per_order 
FROM  filtered_finished_orders      
GROUP BY 1     
;

-- Q-7: What is the distribution of the finish (order.completed, order.cancel) platform for each started platform? 
/*
Please present the results like this:
Start platform \ finish platform: web | Mobile web | app
web								  0.8 | 0.02	   | 0.18
Mobile web						  0.5 | 0.03	   | 0.2
app								  0.7 | 0.05	   | 0.25
*/
-- Solution by mentor:)

with  start_platform as (  -- we can get the same value from orders table or by using first_vlaue(crdated_at)
select 
		order_id,
        platform
from  orders_events
where type = 'success'
group by 1,2
)      
,finished_platform  as (
select distinct 
       order_id,
        last_value(platform) over(partition by order_id  order by created_at ASC rows between unbounded preceding and unbounded following) as platform
from orders_events
where type in ('completed', 'cancel')
)
-- now if we want to get the same table as in the question we can not solve it with 1 query with "case when" cause then we will get 9 columns.
-- my solution for that is to perform the calculation per platform and then union the 3 tables to 1 table which will look exactly as requested in the question.
, web as (
select 
        a. platform  as started_patform, 
       count(distinct case when b. platform = 'web' then a. order_id end)/ count(distinct  a. order_id) as finish_web_rate,
       count(distinct case when b. platform = 'app' then a. order_id end)/ count(distinct  a. order_id) as finish_app_rate,
       count(distinct case when b. platform = 'mobile_web' then a. order_id end)/ count(distinct a. order_id) as finish_mobile_web_rate
from start_platform as a
join finished_platform as b 
	ON a. order_id = b. order_id  -- I want only orders that are finished. that is why I am using join 
where a. platform  = 'web'
group by 1
)
, mobile_web as (
select 
        a. platform  as started_patform, 
       count(distinct case when b. platform = 'web' then a. order_id end)/ count(distinct  a. order_id) as finish_web_rate,
       count(distinct case when b. platform = 'app' then a. order_id end)/ count(distinct  a. order_id) as finish_app_rate,
       count(distinct case when b. platform = 'mobile_web' then a. order_id end)/ count(distinct a. order_id) as finish_mobile_web_rate
from start_platform as a
join finished_platform as b 
	ON a. order_id = b. order_id  -- I want only orders that finished. that is why I am using join 
where a. platform  = 'mobile_web'
group by 1
)
, app as (
select 
        a. platform  as started_patform, 
        count(distinct case when b. platform = 'web' then a. order_id end)/ count(distinct  a. order_id) as finish_web_rate,
        count(distinct case when b. platform = 'app' then a. order_id end)/ count(distinct  a. order_id) as finish_app_rate,
        count(distinct case when b. platform = 'mobile_web' then a. order_id end)/ count(distinct a. order_id) as finish_mobile_web_rate
from start_platform as a
join finished_platform as b 
	ON a. order_id = b. order_id  -- I want only orders that finished. that is why I am using join 
where a. platform  = 'app'
group by 1
)

select * 
from 
      (
      select * from web
      union all 
      select * from mobile_web
      union all 
      select * from app
      ) sub
;

-- Q-8: Out of all orders with cancellation requests (from buyer or seller), 
-- what is the percent of order that was finished (please also break to finish and complete) and didn’t finish.
/* Note - Please do not take orders in progress. 
For that please assume that each order that 7 days didn’t pass from creation (order.success) is still in progress. 
In other words please remove from all orders that didn’t have finish status within 7 days from creation. */
/*
To solve this task let's draw a small scheme for orders that are considered as finished:
					 
	finished orders are: --> completed (status can be changed to --> canceled)
					     --> canceled: --> mutual_cancellation_requested_by_seller --> completed or canceled
					 			   	   --> mutual_cancellation_requested_by_buyer --> completed or canceled
*/
WITH final_satus AS(
	SELECT 
		order_id,
		type as finished_status,
		created_at as finished_at
	FROM orders_events
	WHERE type IN ('completed', 'canceled')	
),
	cancellation_request_status AS(	
		SELECT 
			order_id,
			type as request_status,
			created_at 
		FROM orders_events
		WHERE type IN ('mutual_cancellation_requested_by_seller', 'mutual_cancellation_requested_by_buyer')
	),
  		latest_order_status AS(
			SELECT 
				CASE
					WHEN finished_status = 'completed' THEN 'finished' 
					WHEN finished_status = 'canceled' THEN 'finished_by_cancellation'
						ELSE 'cancellation_requested' END
							as latest_status,
 				COUNT(order_id) as num_orders
			FROM cancellation_request_status r
			LEFT JOIN final_satus f USING (order_id)
			WHERE EXTRACT(day FROM AGE(finished_at, created_at)) >= 7
 			GROUP BY 1
		)
 		SELECT 
 			latest_status,
 			num_orders,
 			ROUND(num_orders * 100 / SUM(num_orders) OVER (), 2) as orders_status_ratio
 		FROM latest_order_status
 		GROUP BY 1,2;	

