
--- ============================================================
--- 2. "Three Strikes"
--- ============================================================

--- Audit the Attempt Counts




/*
Query Results
4 rows


What did I find?  

*/


--- The Real Failure Rate

WITH failure_count AS (
  SELECT 
    COUNT(shipment_id) AS total_shipments,
    COUNT(shipment_id) FILTER (WHERE status = 'failed') AS raw_failed_count,
    COUNT(shipment_id) FILTER (WHERE status = 'failed' AND  delivery_attempts <= max_attempts)  AS corrected_failed_count
FROM logistics.shipments
)

SELECT 
  raw_failed_count,
  corrected_failed_count,
  raw_failed_count - corrected_failed_count AS ghost_shipments,
  ROUND(100.0 * raw_failed_count / total_shipments,2) AS raw_failed_rate,
  ROUND(100.0 * corrected_failed_count / total_shipments,2) AS corrected_failed_rate,
  ROUND(100.0 * (raw_failed_count - corrected_failed_count) / total_shipments, 2) AS gap_percentage_points
FROM failure_count;

/*
Query Results

1 rows
raw_failed_count	corrected_failed_count	ghost_shipments	raw_failed_rate	corrected_failed_rate	gap_percentage_points
179859	176412	3447	9.99	9.80	0.19

What did I find?  
The raw failure rate is 9.99%. After excluding 3,447 failed shipments with bugged attempt counts, the corrected rate is 9.80%.
A decrease of 0.19 percentage points.

*/





---------------------------------

--------------------------------------------------------------QUERY 1 under review

SELECT
    DATE_TRUNC('month', created_at)::date AS month,
    COUNT(*) AS violation_count
FROM logistics.shipments
WHERE delivery_attempts > max_attempts
GROUP BY 1
ORDER BY 1;

SELECT
    s.status::text AS status,
    h.name AS destination_hub,
    COUNT(*) AS violation_count
FROM logistics.shipments s
LEFT JOIN logistics.hubs h
    ON s.destination_hub_id = h.hub_id
WHERE s.delivery_attempts > s.max_attempts
GROUP BY 1, 2
ORDER BY violation_count DESC;


SELECT 
  COUNT(shipment_id) AS shipments_over_cap,
  TO_CHAR(MIN(created_at), 'YYYY-MM-DD') AS earliest_date,
  TO_CHAR(MAX(created_at), 'YYYY-MM-DD') AS latest_date
FROM logistics.shipments
WHERE delivery_attempts > max_attempts;

-----------------------------------------

-- 1. Headline count, date range
SELECT
    COUNT(*)                        AS violation_count,
    MIN(created_at::date)           AS earliest_created,
    MAX(created_at::date)           AS latest_created  -- This is your stopping date
FROM logistics.shipments
WHERE delivery_attempts > max_attempts;

-- 2. Monthly pattern  
SELECT
    DATE_TRUNC('month', created_at)::date AS month,
    COUNT(*)                              AS violation_count
FROM logistics.shipments
WHERE delivery_attempts > max_attempts
GROUP BY 1
ORDER BY 1;

-- 3. Status and hub spread (destination)
SELECT
    s.status::text      AS status,
    h.name              AS destination_hub,
    COUNT(*)            AS violation_count
FROM logistics.shipments s
LEFT JOIN logistics.hubs h ON s.destination_hub_id = h.hub_id
WHERE s.delivery_attempts > s.max_attempts
GROUP BY 1, 2
ORDER BY violation_count DESC;

-- 4. Origin hub spread (complement to query 3)
SELECT
    h.name   AS origin_hub,
    COUNT(*) AS violation_count
FROM logistics.shipments s
LEFT JOIN logistics.hubs h ON s.origin_hub_id = h.hub_id
WHERE s.delivery_attempts > s.max_attempts
GROUP BY 1
ORDER BY violation_count DESC;


-----------------------------------


