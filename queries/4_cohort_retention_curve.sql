-- ## 4_cohort_retention_curve.sql

WITH customer_month_activity AS (
SELECT
  cohort_year,
  customerkey,
 (EXTRACT(YEAR FROM orderdate) - EXTRACT(YEAR FROM first_purchase_date)) * 12  +
 (EXTRACT(MONTH FROM orderdate) - EXTRACT(MONTH FROM first_purchase_date)) AS month_from_first_purchase
FROM cohort_analysis
), cohort_customers AS (
SELECT
      cohort_year,
       COUNT(DISTINCT customerkey) AS cohort_size
FROM customer_month_activity
GROUP BY cohort_year
), cohort_month_customers AS (
SELECT 
  cohort_year,
  month_from_first_purchase,
  COUNT(DISTINCT customerkey) AS active_customers
FROM customer_month_activity
GROUP BY cohort_year, month_from_first_purchase
)
SELECT 
  c.cohort_year,
  m.month_from_first_purchase,
  ROUND((m.active_customers::NUMERIC/c.cohort_size::NUMERIC),3) AS retention_pct
FROM cohort_customers c
INNER JOIN cohort_month_customers m ON  c.cohort_year = m.cohort_year