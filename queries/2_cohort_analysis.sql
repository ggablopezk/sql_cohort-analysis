-- ## 2_cohort_analysis.sql

WITH month_since_purchase AS (
SELECT
  first_purchase_date,
  cohort_year,
 (EXTRACT(YEAR FROM orderdate) - EXTRACT(YEAR FROM first_purchase_date)) * 12  +
 (EXTRACT(MONTH FROM orderdate) - EXTRACT(MONTH FROM first_purchase_date)) AS month_from_first_purchase,
 total_net_revenue
FROM cohort_analysis
), cohort_monthly_revenue AS (
SELECT
    month_from_first_purchase,
    cohort_year,
    SUM(total_net_revenue) AS net_revenue
FROM month_since_purchase
GROUP BY month_from_first_purchase, cohort_year
),
cohort_revenue AS (
SELECT
  cohort_year,
  SUM(total_net_revenue) AS client_ltv
FROM month_since_purchase
GROUP BY cohort_year
)
SELECT
  cr.cohort_year,
  month_from_first_purchase,
  net_revenue,
  cr.client_ltv,
  ROUND((net_revenue/client_ltv)::NUMERIC,3) AS pct_of_total_revenue
FROM cohort_monthly_revenue cm
INNER JOIN cohort_revenue cr ON cm.cohort_year = cr.cohort_year
ORDER BY cr.cohort_year, month_from_first_purchase;