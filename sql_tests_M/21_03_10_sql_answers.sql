--Q-1: How many employees there are in the company?
SELECT 
	COUNT(DISTINCT emp_id) num_employees
FROM employees;
/*
Solved (Y/N):
*/

-- Q-2: How many employees there are per earch rank?
SELECT 
	emp_rank,
	COUNT(emp_id) AS num_employees	
FROM employees
GROUP BY 1;
/*
Solved (Y/N):
*/

-- Q-3: What is the median salary?
/*
The source I used to solve this task: Calculating Percentile (and Median) in PostgreSQL
https://leafo.net/guides/postgresql-calculating-percentile.html#calculating-the-median
*/
-- A: per each department? 
WITH salary_department AS(
SELECT 
	d.department_id,
	d.department_name,
	s.salary
FROM department d
JOIN employees e USING (department_id)
JOIN salaries s
	ON e.emp_id = s.employee_id
)
SELECT
  	department_id,
	department_name,
	PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY salary) as median_salary
FROM salary_department
GROUP BY 1, 2;

-- B: What is the median salary per each site?
WITH salary_department AS(
	SELECT 
		st.site_id,
		s.salary
	FROM salaries s
	JOIN employees e
		ON s.employee_id = e.emp_id
	JOIN department d USING (department_id)
	JOIN sites st USING (site_id)
)	
SELECT site_id,
	PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY salary) as median_salary
FROM salary_department
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
	st.site_cost + s.salary as total_expenses
FROM sites st
JOIN department d
	ON st.site_id = d.site_id
JOIN employees e
	ON d.department_id = e.department_id
JOIN salaries s
	ON e.emp_id = s.employee_id
)
SELECT 
	site_id,
	MAX(total_expenses) OVER (PARTITION BY site_id)
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
		COUNT(DISTINCT emp_id) as num_emp
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
	COUNT(DISTINCT emp_id) as num_hired_emp
FROM employees
WHERE DATE_PART('year', hiring_date) = '2020'
GROUP BY 1
ORDER BY 1;
/*
Solved (Y/N):
*/

-- Q-8: What is the salary share of site #112 out of total salaries?
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
WHERE site_id = 112;
/*
Solved (Y/N):
*/

-- Q-9: Please, create 'churn' analysis by cohort of employees.
/*
To solve the task, we can take the month of hiring_date as a cohort.
And we can calculate the employee churn as:
(num_employed - num_employees in the next month) / num_employed.
NB! the last row will containe null value in churn rate.
*/
WITH emp_hiring AS(
		SELECT
			DISTINCT emp_id,
			MIN(DATE_TRUNC('month', hiring_date)) OVER (PARTITION BY emp_id) as cohort_month,
			still_working = true
		FROM employees
)
  	, emp_cohorts AS(
SELECT 
	DISTINCT cohort_month,
	COUNT(emp_id) OVER (PARTITION BY cohort_month ORDER BY cohort_month) as num_employed
FROM emp_hiring
ORDER BY 1		
)
SELECT *,	
	LEAD(num_employed, 1) OVER (ORDER BY num_employed) as num_empl_end_month,
 	ROUND((num_employed - LEAD(num_employed, 1) OVER (ORDER BY num_employed)) / num_employed  * 100, 2) as churn_rate
FROM emp_cohorts;

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
