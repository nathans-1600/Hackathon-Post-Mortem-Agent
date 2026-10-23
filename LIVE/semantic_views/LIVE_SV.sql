-- POSTMORTEM.LIVE.LIVE_SV (semantic view (Cortex Analyst))
-- Cortex Analyst semantic view for the live sanity check: the comparison by fiscal year, latest runs,
-- playbook record and the latest report.
--
-- Uses: LIVE_COMPARISON, LIVE_RUNS_LATEST, PLAYBOOK_RECORD, SANITY_REPORT_LATEST

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
