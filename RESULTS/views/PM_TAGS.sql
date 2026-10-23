-- POSTMORTEM.RESULTS.PM_TAGS (view)
-- Bias tags of the post-mortems shown in PM_REPORTS.
--
-- Uses: BIAS_TAGS, PM_REPORTS

create or replace view POSTMORTEM.RESULTS.PM_TAGS(
	TAG_ID,
	DECISION_KEY,
	POSTMORTEM_ID,
	TAG,
	ABOUT,
	STRENGTH,
	EVIDENCE
) as
SELECT postmortem_id || '-' || tag || '-' || COALESCE(about, '') AS tag_id, decision_key, postmortem_id,
       tag, about, strength, evidence
FROM POSTMORTEM.RESULTS.BIAS_TAGS
WHERE postmortem_id IN (SELECT postmortem_id FROM POSTMORTEM.RESULTS.PM_REPORTS);
