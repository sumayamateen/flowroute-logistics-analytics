--- ============================================================
--- 6. "The Board Pack"
--- ============================================================

--- The Corrected Numbers, in One Place
--- a) THE REAL FAILURE RATE
-- Correction: Excludes ghost records (the pre-June-2022 app bug)
-- where the app logged more delivery attempts than the max allowed.
SELECT 
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / COUNT(*), 2) AS raw_failure_rate_pct,
    ROUND( 100.0 * COUNT(*) FILTER (WHERE status = 'failed' AND delivery_attempts <= max_attempts) / COUNT(*), 2) AS corrected_failure_rate_pct
FROM logistics.shipments;

--- b) THE WEIGHT LEAKAGE
-- Correction: Only counts shipments where actual weight > 20% over declared.
-- Amounts are stored in kobo, so we divide by 100 to get Naira.
SELECT 
    COUNT(*) AS under_declared_shipments,
    ROUND(SUM(
        (shipping_fee_kobo * ((actual_weight_kg - declared_weight_kg) / declared_weight_kg)) / 100.0
    )::numeric, 2) AS revenue_gap_naira
FROM logistics.shipments
WHERE 
    actual_weight_kg > declared_weight_kg * 1.20
    AND actual_weight_kg IS NOT NULL;

--- c) THE HONEST COD POSITION
-- Correction: Isolates genuine COD. Quantifies the phantom amounts 
-- recorded on non-COD (prepaid) shipments separately.
SELECT 
    ROUND(SUM(cod_amount_kobo) FILTER (WHERE payment_method::text = 'cod') / 100.0, 2) AS true_cod_exposure_naira,
    ROUND(SUM(cod_amount_kobo) FILTER (WHERE payment_method::text <> 'cod') / 100.0, 2) AS phantom_cod_naira
FROM logistics.shipments
WHERE cod_amount_kobo > 0;

--- d) THE SERVICE NUMBER
-- Correction: Excludes impossible records (delivery before pickup).
SELECT  
  ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 3600)::numeric, 2) AS corrected_avg_transit_hours,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 3600)::numeric, 2) AS corrected_median_transit_hours,
  COUNT(*) AS included_shipments,
  (SELECT COUNT(*) FROM logistics.shipments WHERE status = 'delivered') AS total_delivered_shipments,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM logistics.shipments WHERE status = 'delivered'), 2) AS data_coverage_pct
FROM logistics.shipments
WHERE 
  status = 'delivered' 
  AND delivered_at IS NOT NULL 
  AND picked_up_at IS NOT NULL
  AND delivered_at >= picked_up_at;



/*
Query Results

1 row
raw_failure_rate_pct	corrected_failure_rate_pct
9.99	9.80

1 row
under_declared_shipments	revenue_gap_naira
323752	760898151.00

1 row
true_cod_exposure_naira	phantom_cod_naira
54300190856.00	313907611.00

1 row
corrected_avg_transit_hours	corrected_median_transit_hours	included_shipments	total_delivered_shipments	data_coverage_pct
61.90	61.86	1283555	1295890	99.05

What did I find?  
1. Failure Rate: 9.99% raw failure rate pct and  9.80% corrected failure rate pct
2. Weight Leakage: We found 323,752 under-declared shipments (where actual weight exceeded declared by >20%). 
The total revenue gap is ₦760.9 Million.
3. COD Position: True COD exposure is ₦54.3 Billion. We identified ₦313.9 Million in 'phantom' COD amounts that
were incorrectly logged on non-COD shipments.
4. Service Time: The corrected average transit time is 61.90 hours (median 61.86). This number is backed by 99.05% 
of all delivered shipments, making it statistically bulletproof.
All corrections are baked into the SQL logic. These are the exact numbers to put in front of the board."
*/


