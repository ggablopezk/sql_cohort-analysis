-- ## 0b_customers_by_cohort_year.SQL


WITH yearly_cohort AS (
    SELECT DISTINCT
    customerkey,
    cohort_year,
    EXTRACT(YEAR FROM orderdate) AS purchase_year
FROM cohort_analysis
)
  SELECT DISTINCT
  cohort_year,
  purchase_year,
  COUNT(*) OVER (PARTITION BY purchase_year, cohort_year) AS num_customers
FROM yearly_cohort
ORDER BY cohort_year, purchase_year