# FlowRoute Logistics: Business Insights and Recommendations

**Project type:** Simulation project (DataSimHQ), not client work
**Tools:** PostgreSQL, Power BI, Excel
**Data:** 1.8M shipments, 8 hubs, Jan 2020 to Dec 2024 (simulated)
**Conventions:** money in naira (converted from kobo), "pp" means percentage points, every figure states its population and window.

---

## 1. Business problem

Complaints were reported to have risen for three months, and the board wanted answers. Leadership could not tell whether the cause was a real operational failure, a specific hub, financial leakage, or errors in the data itself.

## 2. Executive summary

- **No hub, complaint category or customer type is an outlier in any analysis.** The problem is systemic, so the fixes are process and system changes, not action against particular sites or customer groups.
- **The ~10% failure rate is real.** A driver-app defect inflated it by only 0.19 pp.
- **Three data errors were found, dated and sized.** All are small (0.19 pp, 0.58%, 0.61 hrs), and none explains the complaints.
- **The larger risks are hidden by the standard reports:** shipments stuck "in flight" for months, and delivered cash-on-delivery (COD) with no matching cash receipt.
- **The complaint "spike" itself was not confirmed.** Monthly complaint volume looked flat. I did not complete the rate-per-1,000-shipments-by-month check, so this is listed as an open item.

## 3. The real business problem

The question the board asked was whether complaints were caused by a bad hub, financial leakage, data errors or real operational failure. The analysis shows the real problem is none of the first three. It is a **systemic weakness in how shipments are completed and recorded across the whole network**:

- Only **72.0%** of shipments reach `delivered`. About **10%** fail, and the rest are in flight, returned, created or cancelled.
- **95% of "in-flight" shipments (256,625) are over 90 days old.** They are stuck, lost or never updated, not in transit.
- Customer complaints are about **25% lost, 25% late delivery, 25% wrong address and 25% damaged**, at about 36 per 1,000 shipments at every hub.
- Internal reports do not reconcile with each other. Recorded COD includes amounts on failed, returned, cancelled and stuck parcels, and 74% of delivered COD has no matching receipt. This hides the true position from the board.
- These problems are **the same at every hub, for every customer type and in every year**, so they come from process and system design, not from a specific site, group or person.

**What I could not confirm:** whether complaints actually rose in the last three months. Monthly complaint volume looked flat, and I did not complete the complaint-rate-by-month check. The most accurate statement is: *"The data shows a steady, high complaint rate driven by a steady, high rate of non-delivery. It does not yet show a recent spike."*

## 4. Hypotheses: confirmed, rejected or not tested

| # | Hypothesis | Verdict | Evidence |
|---|---|---|---|
| 1 | A specific hub is underperforming | **Rejected** | Delivery rate 71.90% to 72.08%; complaints 35.7 to 36.5 per 1,000; transit differs by 0.07 hrs; no hub stands out in any finding |
| 2 | One complaint category dominates | **Rejected** | Categories range 24.7% to 25.6% |
| 3 | Business accounts cause the weight leakage | **Rejected** | Same under-declaration rate (20.66% vs 20.72%) and same ₦ per parcel (about ₦2,350) as individuals |
| 4 | Missing delivery-address coordinates cause failed deliveries | **Rejected** | Failure rate 10.00% with coordinates vs 9.95% without; transit 61.89 vs 61.92 hrs |
| 5 | The reported failure rate is inflated by a software defect | **Confirmed but small** | Defect on 3,447 shipments; rate 9.99% to 9.80%. The ~10% failure rate is real |
| 6 | Timestamp errors distort delivery time | **Confirmed but small** | 12,335 delivered records with delivery before pickup; average moves 0.61 hrs |
| 7 | The audit COD figure is overstated by data errors | **Confirmed** | ₦313.9M on 62,254 non-COD shipments (0.58%), plus the larger definition problem in Insight 5 |
| 8 | Financial leakage exists | **Confirmed, but not the cause of complaints** | About ₦152M a year of weight under-declaration, steady since 2020 |
| 9 | Real operational failure is the root cause | **Supported, not proven** | Stable ~10% failure rate; 28% of shipments not delivered; 95% of in-flight shipments stuck. The direct link to complaints was not tested |
| 10 | Complaints rose over the last three months | **Not confirmed** | Volume looked flat; rate by month not computed |
| 11 | Stuck parcels drive the "lost" complaints | **Not tested** | Plausible (25.6% of complaints are "lost"), but not linked at shipment level |
| 12 | Specific drivers or routes cause failures | **Not tested** | Driver and route analysis was not part of the episodes completed |
| 13 | Delivered COD cash is missing | **Not resolved** | 74% have no completed receipt; the payments table may simply not record remittances |

