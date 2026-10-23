-- 04_results_views.sql
-- POSTMORTEM.RESULTS views, in dependency order.
-- (GET_DDL emits these alphabetically, which fails on a fresh account: ERRORS
--  reads FORECASTS, LEARN_RULE_SCORES reads LEARN_RUN_ERRORS, etc.)

create or replace view POSTMORTEM.RESULTS.FORECASTS(
	DECISION_KEY,
	SOURCE,
	MODEL,
	FY_REL,
	PROJ_CUR_M
) as
WITH fy0 AS (
  SELECT decision_key, revenue_cur_m AS fy0_cur FROM POSTMORTEM.MASKED.REVENUE_HISTORY WHERE period_rel = 'FY0'),
runs AS (
  SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS
  WHERE fy1_growth_pct IS NOT NULL AND model IN ('claude-opus-4-6', 'claude-opus-4-8')   -- Sonnet excluded
    AND mode IN ('independent', 'clone', 'factsheet', 'named', 'live')   -- learned runs are scored in 11_learn.sql
  QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, mode, model)),
claude AS (
  SELECT r.decision_key, 'claude_' || r.mode AS source, r.model, 'FY+1' AS fy_rel,
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) AS proj_cur_m
  FROM runs r JOIN fy0 f USING (decision_key)
  UNION ALL
  SELECT r.decision_key, 'claude_' || r.mode, r.model, 'FY+2',
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) * (1 + r.fy2_growth_pct / 100)
  FROM runs r JOIN fy0 f USING (decision_key)
  UNION ALL
  SELECT r.decision_key, 'claude_' || r.mode, r.model, 'FY+3',
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) * (1 + r.fy2_growth_pct / 100) * (1 + r.fy3_growth_pct / 100)
  FROM runs r JOIN fy0 f USING (decision_key)),
guide AS (   -- latest pre-anchor full-year guide for FY+1, midpoint; growth-only guides (TEAM) compound off FY0
  SELECT g.decision_key, 'guidance_mid' AS source, NULL AS model, g.period_rel AS fy_rel,
         COALESCE((g.low_cur_m + g.high_cur_m) / 2,
                  f.fy0_cur * (1 + (g.growth_low_pct + g.growth_high_pct) / 200)) AS proj_cur_m
  FROM POSTMORTEM.MASKED.GUIDANCE g JOIN fy0 f USING (decision_key)
  WHERE g.period_rel = 'FY+1' AND (g.low_cur_m IS NOT NULL OR g.growth_low_pct IS NOT NULL)
  QUALIFY g.rel_day = MAX(g.rel_day) OVER (PARTITION BY g.decision_key))
SELECT * FROM claude
UNION ALL
SELECT decision_key, 'parnassus', NULL, fy_rel, revenue_cur_m FROM POSTMORTEM.MASKED.PARNASSUS_PROJ
UNION ALL
SELECT decision_key, 'consensus', NULL, fy_rel, revenue_cur_m FROM POSTMORTEM.MASKED.CONSENSUS
UNION ALL
SELECT * FROM guide;
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
create or replace view POSTMORTEM.RESULTS.LEARN_RUN_ERRORS(
	RUN_ID,
	DECISION_KEY,
	RUN_AT,
	PURPOSE,
	HOLDOUT_KEY,
	PLAYBOOK_ID,
	RULE_IDS,
	RULES_APPLIED,
	FY_REL,
	LEARNED_ABS_ERR,
	BASE_ABS_ERR,
	GAIN_PTS
) as
WITH runs AS (
  SELECT r.run_id, r.decision_key, r.run_at, r.parsed:rules_applied AS rules_applied,
         p.playbook_id, p.purpose, p.holdout_key, p.rule_ids, h.revenue_cur_m AS fy0_cur,
         r.fy1_growth_pct AS g1, r.fy2_growth_pct AS g2, r.fy3_growth_pct AS g3
  FROM POSTMORTEM.RESULTS.REPLAY_RUNS r
  JOIN POSTMORTEM.RESULTS.LEARN_PLAYBOOKS p ON p.playbook_id = r.playbook_id
  JOIN POSTMORTEM.MASKED.REVENUE_HISTORY h ON h.decision_key = r.decision_key AND h.period_rel = 'FY0'
  WHERE r.mode IN ('learned', 'learned_inner') AND r.fy1_growth_pct IS NOT NULL),
