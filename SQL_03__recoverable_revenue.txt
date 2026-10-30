
--- ============================================================
--- 3. "The Weight of It"
--- ============================================================

--- Size the Under-Declaration
--- Note: A shipment counts as under-declared when the hub scale reading exceeds the declared weight by more than 20%. 
--- Note: shortfall = fee × (actual − declared) / declared, kobo → naira

SELECT 
  c.customer_type,
  COUNT(s.shipment_id) FILTER (WHERE s.actual_weight_kg > s.declared_weight_kg * 1.20) AS under_declared,
  ROUND(100.0 * (COUNT(s.shipment_id) FILTER (WHERE s.actual_weight_kg > s.declared_weight_kg * 1.20)) / (COUNT(s.shipment_id)),2)  AS share,
  ROUND(SUM(s.shipping_fee_kobo * ((s.actual_weight_kg - s.declared_weight_kg) / s.declared_weight_kg)) FILTER (WHERE s.actual_weight_kg > s.declared_weight_kg * 1.20) / 100.0,2) AS shortfall_naira
FROM logistics.shipments s
INNER JOIN logistics.customers c 
ON s.sender_customer_id = c.customer_id
WHERE actual_weight_kg IS NOT NULL 
AND c.customer_id IS NOT NULL
GROUP BY customer_type


/*
Query Results

2 rows
customer_type	under_declared	share	shortfall_naira
business	90428	20.66	213159306.65
individual	233324	20.72	547738844.35

What did I find?  
Under-declaration is a systemic issue affecting exactly 20.7% of all weighed shipments, regardless of customer type. 
However, individual customers are the biggest financial drain: while their rate of under-declaring (20.72%) is identical 
to businesses, they account for ₦547.7M of the ₦760.8M total leakage. Business accounts are only responsible for 28% of 
the lost revenue.
*/


--- The Recoverable Window

WITH latest_record AS (
    SELECT MAX(created_at) AS latest_date
    FROM logistics.shipments
),
under_declared AS (
    SELECT
        c.customer_type,
        h.name AS origin_hub,
        s.shipment_id,
        s.shipping_fee_kobo,
        s.actual_weight_kg,
        s.declared_weight_kg,
        s.shipping_fee_kobo * ((s.actual_weight_kg - s.declared_weight_kg) / s.declared_weight_kg) / 100.0 AS recoverable_naira   
    FROM logistics.shipments s
    JOIN logistics.customers c
    ON s.sender_customer_id = c.customer_id
    INNER JOIN logistics.hubs h
    ON s.origin_hub_id = h.hub_id
    CROSS JOIN latest_record lr
    WHERE s.actual_weight_kg IS NOT NULL
      AND s.actual_weight_kg > s.declared_weight_kg * 1.20
      AND s.created_at >= lr.latest_date - INTERVAL '12 months'
      AND s.created_at <= lr.latest_date
)
SELECT
    customer_type,
    origin_hub,
    COUNT(*) AS under_declared_shipments,
    ROUND(SUM(recoverable_naira), 2) AS recoverable_naira
FROM under_declared
GROUP BY customer_type, origin_hub
ORDER BY recoverable_naira DESC;

/*
Query Results

16 rows
customer_type	origin_hub	under_declared_shipments	recoverable_naira
individual	FlowRoute Kano Hub	5820	13956687.59
individual	FlowRoute Lagos Mega Hub	5844	13880061.76
individual	FlowRoute Abuja Central Hub	5860	13813328.59
individual	FlowRoute Ibadan Hub	5904	13736214.91
individual	FlowRoute Port Harcourt Hub	5790	13663907.90
individual	FlowRoute Lagos Island Hub	5840	13651262.93
individual	FlowRoute Enugu Hub	5818	13613956.13
individual	FlowRoute Benin City Hub	5742	13392421.90
business	FlowRoute Enugu Hub	2321	5515215.70
business	FlowRoute Lagos Mega Hub	2360	5513224.60
business	FlowRoute Port Harcourt Hub	2279	5414669.75
business	FlowRoute Abuja Central Hub	2258	5391035.64
business	FlowRoute Kano Hub	2226	5193406.10
business	FlowRoute Benin City Hub	2186	5177899.92
business	FlowRoute Ibadan Hub	2204	5173586.32
business	FlowRoute Lagos Island Hub	2221	5163515.25

What did I find?  
In the latest 12-month window, individuals are the largest recovery opportunity across all eight origin hubs. 
Individual segments each show approximately ₦13.39 million–₦13.96 million in estimated recoverable fees, compared 
with approximately ₦5.16 million–₦5.52 million for business segments. Within each customer type, leakage is spread 
nearly evenly across all eight hubs — no single origin hub stands out as a concentration point, so recovery rollout 
should be hub-agnostic.
*/
