
--- ============================================================
--- 2. "Three Strikes"
--- ============================================================

--- Audit the Attempt Counts

--a). Headline count, date range
SELECT
    COUNT(*)                        AS violation_count,
    MIN(created_at::date)           AS earliest_created,
    MAX(created_at::date)           AS latest_created  -- This is your stopping date
FROM logistics.shipments
WHERE delivery_attempts > max_attempts;

--b). Monthly pattern  
SELECT
    DATE_TRUNC('month', created_at)::date AS month,
    COUNT(*)                              AS violation_count
FROM logistics.shipments
WHERE delivery_attempts > max_attempts
GROUP BY 1
ORDER BY 1;

--c). Status and hub spread (destination)
SELECT
    s.status::text      AS status,
    h.name              AS destination_hub,
    COUNT(*)            AS violation_count
FROM logistics.shipments s
LEFT JOIN logistics.hubs h ON s.destination_hub_id = h.hub_id
WHERE s.delivery_attempts > s.max_attempts
GROUP BY 1, 2
ORDER BY violation_count DESC;

-- d). Origin hub spread (complement to query 3)
SELECT
    h.name   AS origin_hub,
    COUNT(*) AS violation_count
FROM logistics.shipments s
LEFT JOIN logistics.hubs h ON s.origin_hub_id = h.hub_id
WHERE s.delivery_attempts > s.max_attempts
GROUP BY 1
ORDER BY violation_count DESC;


/*
Query Results
1 row
violation_count	earliest_created	latest_created
3447	2020-01-01T00:00:00.000Z	2023-03-14T00:00:00.000Z

39 rows
month	violation_count
2020-01-01T00:00:00.000Z	79
2020-02-01T00:00:00.000Z	89
2020-03-01T00:00:00.000Z	101
2020-04-01T00:00:00.000Z	79
2020-05-01T00:00:00.000Z	106
2020-06-01T00:00:00.000Z	88
2020-07-01T00:00:00.000Z	95
2020-08-01T00:00:00.000Z	92
2020-09-01T00:00:00.000Z	82
2020-10-01T00:00:00.000Z	93
2020-11-01T00:00:00.000Z	116
2020-12-01T00:00:00.000Z	96
2021-01-01T00:00:00.000Z	86
2021-02-01T00:00:00.000Z	78
2021-03-01T00:00:00.000Z	90
2021-04-01T00:00:00.000Z	82
2021-05-01T00:00:00.000Z	107
2021-06-01T00:00:00.000Z	94
2021-07-01T00:00:00.000Z	90
2021-08-01T00:00:00.000Z	103
2021-09-01T00:00:00.000Z	78
2021-10-01T00:00:00.000Z	81
2021-11-01T00:00:00.000Z	89
2021-12-01T00:00:00.000Z	86
2022-01-01T00:00:00.000Z	85
2022-02-01T00:00:00.000Z	83
2022-03-01T00:00:00.000Z	97
2022-04-01T00:00:00.000Z	83
2022-05-01T00:00:00.000Z	99
2022-06-01T00:00:00.000Z	76
2022-07-01T00:00:00.000Z	82
2022-08-01T00:00:00.000Z	88
2022-09-01T00:00:00.000Z	85
2022-10-01T00:00:00.000Z	105
2022-11-01T00:00:00.000Z	90
2022-12-01T00:00:00.000Z	91
2023-01-01T00:00:00.000Z	85
2023-02-01T00:00:00.000Z	77
2023-03-01T00:00:00.000Z	41

8 rows
status	destination_hub	violation_count
failed	FlowRoute Lagos Mega Hub	449
failed	FlowRoute Abuja Central Hub	440
failed	FlowRoute Lagos Island Hub	438
failed	FlowRoute Kano Hub	432
failed	FlowRoute Ibadan Hub	432
failed	FlowRoute Enugu Hub	425
failed	FlowRoute Benin City Hub	424
failed	FlowRoute Port Harcourt Hub	407

8 rows
origin_hub	violation_count
FlowRoute Port Harcourt Hub	451
FlowRoute Lagos Island Hub	450
FlowRoute Enugu Hub	441
FlowRoute Benin City Hub	438
FlowRoute Lagos Mega Hub	433
FlowRoute Kano Hub	422
FlowRoute Ibadan Hub	416
FlowRoute Abuja Central Hub	396

What did I find?  
There are exactly 3,447 shipments where the app logged more delivery attempts than the policy cap.The anomaly started on Jan 1, 2020, and the final record occurred on March 14, 2023.
The monthly trend shows a steady ~90 violations per month until it drops to 41 in March 2023, then disappears—proving the app fix date.
The violations are 100% tied to failed shipments and spread evenly across all 8 origin and destination hubs.
This confirms the extra attempts were a systemic software bug, not an operational failure by any specific hub or driver.
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
