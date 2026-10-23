-- POSTMORTEM.RESULTS.PM_REPORTS (view)
-- Latest masked post-mortem per backtest case, flattened: projected, reported, gap, closer sources, change
-- next time, data to add, and finding counts per group.
--
-- Uses: POSTMORTEMS, MASKED.POSITIONS

create or replace view POSTMORTEM.RESULTS.PM_REPORTS(
	DECISION_KEY,
	POSTMORTEM_ID,
	CREATED_AT,
	AUTHOR_MODEL,
	PROJECTED,
	REPORTED,
	GAP,
	CLOSER_SOURCES,
	CHANGE_NEXT_TIME,
	DATA_TO_ADD_NEXT_TIME,
	N_IN_PACKET,
	N_KNOWABLE,
	N_HINDSIGHT
) as
SELECT p.decision_key, p.postmortem_id, p.created_at, p.model AS author_model,
       p.parsed:projected::STRING AS projected,
       p.parsed:reported::STRING AS reported,
       p.parsed:gap::STRING AS gap,
       p.parsed:closer_sources::STRING AS closer_sources,
       p.parsed:change_next_time::STRING AS change_next_time,
       ARRAY_TO_STRING(p.parsed:data_to_add_next_time::ARRAY, '; ') AS data_to_add_next_time,
       ARRAY_SIZE(p.parsed:in_packet_underweighted) AS n_in_packet,
       ARRAY_SIZE(p.parsed:knowable_not_in_packet)  AS n_knowable,
       ARRAY_SIZE(p.parsed:hindsight_only)          AS n_hindsight
FROM POSTMORTEM.RESULTS.POSTMORTEMS p
JOIN POSTMORTEM.MASKED.POSITIONS d ON d.decision_key = p.decision_key AND NOT COALESCE(d.is_live, FALSE)
WHERE p.parsed IS NOT NULL AND COALESCE(p.mode, 'masked') = 'masked'
QUALIFY p.created_at = MAX(p.created_at) OVER (PARTITION BY p.decision_key);
