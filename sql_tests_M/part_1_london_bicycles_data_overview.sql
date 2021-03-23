/* PART-1: before solving tasks, let's explore our dataset a bit. */
SELECT 
 	COUNT(DISTINCT id) as num_stations 
	, SUM(bikes_count) as total_bikes
	, MIN(install_date) as min_install_date 
	, MAX(install_date) as max_install_date 
FROM cycle_stations
;

SELECT 
	COUNT (DISTINCT rental_id) num_rentals
	, MIN(start_date) first_rent_date
	, MAX(start_date) last_rent_date
	, COUNT(DISTINCT bike_id) num_bikes
FROM cycle_hire
;
/* 
#1: Let's check if the columns that will be used in tasks have Null values.
Despite that, the fields are allowed to have Null values we should study them 
to exclude their impact on our results of the analysis. 
*/
-- #1-1: Nulls in the cycle_stations table:
SELECT 
	COUNT(CASE WHEN id IS NULL THEN id END) as n_id_nulls,
	COUNT(CASE WHEN installed IS NULL THEN id END) as n_installed_nulls,
	COUNT(CASE WHEN latitude IS NULL THEN id END) as n_latitude_nulls,
	COUNT(CASE WHEN longitude IS NULL THEN id END) as n_longitude_nulls,
	COUNT(CASE WHEN name IS NULL THEN id END) as n_name_nulls,
	COUNT(CASE WHEN docks_count IS NULL THEN id END) as n_docks_count_nulls,
	COUNT(CASE WHEN temporary IS NULL THEN id END) as n_temporary_nulls
FROM cycle_stations
;
-- There is no Null value:)

-- #1-2: Are there Nulls in the cycle_hire table:
SELECT 
	COUNT(CASE WHEN rental_id IS NULL THEN rental_id END) as n_rental_id_nulls,
	COUNT(CASE WHEN duration IS NULL THEN rental_id END) as n_duration_nulls,
	COUNT(CASE WHEN bike_id IS NULL THEN rental_id END) as n_bike_id_nulls,
	
	COUNT(CASE WHEN end_date IS NULL THEN rental_id END) as n_end_date_nulls,
	COUNT(CASE WHEN end_station_id IS NULL THEN rental_id END) as n_end_station_id_nulls,
	COUNT(CASE WHEN end_station_name IS NULL THEN rental_id END) as n_end_station_name_nulls,
	
	COUNT(CASE WHEN start_date IS NULL THEN rental_id END) as n_start_date_nulls,	
	COUNT(CASE WHEN start_station_id IS NULL THEN rental_id END) as n_start_station_id_nulls,
	COUNT(CASE WHEN start_station_name IS NULL THEN rental_id END) as n_start_station_name_nulls
	
FROM cycle_hire
;
/*
Columns start_station_id and end_station_id have 229,639 Null records. 
*/

-- #2-1: Checking duplicates in the cycle_stations table:
SELECT 
	id, 
	COUNT(id) as num_duplicated
FROM cycle_stations
GROUP BY 1
HAVING COUNT(id)>1
;
-- There is no duplicates in id column
					  
-- #2-2: Checking duplicates in the cycle_hire table:
SELECT 
	rental_id, 
	COUNT(rental_id) as num_duplicated
FROM cycle_hire
GROUP BY 1
HAVING COUNT(rental_id) > 1
;
-- There is no duplicates in rental_id column

/* #3: Impossible or weird values.*/

-- #3-1: Records with rental duration equaled to 0:
SELECT 
	COUNT(rental_id) as num_zero_duration
FROM cycle_hire
WHERE duration = 0
;
-- There are 34236 lines, where the rent duration is 0 seconds.
-- But it seems that the duration column has more rows as outliers. We'll process them later in the next chapter.

-- #3-2: if is start_date > end_date
SELECT 
	COUNT(1) as num_rows
FROM cycle_hire
WHERE start_date > end_date
;
-- There are 366 rows contain conflicting values where the lease end day is earlier than the lease start day.
-- Let's take a look at sample of them
SELECT *	
FROM cycle_hire
WHERE start_date > end_date
LIMIT 10
;

-- #-3-3: is there a station that's not installed
SELECT 
	COUNT(1) as num_not_installed_stations
FROM cycle_stations
WHERE installed = false
;
-- There is no:)

-- #3-4: is there stations with install_date latter then removal_date
SELECT 
	COUNT(1) as num_rows
FROM cycle_stations
WHERE install_date > removal_date
;
-- There is no:)
