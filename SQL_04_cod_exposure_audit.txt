
--- ============================================================
--- 4. "Cash on Confusion"
--- ============================================================

--- Audit the COD Field
--- a)Overall count, date range, and phantom amount
SELECT
  COUNT(*) AS shipments_with_phantom_cod,
  ROUND(SUM(cod_amount_kobo) / 100.0, 2) AS phantom_cod_amount_naira,
  TO_CHAR(MIN(created_at), 'YYYY-MM-DD') AS earliest_created_date,
  TO_CHAR(MAX(created_at), 'YYYY-MM-DD') AS latest_created_date
FROM logistics.shipments
WHERE cod_amount_kobo > 0
AND payment_method::text <> 'cod';

--- b)Monthly pattern
SELECT
  TO_CHAR(created_at, 'YYYY-MM') AS month,
  COUNT(*) AS shipments_with_phantom_cod,
  ROUND(SUM(cod_amount_kobo) / 100.0, 2) AS phantom_cod_amount_naira
FROM logistics.shipments
WHERE cod_amount_kobo > 0
AND payment_method::text <> 'cod'
GROUP BY TO_CHAR(created_at, 'YYYY-MM')
ORDER BY month;

--- c) Concentration by estination hub
SELECT 
  h.name AS hub_name,
  COUNT(*) AS total_shipments,
  COUNT(*) FILTER (WHERE s.cod_amount_kobo > 0 AND s.payment_method::text <> 'cod') AS shipments_with_phantom_cod,
  ROUND(SUM(s.cod_amount_kobo) FILTER (WHERE s.cod_amount_kobo > 0 AND s.payment_method::text <> 'cod') / 100.0, 2) AS phantom_cod_amount_naira,
  ROUND(100.0 * COUNT(*) FILTER (WHERE s.cod_amount_kobo > 0
  AND s.payment_method::text <> 'cod') / COUNT(*), 2) AS phantom_rate_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE s.cod_amount_kobo > 0
  AND s.payment_method::text <> 'cod') / SUM(COUNT(*) FILTER (WHERE s.cod_amount_kobo > 0 AND s.payment_method::text <> 'cod')) OVER (), 2) AS share_of_phantom_pct
FROM logistics.shipments s
LEFT JOIN logistics.hubs h 
ON h.hub_id = s.destination_hub_id
GROUP BY h.name
ORDER BY shipments_with_phantom_cod DESC;

--- d) Status-level split
SELECT 
  status,
  COUNT(*) AS phantom_shipments,
  ROUND(SUM(cod_amount_kobo) / 100.0, 2) AS phantom_amount_naira,
  ROUND(100.0 * SUM(cod_amount_kobo) / SUM(SUM(cod_amount_kobo)) OVER (), 2) AS pct_of_total_exposure
FROM logistics.shipments
WHERE cod_amount_kobo > 0
AND payment_method::text <> 'cod'
GROUP BY status
ORDER BY phantom_amount_naira DESC;



