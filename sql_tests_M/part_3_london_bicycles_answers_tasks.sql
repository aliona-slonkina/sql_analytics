/*
********** PART-3: Answers to the tasks ********************* 
*/

-- Q-1: Return the names of stations that established after 2013:

SELECT 
	name as stations_established_after_2013
	, install_date
FROM view_cycle_stations
WHERE 
	EXTRACT(year FROM install_date) > 2013
ORDER BY 2
;

-- Q-2: Return the number of stations that established after 2013:

SELECT 
	COUNT (DISTINCT name) as number_stations_established_after_2013
FROM view_cycle_stations
WHERE 
	EXTRACT(year FROM install_date) > 2013
	;

-- Q-3: Return the station names that are not in Chelsea and their docks_count is bigger than 50:

SELECT 
	name as stations_outside_Chelsea_more_50_docks	
FROM view_cycle_stations
WHERE 
	name NOT LIKE '%Chelsea%' AND docks_count > 50
	;

-- Q-4: What is the temporary station percentage?

SELECT
	 ROUND(
		 COUNT(DISTINCT CASE WHEN temporary = true THEN id END) * 100 / COUNT(DISTINCT id)
		 	::numeric, 2) 
				as share_temporary_stations
FROM view_cycle_stations
;

-- Q-5: Per each year, return the number of stations that established this year:

SELECT 	
	EXTRACT (year FROM install_date) as establish_year
	, COUNT (DISTINCT id) as number_stations
FROM view_cycle_stations
GROUP BY 1
;

-- Q-6: Return the top 5 end stations with the lowest number of dockings:

SELECT 
	DISTINCT h.end_station_id
	, h.end_station_name as top_5_end_stations_lowest_docks
	, s.docks_count as "Number of dockings"
FROM cycle_hire h
JOIN view_cycle_stations s
ON h.end_station_id = s.id
ORDER BY 3 ASC  
LIMIT 5
;

-- Q-7: Return the avg number of renting per bike:

WITH times_rented AS(
	SELECT 
		rental_id
		, COUNT(rental_id) OVER (PARTITION BY bike_id) AS bike_renting
	FROM view_cycle_hire
)
SELECT
	ROUND (AVG(bike_renting)::decimal, 2) as avg_renting_per_bike
FROM times_rented
;

-- Q-8: Return the avg number of renting per bike per year

WITH times_rented_year AS(
	SELECT 
		bike_id
		, DATE_PART ('year', start_date) as year
		, COUNT(rental_id) OVER (PARTITION BY bike_id) AS bike_renting
	FROM view_cycle_hire
)
SELECT
	year
	, ROUND(AVG(bike_renting), 2) as avg_yearly_renting_per_bike
FROM times_rented_year
GROUP BY 1
;

-- Q-9: Return the number of rentals that started and ended on different days:

SELECT
	COUNT(
		CASE 
			WHEN DATE_TRUNC('day', end_date) != DATE_TRUNC('day', start_date) 
				THEN rental_id END
				) as num_rents_duration_more_1_day
FROM view_cycle_hire
;
-- M variant
select  
	count(distinct  rental_id) rentals 
from    cycle_hire a
where date(start_date) <>  date(end_date)


-- Q-10-1: Return the AVG of rentals per bike, where duration was less than 1000 sec:

WITH rentals_less_1000_sec AS (

	SELECT
		DISTINCT bike_id as bikes
		, COUNT(rental_id) as num_rentals_less_1000_sec
	FROM view_cycle_hire
	WHERE duration < 1000
	GROUP BY 1
)
SELECT
	ROUND(
		SUM (num_rentals_less_1000_sec) / COUNT(bikes), 2)
			as num_rental_per_bike_less_1000_sec
FROM rentals_less_1000_sec
;
-- Q-10-2: Return the number of rentals per bike, where duration was less than 1000 sec:

SELECT
	bike_id as bikes
	, COUNT(DISTINCT rental_id) as num_rentals_less_1000_sec
FROM view_cycle_hire
WHERE duration < 1000
GROUP BY 1
;

-- M variant
select  
	bike_id,      
	count(distinct rental_id) rentals
from    cycle_hire a
where duration <= 1000
group by 1


-- Q-11: Return the top 3 rented bike id where the duration was less than 1000 sec:

SELECT
	DISTINCT bike_id
	, COUNT(rental_id) as num_rented
FROM view_cycle_hire
WHERE duration < 1000
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3
;

-- Q-12: Return the top 10 bikes that were used in 2014 and 2016

SELECT	
	DISTINCT bike_id
	, COUNT (DISTINCT rental_id) num_rents
FROM view_cycle_hire
WHERE DATE_PART('year', start_date) IN (2014, 2016)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10
;

-- Q-13 - A: Return the top bikes that had the most duration between 2014 and 2016.
/* Let's assume that:
1) we consider the only rentals that were started and ended in 2015
2) top bikes = 5, just as example
*/
SELECT
	DISTINCT bike_id
	, duration
