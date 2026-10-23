-- POSTMORTEM.LIVE.SANITY_REPORT_LATEST (view)
-- The latest written sanity-check report per case.
--
-- Uses: SANITY_REPORTS

create or replace view POSTMORTEM.LIVE.SANITY_REPORT_LATEST(
	DECISION_KEY,
	CREATED_AT,
	REPORT
) as
SELECT decision_key, created_at, report FROM POSTMORTEM.LIVE.SANITY_REPORTS
QUALIFY created_at = MAX(created_at) OVER (PARTITION BY decision_key);
