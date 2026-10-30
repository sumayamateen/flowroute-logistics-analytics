
--- ============================================================
--- 1. "The Complaint Spike"
--- ============================================================

--- Count the Complaints

SELECT 
  category,
  COUNT(*) AS total_complaints,
  SUM(COUNT(*)) OVER() AS grand_total,
  ROUND((COUNT(*)* 100.0) / SUM(COUNT(*)) OVER(), 2) AS percentage_of_total
FROM logistics.complaints
GROUP BY category
ORDER BY percentage_of_total DESC;


/*
Query Results

4 rows
category	total_complaints	grand_total	percentage_of_total
lost	16,551	64,737	25.57
wrong_address	16,142	64,737	24.93
late_delivery	16,080	64,737	24.84
damaged	15,964	64,737	24.66

What did I find?  
Lost is the most common complaint category, accounting for 25.57% of all complaints (16,551). 
However, complaints are distributed fairly evenly across all four categories, with percentages ranging from 24.66% to 25.57%.
*/


--- The Worst Hubs

WITH complaints_count AS (
  SELECT 
    s.destination_hub_id,
    COUNT(C.complaint_id) AS total_compliants

  FROM logistics.shipments s
  LEFT JOIN logistics.complaints c
  ON s.shipment_id = c.shipment_id
  GROUP BY s.destination_hub_id
)

SELECT 
  h.name,
  h.city,
  hp.total_shipments,
  hp.delivered AS delivered_count,
  hp.failed AS failed_count,
  hp.delivery_rate_pct,
  total_compliants,
  ROUND((cc.total_compliants * 1000.0) / hp.total_shipments,2)  AS complaints_per_1000

FROM logistics.hubs h
INNER JOIN logistics.v_hub_performance hp
ON h.hub_id = hp.hub_id
INNER JOIN complaints_count cc 
ON hp.hub_id = cc.destination_hub_id

ORDER BY hp.delivery_rate_pct ASC;

/*
Query Results

8 rows
name	city	total_shipments	delivered_count	failed_count	delivery_rate_pct	total_compliants	complaints_per_1000
FlowRoute Benin City Hub	Benin City	224696	161559	22444	71.90	8044	35.80
FlowRoute Abuja Central Hub	Abuja	225288	162009	22711	71.91	8066	35.80
FlowRoute Port Harcourt Hub	Port Harcourt	224620	161650	22546	71.97	8048	35.83
FlowRoute Lagos Mega Hub	Lagos	225148	162055	22460	71.98	8139	36.15
FlowRoute Lagos Island Hub	Lagos	224723	161851	22421	72.02	8118	36.12
FlowRoute Ibadan Hub	Ibadan	224946	162024	22473	72.03	8210	36.50
FlowRoute Kano Hub	Kano	224662	161914	22266	72.07	8043	35.80
FlowRoute Enugu Hub	Enugu	225901	162828	22538	72.08	8069	35.72

What did I find?  
No single hub stands out. Delivery rates are virtually identical across all 8 cities (ranging only from 71.90% to 72.08%),
and complaint rates per 1,000 shipments are similarly flat (35.7 to 36.5). Because the differences are within a fraction 
of a percent, blaming a specific hub would be statistical noise. The problem is systemic across the entire network.
*/