**Overall:** hypotheses 1 to 4 are rejected, 5 to 8 are confirmed but do not explain the complaints, 9 is supported, and 10 to 13 are open.

## 5. Business insights

### Insight 1: Complaints are evenly spread, so there is no single driver to fix
- 64,737 complaints. Categories split almost equally: lost 25.6%, wrong address 24.9%, late delivery 24.8%, damaged 24.7%.
- Hub complaint rates range 35.7 to 36.5 per 1,000 shipments. Lagos vs Kano: 36.1 vs 35.8, effectively the same.
- 65.1% of complaints are resolved, so about 35% remain unresolved.
- **Implication:** "lost" and "late delivery" together are about 50% of complaints, consistent with the stuck-parcel finding (Insight 5), though I did not test that link directly.

### Insight 2: The failure rate is real; the app defect is small
- Raw 9.99% (179,859 failed) vs corrected 9.80% (176,412).
- A driver-app defect let delivery attempts exceed the policy maximum on **3,447 shipments**, all with status `failed`. It ran from Jan 2020 to **14 Mar 2023** (no cases afterwards), at every hub (11.5% to 13.1% each).
- The correction assumes those shipments were not genuinely failed. That is untested, so the defensible statement is a **range of 9.80% to 9.99%**.
- Monthly failure rate is flat (9.4% to 10.3%), and 2024 shows 10.08%.
- **Implication:** the board should not act on the idea that failures are a software artefact. About 176,000 failed shipments remain after correction.

### Insight 3: Weight under-declaration costs roughly ₦152M a year, and business accounts are not the cause
- 20.7% of weighed shipments exceed their declared weight by more than 20% (323,752 shipments, ₦760.9M all-time). Including smaller excesses, the figure computed in the board pack is ₦1,017.4M.
- **Last 12 months:** 64,673 shipments, ₦152.25M (>20% tier).
- Business accounts under-declare at the same rate as individuals (20.66% vs 20.72%) and with the same average shortfall (about ₦2,350 per parcel). They account for about 28% of leakage because they account for about 28% of volume. **The Financial Controller's hypothesis was rejected.**
- Leakage per hub ranges ₦18.6M to ₦19.4M a year, with no outlier.
- The rate is stable (20.71% all-time vs 20.65% in the last 12 months).
- **Judgement call:** the >20% threshold was chosen to filter scale and packaging noise. I have not proved that smaller excesses are noise, so both figures are reported.
- **Implication:** the pattern points to a process gap (fees are never re-billed after the hub weighs the parcel), not to specific customers or sites.

### Insight 4: Recorded COD is overstated by ₦313.9M because non-COD shipments carry a COD amount
- Raw ₦54.61bn vs corrected ₦54.30bn, an overstatement of ₦313.9M (0.58% of the corrected figure).
- 62,254 shipments with payment method prepaid (40,034), credit (13,397) or wallet (8,823) carry a COD amount averaging about ₦5,000, against about ₦100,600 for genuine COD. The near-identical amounts across methods suggest a system default, but the cause is unconfirmed.
- About 1,000 shipments a month since Jan 2020, **still occurring**, and identical at every hub (3.40% to 3.51% of shipments).
- **Implication:** the audit report sums COD amounts across every shipment, so a validation rule at data entry would remove the error.

### Insight 5: The audit report's "exposure" is far larger than the cash actually at risk
Even after removing phantom COD, the ₦54.30bn is a five-year cumulative sum of recorded amounts, not an exposure:

| Component | Amount | Comment |
|---|---|---|
| Failed, returned, cancelled | ₦7.05bn | No cash was collected on these |
| In-flight over 90 days | ₦7.75bn | 256,625 shipments (95% of in-flight); 34,381 are still at `created`. These are stuck, not in transit |
| In-flight 0 to 90 days | about ₦0.41bn | The genuinely live amount |
| Delivered | ₦39.09bn | Only ₦2.51bn has a completed `cod_cash` receipt |

