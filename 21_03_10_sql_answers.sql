--Q-1: How many employees there are in the company?
SELECT 
	COUNT(emp_id) num_employees
FROM employees;
/*
Solved (Y/N):
*/

-- Q-2: How many employees there are per earch rank?
SELECT 
	emp_rank,
	COUNT(emp_id) AS num_employees	
FROM employees
GROUP BY 1
ORDER BY 2 DESC;
/*
Solved (Y/N):
*/

-- Q-3: What is the median salary?
/*
The source I used to solve this task: Calculating Percentile (and Median) in PostgreSQL
https://leafo.net/guides/postgresql-calculating-percentile.html#calculating-the-median
*/
-- A: per each department? 
SELECT 
	d.department_id,
	d.department_name,
	percentile_disc(0.5) WITHIN GROUP(ORDER BY s.salary) as median_salary
FROM department d
JOIN employees e USING (department_id)
-- 	ON d.department_id = e.department_id
JOIN salaries s
	ON e.emp_id = s.employee_id
GROUP BY 1,2;

-- B: What is the median salary per each site?
SELECT 
	st.site_id,
	percentile_disc(0.5) WITHIN GROUP(ORDER BY s.salary) as median_salary	
FROM salaries s
JOIN employees e
	ON s.employee_id = e.emp_id
JOIN department d
	ON e.department_id = d.department_id
JOIN sites st
	ON d.site_id = st.site_id
GROUP BY 1;

/*
Solved (Y/N):
*/

-- Q-4: What is the most expensive site (cost + salaries)? 
-- EXPLAIN
WITH site_expenses AS(
	SELECT 
		st.site_id,
		SUM(st.site_cost) + SUM(s.salary) as total_expenses
	FROM sites st
	JOIN department d
		ON st.site_id = d.site_id
	JOIN employees e
		ON d.department_id = e.department_id
	JOIN salaries s
		ON e.emp_id = s.employee_id
	GROUP BY 1
	ORDER BY total_expenses DESC
)
SELECT *
FROM site_expenses
WHERE total_expenses = (
	SELECT MAX(total_expenses)
	FROM site_expenses
);

/*
Solution with WINDOW function instead of using Group By. 
But performance comparison of these 2 variants remains open for me:)
*/
-- EXPLAIN
WITH site_expenses AS(
SELECT 
	DISTINCT st.site_id,
	MAX(st.site_cost + s.salary) OVER (PARTITION BY st.site_id) as total_expenses
FROM sites st
JOIN department d
	ON st.site_id = d.site_id
JOIN employees e
	ON d.department_id = e.department_id
JOIN salaries s
	ON e.emp_id = s.employee_id
)
SELECT *
FROM site_expenses
WHERE total_expenses = (
	SELECT 
		MAX(total_expenses)
	FROM site_expenses
);
/*
Solved (Y/N):
*/

-- Q-5: What is the biggest department? 
/*
I assume that this is in terms of the number of employees:)
*/
WITH num_emp_per_dep AS(
	SELECT 
		department_id,
		COUNT(emp_id) as num_emp
	FROM employees
	GROUP BY 1
	)
SELECT *
FROM num_emp_per_dep
WHERE num_emp = (
	SELECT MAX(num_emp) as max_emp
	FROM num_emp_per_dep
);
/*
Solved (Y/N): 
*/

-- Q-6: What is the most expensive department?
-- by (site_cost + salary)
WITH dep_expenses AS(
	SELECT 
		DISTINCT d.department_id,
		d.department_name,
		MAX(st.site_cost + s.salary) OVER (PARTITION BY st.site_id) as total_expenses
	FROM department d 
	JOIN sites st
		ON d.site_id = st.site_id
	JOIN employees e
		ON d.department_id = e.department_id
	JOIN salaries s
		ON e.emp_id = s.employee_id
)
SELECT *
FROM dep_expenses
WHERE total_expenses = (
	SELECT MAX(total_expenses)
	FROM dep_expenses
);
/*
Solved (Y/N):
*/