/*
Query Results

1 row
shipments_with_phantom_cod	phantom_cod_amount_naira	earliest_created_date	latest_created_date
62254	313907611.00	2020-01-01	2024-12-30

60 rows
month	shipments_with_phantom_cod	phantom_cod_amount_naira
2020-01	1041	5134813.00
2020-02	997	4999207.00
2020-03	1090	5432502.00
2020-04	1045	5281248.00
2020-05	1054	5302276.00
2020-06	1017	5167355.00
2020-07	1082	5410459.00
2020-08	1007	5218696.00
2020-09	1063	5476574.00
2020-10	1039	5183900.00
2020-11	1024	5275968.00
2020-12	1106	5458837.00
2021-01	1048	5152908.00
2021-02	944	4740562.00
2021-03	1033	5227901.00
2021-04	1051	5125399.00
2021-05	1004	5166002.00
2021-06	1010	5380513.00
2021-07	1022	5213560.00
2021-08	1041	5306357.00
2021-09	1028	5150414.00
2021-10	1081	5422628.00
2021-11	1026	5243553.00
2021-12	1041	5423172.00
2022-01	1079	5389379.00
2022-02	907	4426075.00
2022-03	1140	5608494.00
2022-04	1053	5437547.00
2022-05	1094	5544738.00
2022-06	1031	5236235.00
2022-07	1059	5251862.00
2022-08	1010	5027570.00
2022-09	1050	5183676.00
2022-10	1093	5679919.00
2022-11	950	4936069.00
2022-12	1051	5353161.00
2023-01	1019	5093116.00
2023-02	962	4767378.00
2023-03	1118	5738406.00
2023-04	943	4828464.00
2023-05	1063	5279172.00
2023-06	1074	5520023.00
2023-07	1062	5186908.00
2023-08	1053	5200428.00
2023-09	1033	5130758.00
2023-10	992	4866979.00
2023-11	983	4831565.00
2023-12	1093	5559431.00
2024-01	1071	5435325.00
2024-02	986	4835721.00

8 rows
hub_name	total_shipments	shipments_with_phantom_cod	phantom_cod_amount_naira	phantom_rate_pct	share_of_phantom_pct
FlowRoute Ibadan Hub	225152	7908	39877545.00	3.51	12.70
FlowRoute Enugu Hub	224664	7886	39627086.00	3.51	12.67
FlowRoute Port Harcourt Hub	224855	7808	39236275.00	3.47	12.54
FlowRoute Lagos Mega Hub	225641	7782	39096240.00	3.45	12.50
FlowRoute Benin City Hub	225225	7754	39170675.00	3.44	12.46
FlowRoute Kano Hub	224903	7747	39342575.00	3.44	12.44
FlowRoute Abuja Central Hub	224783	7731	38862519.00	3.44	12.42
FlowRoute Lagos Island Hub	224761	7638	38694696.00	3.40	12.27

7 rows
status	phantom_shipments	phantom_amount_naira	pct_of_total_exposure
delivered	44819	226172735.00	72.05
failed	6172	30822624.00	9.82
in_transit	4996	25360862.00	8.08
out_for_delivery	3110	15726248.00	5.01
returned	1251	6345608.00	2.02
created	1251	6269673.00	2.00
cancelled	655	3209861.00	1.02

What did I find?  
The raw database contains ₦313.9 Million in phantom COD amounts across 62,254 shipments. This is an active, 
ongoing software flaw (running at ~1,000 records/month since Jan 2020), spread perfectly evenly across all 8 hubs. 
However, the actual cash risk is much lower than it appears: 72% of this amount (₦226.1M) is already settled on 
delivered shipments. The genuine live cash exposure currently in the field (in_transit and out_for_delivery) is 
only ₦41 Million. Ibrahim is completely correct: the audit committee's massive figure is a reporting artifact of 
historical data-entry noise, not missing cash in his corridor.
*/


--- The True COD Position
--- a) Reported vs True Exposure and Overstatement (all-time)
SELECT
  ROUND(SUM(cod_amount_kobo) / 100.0, 2) AS reported_exposure_naira,
  ROUND(SUM(cod_amount_kobo) FILTER (WHERE payment_method::text = 'cod') / 100.0, 2) AS true_exposure_naira,
  ROUND((SUM(cod_amount_kobo)- SUM(cod_amount_kobo) FILTER (WHERE payment_method::text = 'cod')) / 100.0, 2) AS overstatement_naira,
  ROUND(100.0* (SUM(cod_amount_kobo) - SUM(cod_amount_kobo) FILTER (WHERE payment_method::text = 'cod')) / NULLIF(SUM(cod_amount_kobo), 0), 2)                               AS overstatement_pct,
  COUNT(*) FILTER (WHERE payment_method::text <> 'cod')AS phantom_shipment_count,
  TO_CHAR(MIN(created_at), 'YYYY-MM-DD') AS window_start,
  TO_CHAR(MAX(created_at), 'YYYY-MM-DD') AS window_end
