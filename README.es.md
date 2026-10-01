# Análisis de cohortes, segmentación y retención de clientes con SQL

*[Read in English](README.md)*

Análisis en SQL (PostgreSQL) de las ventas de una empresa ficticia de retail/e-commerce, entre enero de 2015 y abril de 2024 (año parcial). El objetivo es responder tres preguntas de negocio: cómo segmentar a los clientes según su valor de vida (LTV, *lifetime value*) y su comportamiento de compra, cómo evoluciona cada cohorte (grupo de clientes según el año de su primera compra) en ingresos y retención, y qué clientes están en riesgo de abandono y requieren acciones de retención. Para responderlas se construyó una segmentación RFM completa (recencia, frecuencia y valor monetario), curvas de ingreso y retención por cohorte medidas en meses, un umbral de riesgo personalizado según el ritmo de compra de cada cliente y un cruce entre segmento y riesgo.

## Preguntas

| # | Pregunta | Técnica* |
|---|---|---|
| 0a | ¿Cuánto ingreso generaron los clientes de cada cohorte por año de compra? | `EXTRACT` + `GROUP BY` |
| 0b | ¿Cuántos clientes de cada cohorte compraron en cada año? | `SELECT DISTINCT` + `COUNT() OVER (PARTITION BY)` |
| 1.1 | ¿Qué porcentaje del LTV concentra cada segmento sobre el LTV total? | `PERCENTILE_CONT` + `CASE` + subquery para el total |
| 1.2 | ¿Cuál es el puntaje de cada cliente en cuanto a recencia, frecuencia y valor monetario? | `NTILE(4)` + `CONCAT` |
| 2 | ¿Qué porcentaje del ingreso total de cada cohorte se genera en cada mes de vida, contado desde su primera compra? | Aritmética de fechas con `EXTRACT` + `JOIN` a un total fijo por cohorte |
| 3 | ¿Cómo se puede categorizar el riesgo de los clientes según su ritmo habitual de compra? | `LAG` + `AVG` + `ROW_NUMBER` + `CASE` |
| 4 | ¿Qué porcentaje de los clientes de cada cohorte compra en cada mes transcurrido desde su primera compra? | `COUNT(DISTINCT)` + `JOIN` a un tamaño fijo por cohorte |
| 5 | ¿Qué porcentaje de clientes de cada segmento se encuentra en cada categoría de riesgo? | `JOIN` de CTEs + `SUM() OVER (PARTITION BY customer_segment)` |

\*Salvo la 0a, las consultas se organizan con CTEs.

## Datos

### Fuente

