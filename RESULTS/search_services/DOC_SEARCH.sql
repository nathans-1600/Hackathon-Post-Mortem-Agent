-- POSTMORTEM.RESULTS.DOC_SEARCH (Cortex Search service)
-- Cortex Search over the masked case documents (MASKED.DOC_CHUNKS), filterable by case, document type and
-- relative day.
--
-- Uses: MASKED.DOC_CHUNKS

create or replace cortex search service POSTMORTEM.RESULTS.DOC_SEARCH
	ON CHUNK
	attributes DECISION_KEY,DOC_TYPE,REL_DAY
	warehouse='PM_WH'
	target_lag='1 day'
	refresh_mode=INCREMENTAL
	as SELECT chunk, doc_uuid, decision_key, doc_type, rel_day, chunk_no FROM POSTMORTEM.MASKED.DOC_CHUNKS;