WITH s AS (
  SELECT 
    status::text                         AS status,
    origin_hub_id,
    destination_hub_id,
    created_at,
    DATE_TRUNC('month', created_at)      AS month,
    (delivery_attempts > max_attempts)   AS over_cap
  FROM logistics.shipments
),

overall AS (
  SELECT 
    1 AS ord,
    '1. Overall'                         AS section,
    'all shipments'                      AS label,
    COUNT(*)                             AS total_shipments,
    COUNT(*) FILTER (WHERE over_cap)     AS over_cap,
    ROUND(100.0 * COUNT(*) FILTER (WHERE over_cap) / COUNT(*), 2) AS over_cap_pct,
    'earliest ' || TO_CHAR(MIN(created_at) FILTER (WHERE over_cap), 'YYYY-MM-DD')
      || ' | latest ' || TO_CHAR(MAX(created_at) FILTER (WHERE over_cap), 'YYYY-MM-DD') AS note
  FROM s
),

monthly_base AS (
  SELECT 
    month,
    COUNT(*)                                       AS t,
    COUNT(*) FILTER (WHERE over_cap)               AS o,
    MAX(created_at) FILTER (WHERE over_cap)        AS last_violation
  FROM s
  GROUP BY month
),

monthly AS (
  SELECT 
    2,
    '2. Monthly pattern (by year)',
    TO_CHAR(month, 'YYYY'),
    SUM(t)::bigint,
    SUM(o)::bigint,
    ROUND(100.0 * SUM(o) / SUM(t), 2),
    'MM=violations: ' || STRING_AGG(TO_CHAR(month, 'MM') || '=' || o, '  ' ORDER BY month)
      || ' | last violation ' || COALESCE(TO_CHAR(MAX(last_violation), 'YYYY-MM-DD'), 'none')
  FROM monthly_base
  GROUP BY TO_CHAR(month, 'YYYY')
),

by_status AS (
  SELECT 
    3,
    '3a. Status',
    status,
    COUNT(*),
    COUNT(*) FILTER (WHERE over_cap),
    ROUND(100.0 * COUNT(*) FILTER (WHERE over_cap) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE over_cap)
          / SUM(COUNT(*) FILTER (WHERE over_cap)) OVER (), 1) || '% of all violations'
  FROM s
  GROUP BY status
),

by_dest_hub AS (
  SELECT 
    4,
    '3b. Destination hub',
    h.name,
    COUNT(*),
    COUNT(*) FILTER (WHERE s.over_cap),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.over_cap) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.over_cap)
          / SUM(COUNT(*) FILTER (WHERE s.over_cap)) OVER (), 1) || '% of all violations'
  FROM s
  JOIN logistics.hubs h ON h.hub_id = s.destination_hub_id
  GROUP BY h.name
),

by_origin_hub AS (
  SELECT 
    5,
    '3c. Origin hub',
    h.name,
    COUNT(*),
    COUNT(*) FILTER (WHERE s.over_cap),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.over_cap) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.over_cap)
          / SUM(COUNT(*) FILTER (WHERE s.over_cap)) OVER (), 1) || '% of all violations'
  FROM s
  JOIN logistics.hubs h ON h.hub_id = s.origin_hub_id
  GROUP BY h.name
),

cutoff AS (
  SELECT 
    6,
    '4. Cutoff check',
    CASE WHEN created_at < DATE '2023-03-15' 
         THEN 'on/before 2023-03-14' 
         ELSE 'after 2023-03-14' END,
    COUNT(*),
    COUNT(*) FILTER (WHERE over_cap),
    ROUND(100.0 * COUNT(*) FILTER (WHERE over_cap) / COUNT(*), 2),
    NULL::text
  FROM s
  GROUP BY 3
)

SELECT section, label, total_shipments, over_cap, over_cap_pct, note
FROM (
  SELECT * FROM overall
  UNION ALL SELECT * FROM monthly
  UNION ALL SELECT * FROM by_status
  UNION ALL SELECT * FROM by_dest_hub
  UNION ALL SELECT * FROM by_origin_hub
  UNION ALL SELECT * FROM cutoff
) all_results
ORDER BY ord, label;