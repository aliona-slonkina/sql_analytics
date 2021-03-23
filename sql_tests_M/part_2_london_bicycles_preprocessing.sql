/* 
********** PART-2: Preliminary conclusion & Data preprocessing ********************* 

1. The dataset has no duplicated values.
2. In the cycle_hire table two columns (start_station_id, end_station_id) that we need for our analysis have Null values.
3. Also the duration and start_date columns (cycle_hire table) have outlirers and weird value.
*/

/* 
Preprocessing the public dataset is beyond the scope of the current tasks.
However, in order to get a clearer and more accurate analysis result, 
I consider that the following minimum should be done:

A) Removing outliers in duration of rent in the cycle_hire table.

B) Creating temporary (view) tables without rows having missing and/or weird values. 
*/

-- # A) Defining outliers:

/* The interquartile range (IQR) approach and using NTILE() finction (postgreQSL):
Finds values interquartile range (IQR) that is the difference between q1 and q3.
Outliers are values that fall 1.5x IQR below q1 or 1.5x IQR above q3.
*/
WITH duration_quartiles AS(	
	SELECT 
		rental_id,
		duration,
		NTILE(4) OVER (ORDER BY duration) AS duration_quartile
    FROM cycle_hire -- `bigquery-public-data.london_bicycles.cycle_hire`
)
SELECT
	duration_quartile,
	MAX(duration) AS quartile_break
FROM duration_quartiles
WHERE duration_quartile IN (1, 3)
GROUP BY duration_quartile
;

/* 
According to the stat method, we have to remove outliers from the duration column that are out of range:
from q1 - ((q3 - q1) * 1.5) to q3 + ((q3 - q1) * 1.5)

However, calculating the smallest allowable value for the ride duration, we have:
480 - ((1320 - 480) * 1.5) => 480 - 1260 = -780 sec
:=(

So, the business logic needs to be discussed. But right now, let's use human logic to determine the outliers in this particular case :)
For example, we can think of the values as emissions for trips of less than 5 minutes (300 seconds).
*/
SELECT 
	COUNT(1)
FROM cycle_hire --`bigquery-public-data.london_bicycles.cycle_hire`
WHERE duration < 300
;

-- The dataset has 1,909,331 rows with such odd short rides.

-- # B) Creating View tables:

/*
Instead of removing some records let's create View tables. 
We'll get more or less clear data, and this will allowed us to avoid repeating lines of code.
Also, we can use only columns we need for our tasks that makes our queries more readable and elegant.
*/

-- B-2) Creating VIEW of cycle_hire:

CREATE OR REPLACE VIEW view_cycle_hire AS
	SELECT 
		rental_id	
		, duration	
		, bike_id
		, end_date	
		, end_station_id	
		, end_station_name	
		, start_date	
		, start_station_id	
		, start_station_name
	FROM cycle_hire -- `bigquery-public-data.london_bicycles.cycle_hire`
 	WHERE 
		duration >= 300		
		AND start_date IS NOT NULL 
		AND end_date IS NOT NULL
		AND start_date < end_date
;
	
CREATE OR REPLACE VIEW view_cycle_stations AS
	SELECT
		id
		, installed
		, latitude
		, locked
		, longitude
		, name
		, bikes_count	
		, docks_count
		, temporary
		, terminal_name
		, install_date	
		, removal_date
	FROM cycle_stations -- `bigquery-public-data.london_bicycles.cycle_stations`
	WHERE 
		install_date IS NOT NULL 
		;