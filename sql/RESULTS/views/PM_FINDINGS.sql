-- POSTMORTEM.RESULTS.PM_FINDINGS (view)
-- One row per post-mortem finding, labelled with its group (1 in packet, 2 knowable but not collected, 3
-- hindsight only). Only group 1 is usable as a lesson.
--
-- Uses: POSTMORTEMS, PM_REPORTS

create or replace view POSTMORTEM.RESULTS.PM_FINDINGS(
	FINDING_ID,
	DECISION_KEY,
	POSTMORTEM_ID,
	FINDING_GROUP,
	FINDING,
	SOURCE,
	PUBLIC_DATE,
	EFFECT,
	VERIFIED,
	RISK_CATEGORY,
	USABLE_AS_LESSON
) as
WITH pm AS (SELECT p.* FROM POSTMORTEM.RESULTS.POSTMORTEMS p
            WHERE p.postmortem_id IN (SELECT postmortem_id FROM POSTMORTEM.RESULTS.PM_REPORTS))
SELECT pm.postmortem_id || '-1-' || f.index AS finding_id, pm.decision_key, pm.postmortem_id,
       '1 in packet, underweighted' AS finding_group, f.value:input::STRING AS finding,
       f.value:evidence::STRING AS source, NULL::STRING AS public_date, f.value:effect::STRING AS effect,
       NULL::BOOLEAN AS verified, NULL::STRING AS risk_category, TRUE AS usable_as_lesson
FROM pm, LATERAL FLATTEN(input => pm.parsed:in_packet_underweighted) f
UNION ALL
SELECT pm.postmortem_id || '-2-' || f.index, pm.decision_key, pm.postmortem_id,
       '2 public before review, not in packet (unverified)', f.value:input::STRING, f.value:source_type::STRING,
       f.value:public_date::STRING, f.value:effect::STRING, f.value:verified::BOOLEAN, NULL, FALSE
FROM pm, LATERAL FLATTEN(input => pm.parsed:knowable_not_in_packet) f
UNION ALL
SELECT pm.postmortem_id || '-3-' || f.index, pm.decision_key, pm.postmortem_id,
       '3 hindsight only (never a lesson)', f.value:event::STRING, f.value:when::STRING, NULL,
       f.value:effect::STRING, NULL, f.value:risk_category::STRING, FALSE
FROM pm, LATERAL FLATTEN(input => pm.parsed:hindsight_only) f;
