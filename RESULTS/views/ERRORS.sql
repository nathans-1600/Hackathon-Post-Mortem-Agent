-- POSTMORTEM.RESULTS.ERRORS (view)
-- FORECASTS scored against reported revenue: pct_error, abs_pct_error, and how many FY+1 quarters were
-- already reported at the review.
--
-- Uses: FORECASTS, OUTCOMES.ACTUALS_REL, MASKED.REVENUE_HISTORY

create or replace view POSTMORTEM.RESULTS.ERRORS(
	DECISION_KEY,
	SOURCE,
	MODEL,
	FY_REL,
	PROJ_CUR_M,
	ACTUAL_CUR_M,
	PCT_ERROR,
	ABS_PCT_ERROR,
	FY1_QUARTERS_KNOWN
) as
SELECT f.decision_key, f.source, f.model, f.fy_rel,
       ROUND(f.proj_cur_m, 1)                               AS proj_cur_m,
       a.actual_cur_m,
       ROUND(100 * (f.proj_cur_m / a.actual_cur_m - 1), 2)  AS pct_error,
       ROUND(100 * ABS(f.proj_cur_m / a.actual_cur_m - 1), 2) AS abs_pct_error,
       q.fy1_quarters_known
FROM POSTMORTEM.RESULTS.FORECASTS f
JOIN POSTMORTEM.OUTCOMES.ACTUALS_REL a ON a.decision_key = f.decision_key AND a.fy_rel = f.fy_rel
LEFT JOIN (SELECT decision_key, COUNT(*) AS fy1_quarters_known FROM POSTMORTEM.MASKED.REVENUE_HISTORY
           WHERE period_rel LIKE 'Q% FY+1' GROUP BY 1) q ON q.decision_key = f.decision_key;