FROM logistics.shipments
WHERE cod_amount_kobo > 0;

--- b) True Exposure by Status (delivered vs at-risk)
SELECT
  COALESCE(status_group, 'TOTAL') AS status_group,
  COUNT(*) AS true_cod_shipments,
  ROUND(SUM(cod_amount_kobo) / 100.0, 2) AS true_exposure_naira,
  CASE
    WHEN GROUPING(status_group) = 1 THEN NULL
    ELSE ROUND(100.0 * SUM(cod_amount_kobo) / SUM(SUM(cod_amount_kobo)) OVER (), 2)
  END AS pct_of_true_exposure
FROM (
  SELECT
    CASE
      WHEN status::text = 'delivered' THEN '1. Delivered (cash collected)'
      WHEN status::text IN ('in_transit', 'out_for_delivery', 'created', 'pending', 'picked_up') THEN '2. In-flight (cash at risk)'
      WHEN status::text IN ('failed', 'returned') THEN '3. Failed / returned (recovery question)'
      ELSE '4. Other: ' || status::text
    END AS status_group,
    cod_amount_kobo
  FROM logistics.shipments
  WHERE cod_amount_kobo > 0
    AND payment_method::text = 'cod'
) t
GROUP BY ROLLUP (status_group)
ORDER BY GROUPING(status_group), status_group;

--- c) True Exposure by Destination Hub
SELECT
  h.name AS destination_hub,
  h.city,
  COUNT(s.shipment_id) AS true_cod_shipments,
  ROUND(SUM(s.cod_amount_kobo) / 100.0, 2) AS true_exposure_naira,
  ROUND(100.0 * SUM(s.cod_amount_kobo) / SUM(SUM(s.cod_amount_kobo)) OVER (), 2) AS pct_of_true_exposure
FROM logistics.shipments s
JOIN logistics.hubs h ON s.destination_hub_id = h.hub_id
WHERE s.cod_amount_kobo > 0
AND s.payment_method::text = 'cod'
GROUP BY h.hub_id, h.name, h.city
ORDER BY true_exposure_naira DESC;


/*
Query Results

1 row
reported_exposure_naira	true_exposure_naira	overstatement_naira	overstatement_pct	phantom_shipment_count	window_start	window_end
54614098467.00	54300190856.00	313907611.00	0.57	62254	2020-01-01	2024-12-30

5 rows
status_group	true_cod_shipments	true_exposure_naira	pct_of_true_exposure
1. Delivered (cash collected)	388465	39091702959.00	36.00
2. In-flight (cash at risk)	81133	8155529277.00	7.51
3. Failed / returned (recovery question)	64688	6508453048.00	5.99
4. Other: cancelled	5473	544505572.00	0.50
TOTAL	539759	54300190856.00	NULL

8 rows
destination_hub	city	true_cod_shipments	true_exposure_naira	pct_of_true_exposure
FlowRoute Lagos Island Hub	Lagos	67592	6815304391.00	12.55
FlowRoute Lagos Mega Hub	Lagos	67782	6811963278.00	12.55
FlowRoute Benin City Hub	Benin City	67597	6811954032.00	12.54
FlowRoute Ibadan Hub	Ibadan	67529	6803675935.00	12.53
FlowRoute Port Harcourt Hub	Port Harcourt	67517	6788489409.00	12.50
FlowRoute Kano Hub	Kano	67490	6776924416.00	12.48
FlowRoute Abuja Central Hub	Abuja	67186	6761087232.00	12.45
FlowRoute Enugu Hub	Enugu	67066	6730792163.00	12.40

What did I find?  
The audit report claims a COD exposure of ₦54.61 Billion. The true COD exposure is ₦54.30 Billion. 
The report is overstated by ₦313.9 Million. While ₦313.9M is a large absolute number, it represents only a 0.57% 
error in the overall exposure. This overstatement is entirely due to the software flaw that logged COD amounts on
non-COD shipments.
*/