- **74% of delivered COD shipments have no completed cash receipt** (₦36.58bn of recorded COD amounts), flat across all five years. This is an **unreconciled gap, not proven missing cash**: the payments table may simply not capture remittances. I did not finish the check that would decide this.
- **Implication:** the operations lead's claim that his corridor could not hold what the report says is supported. The report counts money that no rider is carrying.

### Insight 6: A defensible delivery time is 61.9 hours, and hubs do not differ
- Average **61.90 hrs** (median 61.86) across 1,283,555 delivered shipments, **99.05%** of all delivered shipments. Raw average (including impossible records) is 61.29 hrs.
- 12,335 delivered shipments have delivery before pickup. Across all statuses there are 14,372 (the other 2,037 are failed or returned shipments carrying a delivery timestamp, a separate defect).
- The records run from the start of the data to **2 Jun 2022**, matching the client's report of an app fix in June 2022. Offsets are 1 to 12 hours, **larger than a UK/Lagos clock difference alone**, so the timezone explanation is plausible but not independently confirmed.
- Hub averages range 61.87 to 61.94 hrs. Against a 72-hour benchmark (my assumption), 58.7% of valid delivered shipments arrive on time, which implies a wide spread around the average.
- **Missing coordinates:** 55,974 delivery addresses (360,509 shipments, 20%). Failure rate is 10.00% with coordinates and 9.95% without, and transit is 61.89 vs 61.92 hrs. **No measurable service impact.**

### Insight 7: The data dictionary does not match the data
- Statuses `created`, `out_for_delivery` and `cancelled` exist but are undocumented. `pending` and `picked_up` are documented but do not exist.
- Payment methods `credit` and `wallet` exist but are undocumented.

## 6. Recommendations

| Priority | Recommendation | Evidence | Suggested owner | KPI to track |
|---|---|---|---|---|
| 1 | **Reconcile delivered COD against cash receipts** and confirm whether the 74% gap is a recording issue or a cash-control issue | ₦36.58bn of recorded COD amounts with no completed receipt | Finance | % of delivered COD shipments with a matching receipt |
| 2 | **Investigate and close out stuck shipments**; add a status timeout so no parcel stays in flight for months | 256,625 shipments over 90 days; ₦7.75bn in COD amounts | Operations, Data & Tech | Shipments in-flight over 30 days |
| 3 | **Re-bill weight differences automatically** when the hub weighs a parcel | About ₦152M a year on parcels over 20% above declared weight, at a stable rate | Finance, Operations | Weight leakage per 1,000 shipments; % re-billed |
| 4 | **Block a COD amount on non-COD shipments** at data entry | ~1,000 shipments a month since Jan 2020 | Data & Tech | Phantom COD shipments per month (target: 0) |
| 5 | **Fix timestamp capture** (one timezone, validation that delivery follows pickup) and write the rule in the data dictionary | 12,335 impossible delivered records; 2,037 failed or returned shipments with a delivery timestamp | Data & Tech | Records with delivery before pickup |
| 6 | **Update the data dictionary** | Undocumented statuses and payment methods | Data & Tech | Dictionary matches live enums |
| 7 | **Use rates, not counts, in board reporting**, with the window and population on every figure | Total vs per-1,000 comparisons changed several conclusions | Analytics | n/a |
| 8 | **Do not take action against individual hubs, drivers or customer groups** on current evidence | No outlier found in any analysis | COO | n/a |

### Illustrative financial impact (assumptions, not forecasts)

| Lever | Cautious | Expected | Ambitious |
|---|---|---|---|
| Weight leakage recovery | 25% | 50% | 75% |
| Failure-rate cut | 0.2 pp | 0.5 pp | 1.0 pp |
| Revenue from leakage | ₦38.1M | ₦76.1M | ₦114.2M |
| Revenue from fewer failures | ₦2.0M | ₦5.0M | ₦9.9M |
| **Total a year** | **₦40.0M** | **₦81.1M** | **₦124.1M** |

- Leakage lever: ₦152.25M (last 12 months, >20% tier) × recovery %.
- Failure lever: failure-rate cut × 2024 shipments (359,711) × average fee on failed shipments (₦2,754; 36,255 failures in 2024). This assumes a prevented failure earns its fee, so treat it as an upper bound.
- Recovery rates and failure-rate cuts are assumptions.