--- Raw vs Corrected, The Bridge
WITH BaseNumbers AS (
    SELECT 
        -- 1. Failure Rate
        COUNT(*) FILTER (WHERE status = 'failed') AS raw_fails,
        COUNT(*) FILTER (WHERE status = 'failed' AND delivery_attempts <= max_attempts) AS corrected_fails,
        COUNT(*) AS total_shipments,
        
        -- 2. Weight Leakage
        SUM((shipping_fee_kobo * ((actual_weight_kg - declared_weight_kg) / declared_weight_kg)) / 100.0) FILTER (WHERE actual_weight_kg > declared_weight_kg) AS raw_weight_leak,
        SUM((shipping_fee_kobo * ((actual_weight_kg - declared_weight_kg) / declared_weight_kg)) / 100.0) FILTER (WHERE actual_weight_kg > declared_weight_kg * 1.20) AS corrected_weight_leak,
        
        -- 3. COD
        SUM(cod_amount_kobo) / 100.0 AS raw_cod,
        SUM(cod_amount_kobo) FILTER (WHERE payment_method::text = 'cod') / 100.0 AS corrected_cod,
        
        -- 4. Transit
       AVG(EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600) FILTER (WHERE status = 'delivered' AND picked_up_at IS NOT NULL AND delivered_at IS NOT NULL)::numeric AS raw_transit,
       AVG(EXTRACT(EPOCH FROM delivered_at - picked_up_at)/3600) FILTER (WHERE status = 'delivered' AND picked_up_at IS NOT NULL AND delivered_at IS NOT NULL AND delivered_at >= picked_up_at)::numeric AS corrected_transit
    FROM logistics.shipments
)
SELECT '1. Failure Rate' AS metric, 
       ROUND(100.0 * raw_fails / total_shipments, 2)::text || '%' AS raw_system, 
       ROUND(100.0 * corrected_fails / total_shipments, 2)::text || '%' AS corrected, 
       ROUND((100.0 * raw_fails / total_shipments) - (100.0 * corrected_fails / total_shipments), 2)::text || ' pp' AS difference,
       'Excludes ghost records where delivery_attempts > max_attempts' AS correction_note
FROM BaseNumbers

UNION ALL

SELECT '2. Weight Revenue Gap', 
       '₦' || TO_CHAR(ROUND(raw_weight_leak, 0), 'FM999,999,999,999'), 
       '₦' || TO_CHAR(ROUND(corrected_weight_leak, 0), 'FM999,999,999,999'), 
       '₦' || TO_CHAR(ROUND(raw_weight_leak - corrected_weight_leak, 0), 'FM999,999,999,999'),
       'Applies strict >20% threshold (filters scale/packaging noise)'
FROM BaseNumbers

UNION ALL

SELECT '3. COD Position', 
       '₦' || TO_CHAR(ROUND(raw_cod, 0), 'FM999,999,999,999'), 
       '₦' || TO_CHAR(ROUND(corrected_cod, 0), 'FM999,999,999,999'), 
       '₦' || TO_CHAR(ROUND(raw_cod - corrected_cod, 0), 'FM999,999,999,999'),
       'Removes phantom COD amounts on non-COD shipments'
FROM BaseNumbers

UNION ALL

SELECT '4. Avg Transit Time', 
       ROUND(raw_transit, 1)::text || ' hrs', 
       ROUND(corrected_transit, 1)::text || ' hrs', 
       ROUND(corrected_transit - raw_transit, 1)::text || ' hrs',
       'Excludes impossible negative timestamps (delivery before pickup)'
FROM BaseNumbers;

/*
Query Results

4 rows
metric	raw_system	corrected	difference	correction_note
1. Failure Rate	9.99%	9.80%	0.19 pp	Excludes ghost records where delivery_attempts > max_attempts
2. Weight Revenue Gap	₦1,017,389,258	₦760,898,151	₦256,491,107	Applies strict >20% threshold (filters scale/packaging noise)
3. COD Position	₦54,614,098,467	₦54,300,190,856	₦313,907,611	Removes phantom COD amounts on non-COD shipments
4. Avg Transit Time	61.29 hrs	61.90 hrs	0.6 hrs	Excludes impossible negative timestamps (delivery before pickup)

What did I find?  
Failure Rate: The system overstated our failure rate by nearly 0.2 percentage points (9.99% down to 9.80%). 
This is because of the 3,447 "ghost records" where the app logged extra delivery attempts.
Weight Revenue Gap: The system overstated the recoverable revenue by ₦256.5 Million. (The raw number is ₦1.02B, 
but once we apply the strict 20% threshold to ignore scale noise, the true recoverable amount is ₦760.9M).
COD Position: The system overstated our cash exposure by ₦313.9 Million. (The raw exposure is ₦54.6B, but once 
we strip out the phantom COD amounts mistakenly logged on prepaid shipments, the true position is ₦54.3B).
Average Transit Time: The system understated our transit time by 0.6 hours. (The raw number is 61.3 hrs, but 
when we remove the impossible negative "time-travel" records, the true average is 61.9 hrs).
*/