proj AS (
  SELECT *, 'FY+1' AS fy_rel, fy0_cur * (1 + g1 / 100) AS proj_cur_m FROM runs
  UNION ALL SELECT *, 'FY+2', fy0_cur * (1 + g1 / 100) * (1 + g2 / 100) FROM runs
  UNION ALL SELECT *, 'FY+3', fy0_cur * (1 + g1 / 100) * (1 + g2 / 100) * (1 + g3 / 100) FROM runs)
SELECT p.run_id, p.decision_key, p.run_at, p.purpose, p.holdout_key, p.playbook_id, p.rule_ids, p.rules_applied, p.fy_rel,
       ROUND(100 * ABS(p.proj_cur_m / a.actual_cur_m - 1), 2)                     AS learned_abs_err,
       e.abs_pct_error                                                            AS base_abs_err,
       ROUND(e.abs_pct_error - 100 * ABS(p.proj_cur_m / a.actual_cur_m - 1), 2)   AS gain_pts
FROM proj p
JOIN POSTMORTEM.OUTCOMES.ACTUALS_REL a ON a.decision_key = p.decision_key AND a.fy_rel = p.fy_rel
JOIN POSTMORTEM.RESULTS.ERRORS e ON e.decision_key = p.decision_key AND e.fy_rel = p.fy_rel
 AND e.source = 'claude_independent' AND e.model = 'claude-opus-4-6';
create or replace view POSTMORTEM.RESULTS.LEARN_RULE_SCORES(
	RULE_ID,
	SOURCE_KEY,
	DIRECTION,
	SIGNAL,
	APPLIES_TO,
	RULE,
	GATE_OK,
	GATE_HIT,
	TIMES_APPLIED,
	NET_WINS,
	IN_LIVE_PLAYBOOK
) as
WITH r1 AS (SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS WHERE fy_rel = 'FY+1' AND purpose = 'outer_r1'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1),
live AS (SELECT rule_ids FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE purpose = 'all'
         ORDER BY created_at DESC LIMIT 1)
SELECT r.rule_id, r.source_key, r.direction, r.signal, r.applies_to, r.rule,
       COALESCE(r.gate_ok, FALSE) AS gate_ok, r.gate_hit,
       COUNT(e.run_id) AS times_applied, COALESCE(SUM(SIGN(e.gain_pts)), 0) AS net_wins,
       ARRAY_CONTAINS(r.rule_id::VARIANT, ANY_VALUE(l.rule_ids)) AS in_live_playbook
FROM POSTMORTEM.RESULTS.LEARN_RULES r
LEFT JOIN r1 e ON ARRAY_CONTAINS(r.rule_id::VARIANT, e.rules_applied::ARRAY) AND ARRAY_CONTAINS(r.rule_id::VARIANT, e.rule_ids)
LEFT JOIN live l ON TRUE
GROUP BY r.rule_id, r.source_key, r.direction, r.signal, r.applies_to, r.rule, r.gate_ok, r.gate_hit;
create or replace view POSTMORTEM.RESULTS.LEARN_SUMMARY(
	DECISION_KEY,
	BASELINE_ABS_ERR,
	ROUND1_ABS_ERR,
	ROUND2_ABS_ERR,
	ROUND1_GAIN_PTS,
	ROUND2_GAIN_PTS,
	ROUND1_RULES,
	ROUND2_RULES,
	NOISE_PTS
) as
WITH latest AS (
  SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS
  WHERE fy_rel = 'FY+1' AND purpose IN ('outer_r1', 'outer_r2')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key, purpose ORDER BY run_at DESC) = 1),
noise AS (
  SELECT ROUND(AVG(ABS(n.fy1_growth_pct - i.fy1_growth_pct)), 2) AS noise_pts
  FROM (SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS WHERE mode = 'noise_check' AND fy1_growth_pct IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1) n
  JOIN (SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS
        WHERE mode = 'independent' AND model = 'claude-opus-4-6' AND fy1_growth_pct IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1) i USING (decision_key))
