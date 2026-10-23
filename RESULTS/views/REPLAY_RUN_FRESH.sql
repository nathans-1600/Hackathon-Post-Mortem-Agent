-- POSTMORTEM.RESULTS.REPLAY_RUN_FRESH (view)
-- Per run: whether it is fresh (run after the masked documents last changed, or imported with a matching
-- checksum) and whether it was imported.
--
-- Uses: REPLAY_RUNS, MASKED.DOCUMENTS, REPLAY_IMPORTS

create or replace view POSTMORTEM.RESULTS.REPLAY_RUN_FRESH(
	RUN_ID,
	IS_FRESH,
	IMPORTED
) as
SELECT r.run_id,
       (r.run_at > t.last_altered) OR (i.run_id IS NOT NULL AND i.docs_checksum = d.checksum) AS is_fresh,
       i.run_id IS NOT NULL AS imported
FROM POSTMORTEM.RESULTS.REPLAY_RUNS r
CROSS JOIN (SELECT last_altered FROM POSTMORTEM.INFORMATION_SCHEMA.TABLES
            WHERE table_schema = 'MASKED' AND table_name = 'DOCUMENTS') t
CROSS JOIN (SELECT SUM(LENGTH(text)) AS checksum FROM POSTMORTEM.MASKED.DOCUMENTS) d
LEFT JOIN (SELECT * FROM POSTMORTEM.RESULTS.REPLAY_IMPORTS
           QUALIFY ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY imported_at DESC) = 1) i USING (run_id);
