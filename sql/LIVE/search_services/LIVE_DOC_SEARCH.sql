-- POSTMORTEM.LIVE.LIVE_DOC_SEARCH (Cortex Search service)
-- Cortex Search over the live case's masked documents (LIVE_DOC_CHUNKS), filterable by document type and
-- relative day.
--
-- Uses: LIVE_DOC_CHUNKS

create or replace cortex search service POSTMORTEM.LIVE.LIVE_DOC_SEARCH
	ON CHUNK
	attributes DOC_TYPE,REL_DAY
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, doc_uuid, doc_type, rel_day, chunk_no FROM POSTMORTEM.LIVE.LIVE_DOC_CHUNKS;
