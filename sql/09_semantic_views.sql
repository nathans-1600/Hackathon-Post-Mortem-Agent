-- 09_semantic_views.sql
-- Cortex Analyst semantic views, exported verbatim with GET_DDL(..., TRUE).
-- PM_ALL_SV is the single backtest view (it replaced PM_SV, LEARN_SV and PM_EXPLORER_SV);
-- LIVE_SV covers the live sanity-check case. Run after 04_results_views.sql and 07_live.sql.

create or replace semantic view POSTMORTEM.RESULTS.PM_ALL_SV
	tables (
		DECISIONS as POSTMORTEM.MASKED.POSITIONS primary key (DECISION_KEY) comment='One row per masked case (the investment review whose revenue projections are scored).',
		POSTMORTEM.RESULTS.ERRORS comment='One row per forecast source x model x fiscal year, scored against reported revenue.',
		TAGS as POSTMORTEM.RESULTS.PM_TAGS primary key (TAG_ID) comment='Bias tags from the masked post-mortems, fixed list. A tag needs that source''s FY+1 miss to be at least 2%.',
		REPORTS as POSTMORTEM.RESULTS.PM_REPORTS primary key (POSTMORTEM_ID) comment='Latest masked post-mortem per case: projected, reported, gap, closer sources, change next time, data to add.',
		FINDINGS as POSTMORTEM.RESULTS.PM_FINDINGS primary key (FINDING_ID) comment='One row per post-mortem finding, in one of three groups. Only group 1 can be a lesson.',
		REPLAYS as POSTMORTEM.RESULTS.REPLAY_LATEST primary key (RUN_ID) comment='Latest masked Claude replay per case, mode and model: projected growth FY+1..FY+3, confidence, view vs consensus.',
		DRIVERS as POSTMORTEM.RESULTS.REPLAY_DRIVERS primary key (DRIVER_ID) comment='Drivers Claude cited in its latest masked replays, with evidence as document type and day.',
		LEARN as POSTMORTEM.RESULTS.LEARN_SUMMARY primary key (DECISION_KEY) comment='Learning loop per case, FY+1 absolute error: plain Opus 4.6 replay (baseline), round 1 playbook, round 2 pruned playbook; noise floor.',
		RULES as POSTMORTEM.RESULTS.LEARN_RULE_SCORES primary key (RULE_ID) comment='Rules learned from the masked post-mortems: gate result, round-1 score, and whether they feed the live playbook.',
		GATES as POSTMORTEM.RESULTS.PIPELINE_STATUS primary key (CHECK_ID) comment='Latest pipeline and hindsight checks. Gate rows must say PASS.',
		EVALS as POSTMORTEM.RESULTS.EVAL_HISTORY comment='Mean score per metric for each evaluation run of the semantic view and the agent.',
		PROVENANCE as POSTMORTEM.RESULTS.REPLAY_PROVENANCE primary key (PROVENANCE_ID) comment='Replay runs per mode and model: how many, imported from the sandbox, fresh, unparsed.'
	)
	relationships (
		ERRORS_TO_DECISIONS as ERRORS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		TAGS_TO_DECISIONS as TAGS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		REPORTS_TO_DECISIONS as REPORTS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		FINDINGS_TO_DECISIONS as FINDINGS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		REPLAYS_TO_DECISIONS as REPLAYS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		DRIVERS_TO_DECISIONS as DRIVERS(DECISION_KEY) references DECISIONS(DECISION_KEY),
		LEARN_TO_DECISIONS as LEARN(DECISION_KEY) references DECISIONS(DECISION_KEY),
		RULES_TO_DECISIONS as RULES(SOURCE_KEY) references DECISIONS(DECISION_KEY)
	)
	facts (
		ERRORS.PCT_ERROR as pct_error comment='Forecast / actual - 1, in percent. Positive = too high.',
		ERRORS.ABS_PCT_ERROR as abs_pct_error,
		ERRORS.FY1_QUARTERS_KNOWN as fy1_quarters_known comment='Quarters of FY+1 already reported at the review date.',
		TAGS.STRENGTH as strength,
		REPLAYS.FY1_GROWTH_PCT as fy1_growth_pct comment='Claude projected FY+1 revenue growth, percent.',
		REPLAYS.FY2_GROWTH_PCT as fy2_growth_pct,
		REPLAYS.FY3_GROWTH_PCT as fy3_growth_pct,
		REPLAYS.CONFIDENCE as confidence comment='Claude self-reported confidence 0-100.',
		LEARN.BASELINE_ABS_ERR as baseline_abs_err comment='FY+1 abs % error of the plain independent Opus 4.6 replay.',
		LEARN.ROUND1_ABS_ERR as round1_abs_err comment='FY+1 abs % error with the round-1 playbook (every rule from the other cases).',
		LEARN.ROUND2_ABS_ERR as round2_abs_err comment='FY+1 abs % error with the round-2 pruned playbook.',
		LEARN.ROUND1_GAIN_PTS as round1_gain_pts comment='Baseline error minus round-1 error; positive = playbook helped.',
		LEARN.ROUND2_GAIN_PTS as round2_gain_pts comment='Baseline error minus round-2 error; positive = playbook helped.',
		LEARN.ROUND1_RULES as round1_rules comment='Rules in the round-1 playbook for this case.',
		LEARN.ROUND2_RULES as round2_rules comment='Rules left after pruning (round 2).',
		LEARN.NOISE_PTS as noise_pts comment='Run-to-run noise in FY+1 growth between two identical replays. A gain within this is no evidence.',
		RULES.TIMES_APPLIED as times_applied,
		RULES.NET_WINS as net_wins comment='Wins minus losses on round-1 runs that applied the rule. Association, not cause.',
		EVALS.AVG_SCORE as avg_score,
		EVALS.EVAL_N as n,
		PROVENANCE.RUNS as runs,
		PROVENANCE.IMPORTED_RUNS as imported_runs,
		PROVENANCE.FRESH_RUNS as fresh_runs,
		PROVENANCE.UNPARSED_RUNS as unparsed_runs
	)
	dimensions (
		DECISIONS.DECISION_KEY as decision_key,
		DECISIONS.TIER as tier comment='A = review after the forecaster''s training cutoff, B = before.',
		ERRORS.SOURCE as source with synonyms=('forecaster','who forecast') comment='parnassus (= Firm_X), consensus, guidance_mid, claude_independent, claude_clone, claude_factsheet',
		ERRORS.MODEL as model comment='claude-opus-4-6 = clean forecaster; claude-opus-4-8 = contaminated control. Never average the two.',
		ERRORS.FY_REL as fy_rel comment='FY+1, FY+2, FY+3 relative to the review',
		TAGS.TAG as tag,
		TAGS.ABOUT as about comment='Whose projection the tag describes: firm_x (institutional view), claude or consensus',
		TAGS.EVIDENCE as evidence,
		REPORTS.PROJECTED as projected comment='What Firm_X projected and why.',
		REPORTS.REPORTED as reported,
		REPORTS.GAP as gap,
		REPORTS.CLOSER_SOURCES as closer_sources comment='Which forecasters came closer and why.',
		REPORTS.CHANGE_NEXT_TIME as change_next_time comment='Process lesson from the post-mortem.',
		REPORTS.DATA_TO_ADD_NEXT_TIME as data_to_add_next_time comment='Data checklist; unverified until checked.',
		FINDINGS.FINDING_GROUP as finding_group comment='1 in packet, underweighted (a lesson) | 2 public before review, not in packet (unverified checklist) | 3 hindsight only (explains the miss, never a lesson)',
		FINDINGS.FINDING as finding,
		FINDINGS.FINDING_SOURCE as source comment='Evidence (doc type + day), source type, or when it happened.',
		FINDINGS.PUBLIC_DATE as public_date,
		FINDINGS.EFFECT as effect,
		FINDINGS.USABLE_AS_LESSON as usable_as_lesson,
		REPLAYS.REPLAY_MODE as mode comment='independent, clone (house style), factsheet (600-word sheet)',
		REPLAYS.REPLAY_MODEL as model,
		REPLAYS.MODEL_ROLE as model_role comment='clean (Opus 4.6) or contaminated control (Opus 4.8). Group by this before averaging.',
		REPLAYS.VS_CONSENSUS as vs_consensus,
		REPLAYS.KEY_RISKS as key_risks,
		DRIVERS.DRIVER as driver,
		DRIVERS.DRIVER_DIRECTION as direction,
		DRIVERS.DRIVER_FY as fy,
		DRIVERS.DRIVER_EVIDENCE as evidence,
		DRIVERS.DRIVER_MODEL_ROLE as model_role,
		RULES.RULE_ID as rule_id,
		RULES.RULE_SOURCE_CASE as source_key comment='Case whose post-mortem the rule came from; never used on that case.',
		RULES.RULE as rule,
		RULES.RULE_SIGNAL as signal,
		RULES.RULE_DIRECTION as direction comment='raise, lower or widen_range',
		RULES.RULE_APPLIES_TO as applies_to,
		RULES.GATE_OK as gate_ok comment='FALSE = blocked by the hindsight gate or a manual veto; never used in any playbook. Active rules = gate_ok TRUE.',
		RULES.GATE_HIT as gate_hit comment='Why a rule was blocked.',
		RULES.IN_LIVE_PLAYBOOK as in_live_playbook comment='In the latest all-cases playbook that feeds live forecasts.',
		GATES.CHECK_ID as check_id,
		GATES.CHECK_KIND as kind comment='gate (must PASS), review, or result (what the loop found)',
		GATES.CHECK_NAME as check_name,
		GATES.CHECK_RESULT as result,
		GATES.CHECK_DETAIL as detail,
		EVALS.EVAL_RUN as run_name,
		EVALS.EVAL_TARGET as target,
		EVALS.METRIC_NAME as metric_name,
		EVALS.EVAL_CAPTURED_AT as captured_at,
		PROVENANCE.PROV_MODE as mode,
		PROVENANCE.PROV_MODEL as model
	)
	metrics (
		ERRORS.MEAN_ABS_PCT_ERROR as AVG(errors.abs_pct_error) comment='Mean absolute % error',
		ERRORS.MEAN_PCT_ERROR as AVG(errors.pct_error) comment='Mean signed % error (bias direction)',
		TAGS.TAG_COUNT as COUNT(tags.tag),
		FINDINGS.FINDING_COUNT as COUNT(findings.finding),
		REPLAYS.MEAN_FY1_GROWTH as AVG(replays.fy1_growth_pct) comment='Mean Claude projected FY+1 growth. Always split by model_role.',
		LEARN.MEAN_ROUND1_GAIN as AVG(learn.round1_gain_pts),
		LEARN.MEAN_ROUND2_GAIN as AVG(learn.round2_gain_pts) comment='Mean FY+1 gain of the pruned playbook, points',
		LEARN.ROUND2_WINS as COUNT_IF(learn.round2_gain_pts > 0),
		LEARN.ROUND2_LOSSES as COUNT_IF(learn.round2_gain_pts < 0),
		RULES.RULE_COUNT as COUNT(rules.rule_id),
		GATES.FAILING_GATES as COUNT_IF(gates.kind = 'gate' AND gates.result <> 'PASS'),
		EVALS.MEAN_EVAL_SCORE as AVG(evals.avg_score)
	)
	comment='One view for the masked backtest: errors, bias tags, post-mortems, Claude replays, learning loop, pipeline checks, evals'
	ai_verified_queries (
		VQ_LOWEST_FY1_ERROR AS (
QUESTION 'Which source had the lowest FY+1 revenue error across all cases?'
SQL 'SELECT source, model, ROUND(AVG(abs_pct_error), 2) AS mean_abs_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = ''FY+1''
           GROUP BY source, model ORDER BY mean_abs_pct_error'),
		VQ_ERROR_BY_SOURCE AS (
QUESTION 'What is the mean absolute and mean signed FY+1 error by source and model?'
SQL 'SELECT source, model, ROUND(AVG(abs_pct_error), 2) AS mean_abs_pct_error,
                  ROUND(AVG(pct_error), 2) AS mean_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = ''FY+1''
           GROUP BY source, model ORDER BY mean_abs_pct_error'),
		VQ_FIRM_X_BIAS AS (
QUESTION 'Were Firm_X projections biased high or low on FY+1?'
SQL 'SELECT ROUND(AVG(pct_error), 2) AS mean_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS WHERE source = ''parnassus'' AND fy_rel = ''FY+1'''),
		VQ_GUIDANCE_ERROR AS (
QUESTION 'In past cases, how far off was the guidance midpoint on FY+1?'
SQL 'SELECT ROUND(AVG(pct_error), 2) AS mean_pct_error, ROUND(AVG(abs_pct_error), 2) AS mean_abs_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS WHERE source = ''guidance_mid'' AND fy_rel = ''FY+1'''),
		VQ_CLONE_VS_INDEPENDENT AS (
QUESTION 'How did clone mode compare with independent mode on FY+1 error, by model?'
SQL 'SELECT source, model, ROUND(AVG(abs_pct_error), 2) AS mean_abs_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS
           WHERE source IN (''claude_clone'', ''claude_independent'') AND fy_rel = ''FY+1''
           GROUP BY source, model ORDER BY model, source'),
		VQ_TOP_TAGS AS (
QUESTION 'Which projection bias tags come up most often, and whose projections do they describe?'
SQL 'SELECT about, tag, COUNT(*) AS tag_count FROM POSTMORTEM.RESULTS.PM_TAGS
           GROUP BY about, tag ORDER BY tag_count DESC'),
		VQ_QUARTERS_KNOWN AS (
QUESTION 'Is FY+1 error lower when more quarters of FY+1 were already reported at the review?'
SQL 'SELECT fy1_quarters_known, ROUND(AVG(abs_pct_error), 2) AS mean_abs_pct_error, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = ''FY+1''
           GROUP BY fy1_quarters_known ORDER BY fy1_quarters_known'),
		VQ_CHANGE_NEXT_TIME AS (
QUESTION 'What did each post-mortem say to change next time?'
SQL 'SELECT decision_key, change_next_time FROM POSTMORTEM.RESULTS.PM_REPORTS ORDER BY decision_key'),
		VQ_FINDINGS_BY_GROUP AS (
QUESTION 'How many post-mortem findings fall in each group, by case?'
SQL 'SELECT decision_key, finding_group, COUNT(*) AS finding_count FROM POSTMORTEM.RESULTS.PM_FINDINGS
           GROUP BY decision_key, finding_group ORDER BY decision_key, finding_group'),
		VQ_CLAUDE_VS_CONSENSUS AS (
QUESTION 'Where did Claude differ from consensus in its independent replays?'
SQL 'SELECT decision_key, model_role, fy1_growth_pct, vs_consensus FROM POSTMORTEM.RESULTS.REPLAY_LATEST
           WHERE mode = ''independent'' ORDER BY decision_key, model_role'),
		VQ_CLAUDE_MEAN_GROWTH AS (
QUESTION 'What was Claude''s average projected FY+1 growth across its independent replays?'
SQL 'SELECT model_role, model, ROUND(AVG(fy1_growth_pct), 1) AS mean_fy1_growth_pct, COUNT(*) AS n
           FROM POSTMORTEM.RESULTS.REPLAY_LATEST WHERE mode = ''independent''
           GROUP BY model_role, model ORDER BY model'),
		VQ_LEARNING_SUMMARY AS (
QUESTION 'Did the learning loop improve the forecasts?'
SQL 'SELECT COUNT(*) AS cases, ROUND(AVG(baseline_abs_err), 2) AS baseline_mean_abs_err,
                  ROUND(AVG(round1_abs_err), 2) AS round1_mean_abs_err, ROUND(AVG(round2_abs_err), 2) AS round2_mean_abs_err,
                  COUNT_IF(round2_gain_pts > 0) AS wins, COUNT_IF(round2_gain_pts < 0) AS losses,
                  COUNT_IF(round2_gain_pts = 0) AS ties, ANY_VALUE(noise_pts) AS noise_pts,
                  COUNT_IF(round2_rules < round1_rules) AS cases_pruned
           FROM POSTMORTEM.RESULTS.LEARN_SUMMARY'),
		VQ_PLAYBOOK_GAIN AS (
QUESTION 'Did the learned playbook beat run-to-run noise on FY+1?'
SQL 'SELECT ROUND(AVG(round2_gain_pts), 2) AS mean_gain_pts, ANY_VALUE(noise_pts) AS noise_pts,
                  COUNT_IF(round2_gain_pts > 0) AS wins, COUNT_IF(round2_gain_pts < 0) AS losses, COUNT(*) AS cases
           FROM POSTMORTEM.RESULTS.LEARN_SUMMARY'),
		VQ_LEARNING_BY_CASE AS (
QUESTION 'Show baseline, round 1 and round 2 FY+1 error for each case.'
SQL 'SELECT decision_key, baseline_abs_err, round1_abs_err, round2_abs_err, round2_gain_pts, round1_rules, round2_rules
           FROM POSTMORTEM.RESULTS.LEARN_SUMMARY ORDER BY round2_gain_pts DESC'),
		VQ_RULE_SCORES AS (
QUESTION 'Which learned rules helped most, and which are in the live playbook?'
SQL 'SELECT rule_id, direction, rule, times_applied, net_wins, in_live_playbook
           FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES WHERE gate_ok
           ORDER BY net_wins DESC, times_applied DESC'),
		VQ_LIVE_RULES AS (
QUESTION 'Which learned rules are in the live playbook, and how did they score?'
SQL 'SELECT rule_id, rule, direction, times_applied, net_wins FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES
           WHERE in_live_playbook ORDER BY net_wins DESC, times_applied DESC'),
		VQ_RULE_DIRECTION AS (
QUESTION 'How many active rules say raise, lower or widen?'
SQL 'SELECT direction, COUNT(*) AS rules FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES
           WHERE gate_ok GROUP BY direction ORDER BY rules DESC'),
		VQ_BLOCKED_RULES AS (
QUESTION 'Which rules were blocked from the playbooks, and why?'
SQL 'SELECT rule_id, gate_hit, rule FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES
           WHERE NOT gate_ok ORDER BY rule_id'),
		VQ_FAILING_GATES AS (
QUESTION 'Are all pipeline checks passing?'
SQL 'SELECT kind, result, COUNT(*) AS checks FROM POSTMORTEM.RESULTS.PIPELINE_STATUS
           GROUP BY kind, result ORDER BY kind, result'),
		VQ_LATEST_EVAL AS (
QUESTION 'What were the latest evaluation scores for each agent?'
SQL 'SELECT target, metric_name, ROUND(avg_score, 2) AS avg_score, n FROM POSTMORTEM.RESULTS.EVAL_HISTORY
           QUALIFY captured_at = MAX(captured_at) OVER (PARTITION BY target) ORDER BY target, metric_name'),
		VQ_REPLAY_IMPORTS AS (
QUESTION 'How many replay runs came from the sandbox, by mode and model?'
SQL 'SELECT mode, model, runs, imported_runs, fresh_runs, unparsed_runs FROM POSTMORTEM.RESULTS.REPLAY_PROVENANCE
           ORDER BY mode, model')
	);
create or replace semantic view POSTMORTEM.LIVE.LIVE_SV
	tables (
		COMPARISON as POSTMORTEM.LIVE.LIVE_COMPARISON primary key (FY_REL) comment='Live case, one row per fiscal year: every view of revenue growth in percent.',
		RUNS as POSTMORTEM.LIVE.LIVE_RUNS_LATEST primary key (VARIANT,MODEL) comment='Latest live replay per variant: raw, playbook (learned rules), full (rules + prior-run lessons).',
		RECORD as POSTMORTEM.LIVE.PLAYBOOK_RECORD primary key (RULE_ID) comment='Every rule in the live playbook: direction, the past case it was learned from, its backtest record, and whether it fired today (fired_with_playbook = playbook run, fired_with_lessons = playbook + lessons run).',
		REPORT as POSTMORTEM.LIVE.SANITY_REPORT_LATEST primary key (DECISION_KEY) comment='Latest written sanity check.'
	)
	facts (
		COMPARISON.CLAUDE_RAW as claude_raw comment='Opus 4.6, masked packet only, growth %.',
		COMPARISON.CLAUDE_PLAYBOOK as claude_playbook comment='Opus 4.6 with the learned playbook, growth %.',
		COMPARISON.CLAUDE_PLAYBOOK_LESSONS as claude_playbook_lessons comment='Opus 4.6 with playbook and prior-run lessons, growth %.',
		COMPARISON.CLAUDE_RAW_BIAS_ADJUSTED as claude_raw_bias_adjusted comment='FY+1 raw growth corrected by Opus 4.6''s mean past FY+1 error.',
		COMPARISON.CONSENSUS as consensus comment='Consensus growth %, as of D-1.',
		COMPARISON.GUIDANCE_MID as guidance_mid comment='Latest management guide for FY+1, midpoint growth %.',
		COMPARISON.ANALYST as analyst comment='Firm_X analyst model growth %.',
		RUNS.FY1_GROWTH_PCT as fy1_growth_pct,
		RUNS.FY2_GROWTH_PCT as fy2_growth_pct,
		RUNS.FY3_GROWTH_PCT as fy3_growth_pct,
		RUNS.CONFIDENCE as confidence,
		RUNS.N_RULES_APPLIED as n_rules_applied,
		RECORD.TIMES_APPLIED_BACKTEST as times_applied_backtest comment='Round-1 backtest runs that applied the rule.',
		RECORD.NET_WINS_BACKTEST as net_wins_backtest comment='Wins minus losses in those runs: association, not proof.'
	)
	dimensions (
		COMPARISON.FY_REL as fy_rel comment='FY+1 = the year in progress at D0, then FY+2, FY+3.',
		RUNS.VARIANT as variant comment='raw | playbook | full',
		RUNS.MODEL as model,
		RUNS.VS_CONSENSUS as vs_consensus,
		RUNS.KEY_RISKS as key_risks,
		RECORD.RULE_ID as rule_id,
		RECORD.DIRECTION as direction comment='raise | lower | widen_range',
		RECORD.LEARNED_FROM_CASE as learned_from_case comment='Masked key of the past case the rule was learned from.',
		RECORD.RULE as rule,
		RECORD.FIRED_WITH_PLAYBOOK as fired_with_playbook comment='TRUE if the rule fired in today''s playbook run.',
		RECORD.FIRED_WITH_LESSONS as fired_with_lessons comment='TRUE if the rule fired in today''s playbook + lessons run.',
		REPORT.REPORT as report,
		REPORT.CREATED_AT as created_at
	)
	metrics (
		RECORD.RULES_IN_PLAYBOOK as COUNT(record.rule_id)
	)
	comment='Masked live sanity check: forecasts with and without past learnings, the rules that fired, and the report'
	ai_verified_queries (
		VQ_COMPARISON AS (
QUESTION 'Show every view of revenue growth by fiscal year for the live case.'
SQL 'SELECT * FROM POSTMORTEM.LIVE.LIVE_COMPARISON ORDER BY fy_rel'),
		VQ_PLAYBOOK_SHIFT AS (
QUESTION 'How much did the playbook and the lessons move Claude''s FY+1 forecast?'
SQL 'SELECT claude_raw, claude_playbook, claude_playbook_lessons,
                  ROUND(claude_playbook - claude_raw, 1) AS playbook_shift,
                  ROUND(claude_playbook_lessons - claude_playbook, 1) AS lessons_shift
           FROM POSTMORTEM.LIVE.LIVE_COMPARISON WHERE fy_rel = ''FY+1'''),
		VQ_RULES_FIRED AS (
QUESTION 'Which learned rules fired in the live forecast, and which past case did each come from?'
SQL 'SELECT rule_id, direction, learned_from_case, fired_with_playbook, fired_with_lessons, rule
           FROM POSTMORTEM.LIVE.PLAYBOOK_RECORD WHERE fired_with_playbook OR fired_with_lessons ORDER BY rule_id'),
		VQ_RULE_RECORD AS (
QUESTION 'How did the rules that fired today do in the backtest?'
SQL 'SELECT rule_id, direction, times_applied_backtest, net_wins_backtest, fired_with_playbook, fired_with_lessons
           FROM POSTMORTEM.LIVE.PLAYBOOK_RECORD WHERE fired_with_playbook OR fired_with_lessons
           ORDER BY net_wins_backtest DESC, times_applied_backtest DESC'),
		VQ_VS_CONSENSUS AS (
QUESTION 'What did Claude say about consensus in each variant''s latest run?'
SQL 'SELECT variant, fy1_growth_pct, vs_consensus FROM POSTMORTEM.LIVE.LIVE_RUNS_LATEST ORDER BY variant')
	);