SELECT p.decision_key,
       r1.base_abs_err AS baseline_abs_err, r1.learned_abs_err AS round1_abs_err, r2.learned_abs_err AS round2_abs_err,
       r1.gain_pts AS round1_gain_pts, r2.gain_pts AS round2_gain_pts,
       ARRAY_SIZE(r1.rule_ids) AS round1_rules, ARRAY_SIZE(r2.rule_ids) AS round2_rules,
       n.noise_pts
FROM POSTMORTEM.MASKED.POSITIONS p
LEFT JOIN (SELECT * FROM latest WHERE purpose = 'outer_r1') r1 USING (decision_key)
LEFT JOIN (SELECT * FROM latest WHERE purpose = 'outer_r2') r2 USING (decision_key)
LEFT JOIN noise n ON TRUE
WHERE NOT p.is_live;
create or replace view POSTMORTEM.RESULTS.PIPELINE_STATUS(
	CHECK_ID,
	KIND,
	CHECK_NAME,
	RESULT,
	DETAIL,
	CHECKED_AT
) as
SELECT check_id, kind, check_name, result, detail, checked_at FROM POSTMORTEM.RESULTS.EVAL_PIPELINE
QUALIFY checked_at = MAX(checked_at) OVER ();
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
create or replace view POSTMORTEM.RESULTS.REPLAY_LATEST(
	RUN_ID,
	DECISION_KEY,
	MODE,
	MODEL,
	RUN_AT,
	MODEL_ROLE,
	FY1_GROWTH_PCT,
	FY2_GROWTH_PCT,
	FY3_GROWTH_PCT,
	CONFIDENCE,
	VS_CONSENSUS,
	KEY_RISKS
) as
SELECT r.run_id, r.decision_key, r.mode, r.model, r.run_at,
       IFF(r.model = 'claude-opus-4-8', 'contaminated control', 'clean') AS model_role,
       r.fy1_growth_pct, r.fy2_growth_pct, r.fy3_growth_pct, r.confidence,
       r.parsed:vs_consensus::STRING AS vs_consensus,
       ARRAY_TO_STRING(r.parsed:key_risks::ARRAY, '; ') AS key_risks
FROM POSTMORTEM.RESULTS.REPLAY_RUNS r
JOIN POSTMORTEM.MASKED.POSITIONS d ON d.decision_key = r.decision_key AND NOT COALESCE(d.is_live, FALSE)
WHERE r.mode IN ('independent', 'clone', 'factsheet') AND r.model IN ('claude-opus-4-6', 'claude-opus-4-8')
  AND r.fy1_growth_pct IS NOT NULL
QUALIFY r.run_at = MAX(r.run_at) OVER (PARTITION BY r.decision_key, r.mode, r.model);
create or replace view POSTMORTEM.RESULTS.REPLAY_DRIVERS(
	DRIVER_ID,
	RUN_ID,
	DECISION_KEY,
	MODE,
	MODEL,
	MODEL_ROLE,
	DRIVER,
	DIRECTION,
	FY,
	EVIDENCE
) as
SELECT l.run_id || '-' || d.index AS driver_id, l.run_id, l.decision_key, l.mode, l.model, l.model_role,
       d.value:driver::STRING AS driver, d.value:direction::STRING AS direction,
       d.value:fy::STRING AS fy, d.value:evidence::STRING AS evidence
FROM POSTMORTEM.RESULTS.REPLAY_LATEST l
JOIN POSTMORTEM.RESULTS.REPLAY_RUNS r USING (run_id), LATERAL FLATTEN(input => r.parsed:drivers) d;
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
create or replace view POSTMORTEM.RESULTS.REPLAY_PROVENANCE(
	PROVENANCE_ID,
	MODE,
	MODEL,
	RUNS,
	IMPORTED_RUNS,
	FRESH_RUNS,
	UNPARSED_RUNS,
	LAST_RUN
) as
SELECT r.mode || '|' || r.model AS provenance_id, r.mode, r.model, COUNT(*) AS runs,
       COUNT_IF(f.imported) AS imported_runs, COUNT_IF(f.is_fresh) AS fresh_runs,
       COUNT_IF(r.fy1_growth_pct IS NULL) AS unparsed_runs, MAX(r.run_at) AS last_run
FROM POSTMORTEM.RESULTS.REPLAY_RUNS r LEFT JOIN POSTMORTEM.RESULTS.REPLAY_RUN_FRESH f USING (run_id)
GROUP BY r.mode, r.model;
