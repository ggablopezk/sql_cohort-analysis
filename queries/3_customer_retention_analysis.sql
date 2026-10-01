-- ## 3_customer_retention_analysis.sql

WITH days_prev_purchase AS (
SELECT
	customerkey,
	orderdate,
	LAG(orderdate) OVER (PARTITION BY customerkey ORDER BY orderdate) AS previous_orderdate,
	(orderdate - LAG(orderdate) OVER (PARTITION BY customerkey ORDER BY orderdate)) AS days_since_prev_purchase
FROM cohort_analysis
), avg_prev_purchase AS (
SELECT
	customerkey,
	AVG(days_since_prev_purchase) AS avg_days_prev_purchase
FROM days_prev_purchase
GROUP BY customerkey
), row_num AS (
SELECT
	customerkey,
	orderdate,
	ROW_NUMBER() OVER (PARTITION BY customerkey ORDER BY orderdate DESC) AS rn
FROM days_prev_purchase
), max_diff AS(
SELECT
	customerkey,
	(SELECT MAX(orderdate) FROM cohort_analysis) - orderdate AS days_diff_date
FROM row_num
WHERE rn = 1
)
SELECT
	m.customerkey,
	days_diff_date,
-- Threshold: flagged 'At Risk' once a customer's gap since last purchase
-- exceeds double their own historical average gap between purchases.
	CASE
		WHEN avg_days_prev_purchase IS NULL THEN 'Insufficient History'
		WHEN days_diff_date > avg_days_prev_purchase * 2 THEN 'At Risk'
		ELSE 'Active'
	END AS client_risk
FROM max_diff m
INNER JOIN avg_prev_purchase a ON m.customerkey = a.customerkey