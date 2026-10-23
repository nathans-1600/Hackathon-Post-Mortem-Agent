-- 08_search_services.sql
-- Cortex Search services. Each indexes the CHUNK column of a chunk table, so the
-- source tables must exist (and should be loaded) before the first refresh.
-- All three use the default embedding model (snowflake-arctic-embed-m-v1.5) on PM_WH.

create or replace cortex search service POSTMORTEM.RESULTS.DOC_SEARCH
	ON CHUNK
	attributes DECISION_KEY,DOC_TYPE,REL_DAY
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, doc_uuid, decision_key, doc_type, rel_day, chunk_no FROM POSTMORTEM.MASKED.DOC_CHUNKS;
create or replace cortex search service POSTMORTEM.RESULTS.PM_REPORT_SEARCH
	ON CHUNK
	attributes DECISION_KEY,SECTION
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, chunk_id, decision_key, section FROM POSTMORTEM.RESULTS.PM_REPORT_CHUNKS;
create or replace cortex search service POSTMORTEM.LIVE.LIVE_DOC_SEARCH
	ON CHUNK
	attributes DOC_TYPE,REL_DAY
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, doc_uuid, doc_type, rel_day, chunk_no FROM POSTMORTEM.LIVE.LIVE_DOC_CHUNKS;
