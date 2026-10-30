--- ============================================================
--- 5. "The Time Travelers"
--- ============================================================

--- Find the time travelers
--- a) Total Impossible Shipments
SELECT  
  COUNT(*) AS impossible_shipment_count
FROM logistics.shipments
WHERE delivered_at < picked_up_at;

--- b) Impossible Shipments by Year
SELECT 
	EXTRACT(YEAR FROM picked_up_at) AS pickup_year,
    COUNT(*) AS impossible_shipment_count,
    MIN(picked_up_at)::date AS first_bad,
    MAX(picked_up_at)::date AS last_bad
FROM logistics.shipments
WHERE delivered_at < picked_up_at
GROUP BY 1 ORDER BY 1;

--- c) Missing Coordinates
SELECT 
	COUNT(*) FILTER (WHERE lat IS NULL OR lng IS NULL) AS missing_coordinates,
    COUNT(*) AS total_addresses,
    ROUND(100.0 * COUNT(*) FILTER (WHERE lat IS NULL OR lng IS NULL) / COUNT(*), 1) AS pct_missing
FROM logistics.delivery_addresses;

--- d) Average Transit Time: Include vs. Exclude
SELECT 
  COUNT(*) AS delivered_with_timestamps,
  COUNT(*) FILTER (WHERE delivered_at < picked_up_at) AS impossible_excluded,
  ROUND(AVG(EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600)::numeric, 2) AS avg_hrs_including,
  ROUND(AVG(EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600)
  FILTER (WHERE delivered_at >= picked_up_at)::numeric, 2) AS avg_hrs_excluding
FROM logistics.shipments
WHERE status::text = 'delivered'
AND picked_up_at IS NOT NULL AND delivered_at IS NOT NULL;

/*
Query Results

1 row
impossible_shipment_count
14372

3 rows
pickup_year	impossible_shipment_count	first_bad	last_bad
2020	5970	2020-01-01T00:00:00.000Z	2020-12-31T00:00:00.000Z
2021	5897	2021-01-01T00:00:00.000Z	2021-12-31T00:00:00.000Z
2022	2505	2022-01-01T00:00:00.000Z	2022-06-02T00:00:00.000Z

1 rows
missing_coordinates	total_addresses	pct_missing
55974	280000	20.0

1 rows
delivered_with_timestamps	impossible_excluded	avg_hrs_including	avg_hrs_excluding
1295890	12335	61.29	61.90

What did I find?  
I ran the audit. Here is the truth:
1. There are exactly 14,372 shipments with impossible timestamps (delivery before pickup). The year-over-year breakdown proves the bug's 
lifecycle: it was active at a steady rate of ~5,900 cases per year in 2020 and 2021, dropped to 2,505 in 2022 (because the fix was 
deployed mid-year). 2023 and 2024 return no rows in the year breakdown — their absence from the result set confirms zero impossible 
shipments after the fix.
2. Missing Coordinates: There are 55,974 delivery addresses missing lat/lng data.
3. Average Transit Time: The raw average is 61.29 hours. Excluding the impossible records, the corrected average is 61.90 hours. 
*/


--- The True COD Position
--- a) THE BOARD NUMBER (Average and Median)
SELECT 
  COUNT(*) AS included_shipments,
  ROUND(AVG(EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600)::numeric, 2) AS avg_transit_hrs,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600)::numeric, 2) AS median_transit_hrs
FROM logistics.shipments
WHERE status::text = 'delivered' AND picked_up_at IS NOT NULL AND delivered_at IS NOT NULL AND delivered_at >= picked_up_at;

--- b) BREAKDOWN BY ORIGIN HUB
SELECT 
  h.name AS origin_hub,
  COUNT(*) AS included_shipments,
  ROUND(AVG(EXTRACT(EPOCH FROM s.delivered_at - s.picked_up_at)/3600)::numeric, 2) AS avg_transit_hrs,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY EXTRACT(EPOCH FROM s.delivered_at - s.picked_up_at)/3600)::numeric, 2) AS median_transit_hrs
FROM logistics.shipments s
JOIN logistics.hubs h ON h.hub_id = s.origin_hub_id
WHERE s.status::text = 'delivered' AND s.picked_up_at IS NOT NULL AND s.delivered_at IS NOT NULL AND s.delivered_at >= s.picked_up_at
GROUP BY h.name
ORDER BY avg_transit_hrs DESC;

--- c) DATA-COVERAGE NOTE
SELECT 
  COUNT(*) AS total_delivered,
  COUNT(*) FILTER (WHERE picked_up_at IS NULL OR delivered_at IS NULL)  AS excluded_null_timestamp,
  COUNT(*) FILTER (WHERE delivered_at < picked_up_at) AS excluded_impossible,
  COUNT(*) FILTER (WHERE picked_up_at IS NOT NULL AND delivered_at IS NOT NULL AND delivered_at >= picked_up_at) AS included_shipments,
  ROUND(100.0 * COUNT(*) FILTER (WHERE picked_up_at IS NOT NULL AND delivered_at IS NOT NULL AND delivered_at >= picked_up_at) / COUNT(*), 2) AS data_coverage_pct
FROM logistics.shipments
WHERE status::text = 'delivered';


/*
Query Results

1 row
included_shipments	avg_transit_hrs	median_transit_hrs
1283555	61.90	61.86

8 rows
origin_hub	included_shipments	avg_transit_hrs	median_transit_hrs
FlowRoute Benin City Hub	160025	61.95	61.89
FlowRoute Lagos Island Hub	160367	61.92	61.77
FlowRoute Ibadan Hub	160455	61.92	61.89
FlowRoute Lagos Mega Hub	160517	61.90	62.02
FlowRoute Port Harcourt Hub	160106	61.90	61.98
FlowRoute Abuja Central Hub	160431	61.87	61.81
FlowRoute Enugu Hub	161299	61.87	61.83
FlowRoute Kano Hub	160355	61.84	61.73

1 row
total_delivered	excluded_null_timestamp	excluded_impossible	included_shipments	data_coverage_pct
1295890	0	12335	1283555	99.05

What did I find?  
The Board Number: The corrected average transit time is 61.90 hours with a median of 61.86 hours. 
Because the average and median are almost identical, we can trust that the number is not skewed by extreme outliers.
The Coverage: This number stands on 99.05% of all delivered shipments. We only excluded the 12,335 impossible timezone records, 
giving the board immense confidence in the metric.
The Hub Breakdown: I broke this down by origin_hub_id. The spread between the fastest hub (Benin City at 61.95 hours) and 
the slowest (Kano at 61.84 hours) the spread is only 0.11 hours. It proves there are no regional failures; the network is 
performing uniformly.
*/


