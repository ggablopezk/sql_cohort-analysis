-- ## 1_2_customer_rfm


WITH customer_rfm_base AS (
SELECT
	  customerkey,
	  (SELECT MAX(orderdate) FROM cohort_analysis) - MAX(orderdate) AS recency_days,
	  SUM(num_orders) AS frequency,
	  SUM(total_net_revenue) AS monetary
FROM cohort_analysis
GROUP BY customerkey
),
customer_rfm_quartiles AS (
SELECT 
      customerkey,
      recency_days,
      frequency,
      monetary,
      NTILE(4) OVER (ORDER BY recency_days DESC) AS recency_quartile,
      NTILE(4) OVER (ORDER BY frequency ASC) AS frequency_quartile,
      NTILE(4) OVER (ORDER BY monetary ASC) AS monetary_quartile
FROM customer_rfm_base
)
SELECT 
	  customerkey,
	  recency_quartile,
	  frequency_quartile,
	  monetary_quartile,
	  CONCAT(recency_quartile, frequency_quartile, monetary_quartile) AS rfm_score
FROM customer_rfm_quartiles