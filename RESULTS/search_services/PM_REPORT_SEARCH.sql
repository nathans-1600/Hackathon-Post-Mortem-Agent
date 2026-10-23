-- POSTMORTEM.RESULTS.PM_REPORT_SEARCH (Cortex Search service)
-- Cortex Search over the post-mortem report text (PM_REPORT_CHUNKS), filterable by case and section.
--
-- Uses: PM_REPORT_CHUNKS

create or replace cortex search service POSTMORTEM.RESULTS.PM_REPORT_SEARCH
	ON CHUNK
	attributes DECISION_KEY,SECTION
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, chunk_id, decision_key, section FROM POSTMORTEM.RESULTS.PM_REPORT_CHUNKS;