FROM view_cycle_hire
WHERE 
	DATE_PART('year', start_date) = 2015
	AND DATE_PART('year', end_date) = 2015
ORDER BY 2 DESC
LIMIT 5
;	

-- Q-13 - B: Top bikes with most avg duration per rentals

SELECT
	DISTINCT bike_id
 	, ROUND(AVG(duration) OVER (PARTITION BY bike_id)) as avg_duration
FROM view_cycle_hire
-- WHERE bike_id IN (4071, 5351, 13685)
ORDER BY avg_duration DESC
LIMIT 5
;

-- Q-14: Per bike_id 2143 find the names of the stations that weren’t there at all

WITH all_point_satations AS (

	SELECT
		bike_id
		, end_station_name as station_name
	FROM view_cycle_hire
	UNION
	SELECT
		bike_id
		, start_station_name as station_name
	FROM view_cycle_hire
)
SELECT 
	DISTINCT station_name 
FROM all_point_satations
WHERE bike_id != 2143
ORDER BY 1
;
-- M variant
select 
	name
from cycle_stations  
where id not in (select start_station_id  
		   		from cycle_hire
                where bike_id=2143)
group by 1 
;

-- Q-15: Per each rent return start time, and coordinates of start station:

SELECT 
	hire.rental_id
	, hire.start_station_id
	, hire.start_date
	, stat.latitude
	, stat.longitude
FROM view_cycle_hire as hire
JOIN
	view_cycle_stations as stat
	ON
	hire.start_station_id = stat.id
WHERE hire.start_station_id IS NOT NULL
;

-- Q-16: Per each rent return start time, end_time, and coordinates of start station and end_stations:
/* 
Let's create VIEW table for 16th and 17th tasks.
*/

CREATE OR REPLACE VIEW geo_coordinates AS
	SELECT 
			DISTINCT hire.rental_id
			, hire.start_station_id
			, hire.start_date
			, hire.end_station_id
			, hire.end_date
			-- adding coordinates for the start station:
			, stat.latitude as stat_latitude
			, stat.longitude as stat_longitude			
			-- adding coordinates for the end station:
			, end_st.latitude as end_latitude
			, end_st.longitude as end_longitude
		FROM view_cycle_hire as hire
		JOIN
			view_cycle_stations as stat
			ON
			hire.start_station_id = stat.id
		JOIN
			view_cycle_stations as end_st
			ON
			hire.end_station_id = end_st.id
		WHERE 
			hire.start_station_id IS NOT NULL
			AND hire.end_station_id IS NOT NULL
;

-- Now let's answer the question:
SELECT *
FROM geo_coordinates
;

-- Q-17: Return all rentals that the longitude distance between start and end is bigger than 0.2 
-- (write also a solution with having) 
/*
To answer this question, it would be better to use extension for PostgreSQL.
Let's add them:
*/
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

-- NB! The distance will be in miles.
SELECT *
	, (point(stat_longitude, stat_latitude) <@> point(end_longitude, end_latitude)::point) * 1609.344 as distance 
FROM geo_coordinates
WHERE 
	point(stat_longitude, stat_latitude) <@> point(end_longitude, end_latitude) > 0.2
ORDER BY distance DESC;

-- Q-18: Return the name of the start and end station where the highest duration of rent was in:
SELECT
	duration
	, start_station_name
	, end_station_name
FROM view_cycle_hire
WHERE duration = (
	SELECT
		MAX (duration)
	FROM view_cycle_hire
);
-- M variant
select  
      start_station_name,
      end_station_name,
      max(duration) as duration
from  cycle_hire
group by 1,2, duration
having duration >= (select max(duration) 
	                    from cycle_hire)
;

-- Q-19: per each day in 2015 return the total number of rentals and avg daily duration, order by the date the results.
SELECT
	DATE_TRUNC('day', start_date) as day
	, COUNT(DISTINCT rental_id) as daily_rentals
	, ROUND(AVG(duration)) as avg_daily_duration
FROM view_cycle_hire
WHERE DATE_PART('year', start_date) = 2015
GROUP BY 1
ORDER BY 1
;

-- Q-20:  Return per each bike the first rental date.
SELECT
	DISTINCT bike_id
	, DATE_TRUNC('day', MIN(start_date))
FROM view_cycle_hire
GROUP BY 1
ORDER BY 1
;
-- M variant
with bike_rn as(
	select  
	bike_id,
	start_date,
	row_number() over(partition by bike_id order by start_date) rn
	from   cycle_hire )
 select bike_id,start_date
 from bike_rn
 where rn=1
group by 1,2
;

-- Q-21: Per each bike, per each year - return the total duration:

SELECT
	bike_id
	, EXTRACT(year FROM start_date) as rent_year
	, SUM(AGE(end_date, start_date)) as toal_duration_min	
FROM view_cycle_hire
GROUP BY 1,2
ORDER BY 1;

-- M variant
select
	distinct bike_id,
	extract(year from start_date) as year,
	sum( duration )  over( partition by bike_id,extract(year from start_date))  as sum_duration
from   cycle_hire
order by 1
;