## 7. Raw vs corrected figures

| Finding | Raw | Corrected | Difference | Type | Reason |
|---|---|---|---|---|---|
| Failure rate | 9.99% | 9.80% | 0.19 pp | Data error | Attempts above policy on 3,447 failed shipments |
| Weight leakage (all-time) | ₦1,017.4M | ₦760.9M (>20% over) | ₦256.5M | Judgement | Threshold excludes excesses of 20% or less |
| Recorded COD | ₦54.61bn | ₦54.30bn | ₦313.9M | Data error | COD amount on 62,254 non-COD shipments |
| Avg delivery time | 61.29 hrs | 61.90 hrs | 0.61 hrs | Data error | 12,335 delivered shipments with delivery before pickup |

## 8. Why the Excel results differ from SQL and Power BI

SQL and Power BI ran on the **full dataset** (1.8M shipments). Excel could not hold that volume, so the Excel files use **extracts: a sample or a shorter time window**. Excel results should therefore be read as a demonstration of method, not as board figures.

| Episode | Excel result | SQL / Power BI result | Why they differ |
|---|---|---|---|
| 1 Complaints | Same counts (64,737; category and hub tables) | Same | Full data in both; **match** |
| 2 Failure rate | 3,447 over cap; 9.99% to 9.80% | Same | Full data in both; **match exactly** |
| 3 Weight leakage | 12 months: ₦152,250,395; 2 years: ₦304.1M | All-time ₦760.9M; 12 months ₦152.25M | **Different time windows.** The 12-month figure matches SQL; the 2-year figure is an extra window |
| 4 COD | ₦10.95bn to ₦10.88bn; phantom ₦63.3M (12,511 shipments) | ₦54.61bn to ₦54.30bn; phantom ₦313.9M (62,254 shipments) | **Different time windows** (12 months vs all-time). The overstatement is 0.58% in both |
| 5 Transit time | Extract of 26,372 rows: 27.2 to 62.3 hrs ("35-hour distortion") | 61.29 to 61.90 hrs (0.61-hr difference) | **Sample, not population.** The extract held all 14,372 impossible records but only 12,000 valid ones, so it exaggerated the bug about 57 times |
| 5 Excel formula | `AVERAGEIFS` gives about 62.09 hrs | 61.90 hrs | The table holds a sample of about 10,000 delivered shipments. A gap of 0.2 hrs is within normal sampling error (rough estimate) |
| 6 Board summary tab | Mixed windows and populations | Consistent full-data figures | **The tab must be replaced** with the SQL and Power BI figures |

Smaller differences between SQL and Power BI (monthly counts off by 1 to 5 in Episode 2, ₦152.26M vs ₦152.25M in Episode 3) most likely come from timezone boundaries and rounding.

**Rules used in this project:**
- Board figures come from SQL and Power BI on the full data.
- Excel is used to show method and to cross-check, and each Excel figure states its window and population.
- Where Excel and SQL disagree, I checked the population and window before suspecting the formula.

## 9. Analytical decisions

- Compared rates, not totals, so larger groups were not blamed for their volume.
- Cross-checked every headline figure in SQL, Excel and Power BI. Differences traced to time windows, timezone boundaries and an Excel sample that held 14,372 bad rows but only 12,000 good rows, which exaggerated the transit-time bug about 57 times.
- Treated the three data-error corrections differently from the weight threshold, which is a judgement call.
- Restricted the delivery-time metric to delivered shipments, after finding the first version also included failed and returned shipments.

## 10. Limitations and open items

- **The complaint spike was not tested.** I did not compute complaints per 1,000 shipments by month, so I cannot confirm or reject a recent rise.
- **COD receipts:** I did not finish checking what payments exist for delivered COD parcels, so the ₦36.58bn gap is unresolved.
- **Over-cap failures:** the assumption that these 3,447 shipments were not genuinely failed is untested, so the failure rate is reported as a range.
- **Weight threshold:** not tested against smaller excesses.
- **72-hour benchmark:** my assumption, not a client-stated target.
- **Negative transit times:** cause unconfirmed.
- **Stuck parcels:** counted but not investigated or linked to "lost" complaints.
- **Simulated data:** results show uniform patterns that real data would rarely show.