Contoso es el nombre de una empresa ficticia usada en ejemplos de Microsoft. Los datos de este análisis son sintéticos: los genera el [Contoso Data Generator V2 de SQLBI](https://github.com/sql-bi/Contoso-Data-Generator-V2) (licencia MIT). Se utilizó el archivo [`contoso_100k.sql`](https://github.com/lukebarousse/Int_SQL_Data_Analytics_Course/releases/download/v.0.0.0/contoso_100k.sql), un volcado para PostgreSQL publicado en el material del [curso de SQL intermedio de Luke Barousse](https://github.com/lukebarousse/Int_SQL_Data_Analytics_Course), cuyo autor indica que lo obtuvo de ese generador. El archivo no se incluye en este repositorio.

### Contenido

La base completa tiene seis tablas (`currencyexchange`, `date`, `store`, `customer`, `product` y `sales`); este análisis usa solo `sales` y `customer`.

- **`sales`:** una fila por línea de venta (`orderkey`, `customerkey`, `orderdate`, `quantity`, `netprice`, `exchangerate`).
- **`customer`:** datos de cada cliente (`customerkey`, `countryfull`, `age`, `givenname`, `surname`).

Las ventas van de enero de 2015 a abril de 2024 (año parcial) e involucran a 49.487 clientes. El ingreso neto de cada línea es `quantity * netprice * exchangerate`.

### Herramientas

- PostgreSQL local (versión 18)
- DBeaver Community, para ejecutar las consultas y exportar resultados
- Notebooks de Jupyter / Google Colab, para iterar las consultas antes de consolidarlas
- Python (matplotlib), para los gráficos, a partir de los CSV exportados

### Armado de la base

Se creó una base `contoso_100k` en PostgreSQL local y se cargó el archivo `contoso_100k.sql`. Después se ejecutó `queries/0_cohort_analysis_view.sql`, que crea la vista `cohort_analysis` (una fila por cliente y día de compra, con `first_purchase_date` y `cohort_year`). El resto de las consultas leen de esa vista y pueden ejecutarse en cualquier orden.

### Qué es del curso y qué es propio

El proyecto parte del esquema de tres preguntas del curso (segmentación, cohortes y retención) y lo extiende.

| Archivo | Origen |
|---|---|
| `0_cohort_analysis_view.sql` | Del curso, sin cambios |
| `0a`, `0b` | Del curso, adaptadas a la vista |
| `1_1_customer_segmentation.sql` | Base del curso |
| `1_2_customer_rfm.sql` | Propia: suma recencia y frecuencia a la segmentación por valor monetario |
| `2_cohort_analysis.sql` | Extensión propia: curva por cohorte y en meses, en lugar de por días y con todas las cohortes mezcladas |
| `3_customer_retention_analysis.sql` | Extensión propia: umbral de riesgo según el ritmo de cada cliente, en lugar de un corte fijo de 6 meses |
| `4_cohort_retention_curve.sql` | Propia |
| `5_segment_risk_crosstab.sql` | Propia |

## Hallazgos

### 1. Ingreso y clientes por cohorte y año de compra (0a, 0b)

![Ingreso por año de compra, apilado por cohorte](assets/01_revenue_by_cohort.png)

- **Ingreso total:** el pico ocurre en 2022 ($44,9M) y la caída en 2020 ($11,2M, ~65% menos que en 2019).
- Las cohortes 2015–2018 se mueven juntas (tomando como base 100 el ingreso de cada cohorte en 2019): ~30–36 en 2020 y ~127–140 en 2022. Pesa más el año calendario que la cohorte.
- Participación de la cohorte nueva en el ingreso: 100% en 2015, 54% en 2022 y 43% en 2023.
- Clientes de cohortes anteriores que compran en el año: 2.496 en 2019 y 7.378 en 2022.
- 2024 es un año parcial: solo hay registros hasta abril.

<details>
<summary>Ver SQL — <code>0a_revenue_by_cohort_year.sql</code></summary>

```sql
SELECT
    cohort_year,
    EXTRACT(YEAR FROM orderdate) AS purchase_year,
    SUM(total_net_revenue) AS net_revenue
FROM cohort_analysis
GROUP BY cohort_year, purchase_year
ORDER BY cohort_year, purchase_year;
```
</details>

<details>
<summary>Ver SQL — <code>0b_customers_by_cohort_year.sql</code></summary>

```sql
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
```
</details>

### 2. Segmentación por valor y RFM (1.1, 1.2)

- High-Value: 12.372 clientes, 65,6% del LTV, LTV promedio $10.946.
- Mid-Value: 24.743 clientes, 32,3% del LTV, LTV promedio $2.693.
- Low-Value: 12.372 clientes, 2,1% del LTV, LTV promedio $351.
- RFM: 64 combinaciones posibles; las más frecuentes son 111 (3.426 clientes) y 444 (2.848 clientes).

<details>
<summary>Ver SQL — <code>1_1_customer_segmentation.sql</code></summary>

```sql
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
)
SELECT 
  customer_segment,
  SUM(total_ltv) AS total_ltv,
  SUM(total_ltv)/ (SELECT SUM (total_ltv) FROM segment_values) AS ltv_pct,
  COUNT(customerkey) AS customer_count,
  SUM(total_ltv)/ COUNT(customerkey) AS avg_ltv
FROM segment_values 
GROUP BY customer_segment
ORDER BY total_ltv DESC;
```
</details>

<details>
<summary>Ver SQL — <code>1_2_customer_rfm.sql</code></summary>

```sql
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
```
</details>

### 3. Curva de ingreso por cohorte, en meses (2)

- El mes 0 concentra el 49% del LTV de la cohorte 2015 y el 98% de la 2024, pero se debe al horizonte temporal: la cohorte 2015 tiene 111 meses de historial de compras, mientras que la 2024 solo tiene 3.
- A igual horizonte (ingreso de los meses 1–12 sobre el del mes 0): ~4–10% en 2015–2017, ~11–17% en 2018–2019 y ~23% en 2021–2022.
- Las cohortes 2021–2022 repiten más en su primer año, pero ese año coincide con el pico de 2022.

<details>
<summary>Ver SQL — <code>2_cohort_analysis.sql</code></summary>

```sql
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
```
</details>

### 4. Retención y riesgo por cliente (3, 4)

![Retención mensual por cohorte](assets/03_retention_curve.png)

- **Query 3:** de 49.487 clientes, 55,7% tiene historial insuficiente (compraron en una sola ocasión), 34,3% Active y 10% At Risk.
- Entre los que se pueden evaluar (21.939), el 22,6% está At Risk.
- Mediana de días desde la última compra: 409 en Active, 1.374 en At Risk y 967 en historial insuficiente.
- **Query 4:** el mes 0 es 100% por construcción; después compra ~0,4–2% de la cohorte por mes, sin decaer. Promedio de los meses 1–12 en las cohortes 2015–2020: ~0,7%; hacia los meses 36–40, ~1,3%.
- El máximo de retención de cada cohorte cae alrededor de 2022 (mes 84 en la 2015, mes 41 en la 2019, mes 15 en la 2021): mismo efecto calendario que en el punto 1.

<details>
<summary>Ver SQL — <code>3_customer_retention_analysis.sql</code></summary>

```sql
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
```
</details>

<details>
<summary>Ver SQL — <code>4_cohort_retention_curve.sql</code></summary>

```sql
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
```
</details>

### 5. Cruce segmento × riesgo (5)

![Estado de riesgo dentro de cada segmento](assets/02_segment_risk.png)

- At Risk sube con el valor: 3% (Low), 11% (Mid), 15% (High).
- Pero cambia el peso de "historial insuficiente": 87%, 55% y 26%.
- Entre los evaluables, At Risk es 26% (Low), 23% (Mid) y 21% (High): los clientes valiosos no se fugan más que el resto.
- Accionable: 1.911 High-Value At Risk y 3.226 High-Value con un solo día de compra, de los que no hay datos suficientes para evaluar el riesgo.

<details>
<summary>Ver SQL — <code>5_segment_risk_crosstab.sql</code></summary>

```sql
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
```
</details>

## Limitaciones

- Contoso es un dataset de ejemplo: patrones como el pico de 2022 no necesariamente reflejan un negocio real.
- La fecha de referencia ("hoy") es la última del dataset, abril de 2024, no la fecha actual.
- El umbral de riesgo (×2 el intervalo habitual de compra) es un criterio ajustable, no una regla; dependerá de las necesidades del negocio.
- Las cohortes recientes tienen menos meses observados, lo que no necesariamente lleva a comparaciones justas.
- `NTILE` no resuelve empates: clientes con el mismo valor de frecuencia pueden caer en cuartiles distintos.
- El 56% de los clientes compró un solo día, así que el análisis de riesgo cubre menos de la mitad de la base.

## Conclusión

- Está evidenciado que se trata de un negocio de adquisición con poca recompra. El 56% de los clientes compró un solo día, y la retención mensual de las cohortes ronda el 0,7% sin decaer.
- El año calendario pesa más que la cohorte. 2020 cae para todas las cohortes y 2022 es el pico para todas, así que conviene separar cuándo se adquirió y cuándo se compró.
- El valor está concentrado: el 25% High-Value aporta el 65,6% del LTV, y el 25% Low-Value solo el 2,1%.
- Entre los clientes evaluables, el riesgo es parecido en los tres segmentos (21–26%).
- Lo accionable son los 1.911 High-Value At Risk y los 3.226 High-Value con un solo día de compra, que el método no puede evaluar.

## Qué me llevo de este proyecto

Lo más trabajoso fue encadenar CTEs y usar funciones de ventana. Estas fueron las complicaciones principales y cómo se resolvieron:

- **Porcentajes con un denominador fijo.** Para saber qué parte del ingreso de una cohorte cae en cada mes hace falta el total de esa cohorte. *Solución:* calcularlo en una CTE aparte y unirlo con `JOIN`.
- **Cálculos fila a fila y agrupados en la misma consulta.** `LAG` trabaja fila por fila y `AVG` agrupa por cliente. *Solución:* separarlos en dos CTEs encadenadas.
- **Filtrar el resultado de una función de ventana.** `WHERE` se ejecuta antes que la función de ventana. *Solución:* calcular `ROW_NUMBER()` en una CTE y filtrar `rn = 1` en la capa siguiente.
- **Clientes sin historial para evaluar.** Quienes compraron una sola vez no tienen un ritmo habitual de compra con el cual compararlos. *Solución:* clasificarlos aparte como "Historial insuficiente", en lugar de asumir que están activos.

Probar cada CTE por separado antes de encadenar la siguiente me llevó a evitar arrastrar errores entre capas.

## Estructura del repositorio

```
sql_cohort-analysis/
├── README.md
├── README.es.md
├── queries/
│   ├── 0_cohort_analysis_view.sql
│   ├── 0a_revenue_by_cohort_year.sql
│   ├── 0b_customers_by_cohort_year.sql
│   ├── 1_1_customer_segmentation.sql
│   ├── 1_2_customer_rfm.sql
│   ├── 2_cohort_analysis.sql
│   ├── 3_customer_retention_analysis.sql
│   ├── 4_cohort_retention_curve.sql
│   └── 5_segment_risk_crosstab.sql
└── assets/
    ├── 01_revenue_by_cohort.png
    ├── 02_segment_risk.png
    └── 03_retention_curve.png
```
