-- Q-3: What is the % of late orders for  completed and canceled final status. 

WITH final_order_status AS(
	SELECT 
		DISTINCT order_id,
		type,
		is_late
	FROM orders_events
	WHERE type IN ('completed', 'canceled')
)
SELECT 
	ROUND(COUNT(DISTINCT CASE WHEN is_late = true THEN order_id END) * 100/ COUNT(DISTINCT order_id), 2) 
		as "The % of late orders for  completed and canceled final status"
FROM final_order_status;

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
	COUNT(CASE WHEN type ='rejected' THEN price END) *100 / 
		COUNT(price) OVER (PARTITION BY price) 
			as "The % of delivery’s rejection per price bucket"
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
		e.created_at as order_finished_at
	FROM orders_events e
	JOIN orders o USING (order_id)
	WHERE e.type IN ('completed', 'canceled') 
		AND o.is_tip = 0
		AND o.category_id IS NOT NULL
)
SELECT
	DISTINCT category_id,
	AVG(order_finished_at - order_created_at) OVER (PARTITION BY category_id) as avg_order_duration
FROM orders_duration;

-- Q-6: For orders with ASP (average sale price) greater than 50$ that were finished: 
-- find the average number of deliveries per order by finish status (order.completed / order.canceled). 
/* NB! Every time the seller send something to the buyer it creates order_delivered event in our table.*/

WITH events_type AS(
	SELECT 
		e.order_id,
		COUNT(e.created_at) as num_events
	FROM orders o
	JOIN orders_events e USING (order_id)
	WHERE is_tip = 0 
 		AND o.amount > 50
		AND e.type IN ('completed', 'canceled')
	GROUP BY 1
)
SELECT 
	ROUND(AVG(num_events), 2) as "The average number of deliveries per order by finish status"
FROM events_type;

-- Q-7: What is the distribution of the finish (order.completed, order.cancel) platform for each started platform? 
/*
Please present the results like this:
Start platform \ finish platform: web | Mobile web | app
web								  0.8 | 0.02	   | 0.18
Mobile web						  0.5 | 0.03	   | 0.2
app								  0.7 | 0.05	   | 0.25
*/
/* Solution with using Pivoting in podtgreSQL:
STEP #1: Enabling the Crosstab Function
STEP #2: RUN crosstab function with subqueries
*/
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT *
	FROM CROSSTAB(
	$$	
	WITH finished_platforms AS(
		SELECT 
			order_id,
			type as finish_status,
			created_at as finished_at,
			platform as finish_platform
		FROM orders_events
		WHERE type IN ('completed', 'canceled')
		ORDER BY 1
	), 
		start_finish_platforms AS(	
			SELECT 
				e.order_id,
				e.created_at,
				e.platform as start_platform,
				f.finished_at,
				f.finish_platform
			FROM orders_events e
			JOIN finished_platforms f USING (order_id)
			WHERE e.type = 'success' 
				AND finished_at > created_at -- just for checking
		), 
			dist_platform AS(
				SELECT 
					DISTINCT start_platform,
					finish_platform,
					CUME_DIST() OVER (PARTITION BY start_platform ORDER BY finish_platform) as cum_dist
				FROM start_finish_platforms		
			)
			SELECT * FROM dist_platform $$,
			$$
				VALUES				 
				('app'), 
				('mobile_web'),
				('web')
			$$
			)		  
			AS pivot_platform (
				platform text, 
				app FLOAT(2),
				mobile_web FLOAT(2),
			  	web FLOAT(2)
			);

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
			WHERE EXTRACT(day FROM AGE(finished_at, created_at)) < 7
 			GROUP BY 1
		)
 		SELECT 
 			latest_status,
 			num_orders,
 			ROUND(num_orders * 100 / SUM(num_orders) OVER (), 2) as orders_status_ratio
 		FROM latest_order_status
 		GROUP BY 1,2;	

