-- ## 0a_revenue_by_cohort_year.sql


SELECT
    cohort_year,
    EXTRACT(YEAR FROM orderdate) AS purchase_year,
    SUM(total_net_revenue) AS net_revenue
FROM cohort_analysis
GROUP BY cohort_year, purchase_year
ORDER BY cohort_year, purchase_year;