-- Q-7: How many employees joined in the last year? Split it by months.
SELECT 
	DATE_PART('month', hiring_date) AS hiring_month,
	COUNT(emp_id) as num_hired_emp
FROM employees
WHERE DATE_PART('year', hiring_date) = '2020'
GROUP BY 1
ORDER BY 1;
/*
Solved (Y/N):
*/

-- Q-8: What is the salary share of site #2 out of total salaries?
WITH total_site_salaries AS(
	SELECT 
		st.site_id,
		SUM(s.salary) as salaries_per_site
	FROM sites st
	JOIN department d
		ON st.site_id = d.site_id
	JOIN employees e
		ON d.department_id = e.department_id
	JOIN salaries s
		ON e.emp_id = s.employee_id
	GROUP BY 1
),
	share_site_salaries AS(
	SELECT *,
 		ROUND(salaries_per_site / SUM(salaries_per_site) OVER() * 100, 2) as share_salary
	FROM total_site_salaries
)
SELECT *
FROM share_site_salaries
WHERE site_id = 2;
/*
Solved (Y/N):
*/

-- Q-9: Please, create 'churn' analysis by cohort of employees.
/*
I can't figure out how to create 'churn' analysis in this particular case having only 1 (one) timestamp :(
However, for practical purposes, I have tried to create a retention rate using the current date as the second timestamp.
*/
WITH cohorts AS(
		SELECT
			emp_id,
			MIN(DATE_TRUNC('month', hiring_date)) OVER (PARTITION BY emp_id) as cohort_month,
			EXTRACT(month FROM AGE(CURRENT_DATE, DATE_TRUNC('month', hiring_date))) as work_month
		FROM employees
		WHERE still_working = True							   
)
SELECT cohort_month, 
	SUM(CASE WHEN work_month = 12 THEN 1 ELSE 0 END) AS month_12,
	SUM(CASE WHEN work_month = 11 THEN 1 ELSE 0 END) AS month_11,
	SUM(CASE WHEN work_month = 10 THEN 1 ELSE 0 END) AS month_10,
	SUM(CASE WHEN work_month = 9 THEN 1 ELSE 0 END) AS month_9,
	SUM(CASE WHEN work_month = 8 THEN 1 ELSE 0 END) AS month_8,
	SUM(CASE WHEN work_month = 7 THEN 1 ELSE 0 END) AS month_7,
	SUM(CASE WHEN work_month = 6 THEN 1 ELSE 0 END) AS month_6,
	SUM(CASE WHEN work_month = 5 THEN 1 ELSE 0 END) AS month_5,
	SUM(CASE WHEN work_month = 4 THEN 1 ELSE 0 END) AS month_4,
	SUM(CASE WHEN work_month = 3 THEN 1 ELSE 0 END) AS month_3,
	SUM(CASE WHEN work_month = 2 THEN 1 ELSE 0 END) AS month_2,
	SUM(CASE WHEN work_month = 1 THEN 1 ELSE 0 END) AS month_1,
	SUM(CASE WHEN work_month = 0 THEN 1 ELSE 0 END) AS month_0
FROM cohorts
GROUP BY 1
ORDER BY 1;
/*
Solved (Y/N):
*/

-- Q-10: Per each department, give the highest and lowest salary.
WITH dep_salaries AS(
	SELECT 
		d.department_id,
		MAX(salary) OVER(PARTITION BY d.department_id ORDER BY s.salary) as max_salary,
		MIN(salary) OVER(PARTITION BY d.department_id ORDER BY s.salary) as min_salary	
	FROM department d
	JOIN employees e
		ON d.department_id = e.department_id
	JOIN salaries s
		ON e.emp_id = s.employee_id
)
SELECT 
	department_id,
	MAX(max_salary) as highest_salary,
	MIN(min_salary) as lowest_salary
FROM dep_salaries
GROUP BY 1
ORDER BY 1;
/*
Solved (Y/N):
*/
