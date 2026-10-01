-- ## 5_segment_risk_crosstab.sql

WITH customer_ltv AS (
    SELECT
        customerkey,
        SUM(total_net_revenue) AS total_ltv
    FROM cohort_analysis
    GROUP BY customerkey
),

customer_segments AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_ltv) AS percentile_25th,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_ltv) AS percentile_75th
    FROM customer_ltv
),

segment_values AS (
    SELECT
        c.customerkey,
        c.total_ltv,
        CASE
            WHEN c.total_ltv < percentile_25th THEN '1 - Low-Value'
            WHEN c.total_ltv BETWEEN percentile_25th AND percentile_75th THEN '2 - Mid-Value'
            ELSE '3 - High-Value'
        END AS customer_segment
    FROM customer_ltv c, customer_segments
),

days_prev_purchase AS (
    SELECT
        customerkey,
        orderdate,
        LAG(orderdate) OVER (PARTITION BY customerkey ORDER BY orderdate) AS previous_orderdate,
        (orderdate - LAG(orderdate) OVER (PARTITION BY customerkey ORDER BY orderdate))
            AS days_since_prev_purchase
    FROM cohort_analysis
),

avg_prev_purchase AS (
    SELECT
        customerkey,
        AVG(days_since_prev_purchase) AS avg_days_prev_purchase
    FROM days_prev_purchase
    GROUP BY customerkey
),

row_num AS (
    SELECT
        customerkey,
        orderdate,
        ROW_NUMBER() OVER (PARTITION BY customerkey ORDER BY orderdate DESC) AS rn
    FROM days_prev_purchase
),

max_diff AS (
    SELECT
        customerkey,
        (SELECT MAX(orderdate) FROM cohort_analysis) - orderdate AS days_diff_date
    FROM row_num
    WHERE rn = 1
),

risk_category AS (
    SELECT
        m.customerkey,
        days_diff_date,
        CASE
            WHEN avg_days_prev_purchase IS NULL THEN 'Insufficient History'
            WHEN days_diff_date > avg_days_prev_purchase * 2 THEN 'At Risk'
            ELSE 'Active'
        END AS client_risk
    FROM max_diff m
    INNER JOIN avg_prev_purchase a ON m.customerkey = a.customerkey
),

segment_risk AS (
    SELECT
        s.customer_segment,
        r.client_risk,
        COUNT(s.customerkey) AS client_count
    FROM segment_values s
    INNER JOIN risk_category r ON s.customerkey = r.customerkey
    GROUP BY s.customer_segment, r.client_risk
)

SELECT
    customer_segment,
    client_risk,
    client_count,
    SUM(client_count) OVER (PARTITION BY customer_segment) AS segment_total,
    ROUND(
        client_count::NUMERIC / SUM(client_count) OVER (PARTITION BY customer_segment)::NUMERIC,
        3
    ) AS segment_pct
FROM segment_risk
ORDER BY customer_segment, client_count DESC;