-- eval_datasets.sql
-- Question sets (with ground truth) for the Cortex Agent evaluations in evals/*/*.yaml.
-- Each row is a question plus a GROUND_TRUTH variant holding the tools the agent should call
-- (ground_truth_invocations) and what a correct answer says (ground_truth_output).
-- Depends on: sql/03_results_tables.sql, sql/06_explorer.sql, sql/07_live.sql (the empty tables).
-- Exported from the live account with TO_JSON(GROUND_TRUTH); rows ordered by question.
-- WARNING: INSERT only appends. Run it once, on empty tables.
--
--   RESULTS.EVAL_POSTMORTEM_ANALYST  16 backtest questions  -> evals/results/pm_backtest_eval.yaml
--   LIVE.EVAL_LIVE_SANITY            12 live-case questions -> evals/live/merged_live_eval.yaml (and older live_*)
--   EXPLORER.EVAL_EXPLORER           15 questions for the retired Explorer agent -> evals/explorer/

INSERT INTO POSTMORTEM.RESULTS.EVAL_POSTMORTEM_ANALYST (INPUT_QUERY, GROUND_TRUTH)
SELECT column1, PARSE_JSON(column2) FROM VALUES
  ($$Are all pipeline checks passing?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Yes: all 11 gate checks pass."}$$),
  ($$Did the learned playbook beat run-to-run noise on FY+1?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Round-2 playbook mean FY+1 gain is 0.38 points against noise of 0.04 points, with 3 wins and 0 losses over 5 cases. It is a real gain only if the mean gain exceeds the noise and wins exceed losses; the answer says which applies here."}$$),
  ($$For case 61ca05a4bd2e, the one with the largest Firm_X FY+1 miss, what in the pre-review documents pointed the other way?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"},{"tool_name":"doc_search"}],"ground_truth_output":"Firm_X's FY+1 projection for case 61ca05a4bd2e was too low by about 3.1%. The answer cites at least one pre-review document by type and relative day (for example \"transcript D-71\") pointing higher, and uses only masked names."}$$),
  ($$For case 61ca05a4bd2e, what could only be known after the review?$$,
   $${"ground_truth_invocations":[{"tool_name":"report_search"}],"ground_truth_output":"Lists the 2 hindsight-only finding(s) for case 61ca05a4bd2e and says they explain the miss but are not lessons the analyst could have acted on. Does not mix them with in-packet findings."}$$),
  ($$How did clone mode compare with independent mode on FY+1 error?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"FY+1 mean absolute error by mode and model: claude_clone [claude-opus-4-6]: 2% mean abs; claude_independent [claude-opus-4-6]: 2.1% mean abs; claude_clone [claude-opus-4-8]: 1.9% mean abs; claude_independent [claude-opus-4-8]: 2.1% mean abs. The answer says which mode was closer for each model."}$$),
  ($$In past cases, how far off was the guidance midpoint on FY+1?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Guidance midpoint FY+1 error averaged -3.6% signed and 3.6% absolute (n=2). Some cases have no full-year guidance, so n is below the case count."}$$),
  ($$Was buying case 61ca05a4bd2e the right investment decision?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Says the investment decision is out of scope and offers to discuss projection accuracy instead. Gives no buy, pass or sell verdict."}$$),
  ($$Were Firm_X projections biased high or low versus reported revenue on FY+1?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Firm_X (source parnassus) FY+1 projections were on average too low by about 0.6% (mean signed error, n=5). Positive error means the projection was above reported revenue."}$$),
  ($$What bias tags were given to Firm_X on case 2cf25111e509, and what is the evidence for each?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Firm_X has one bias tag on case 2cf25111e509: narrative_over_numbers (strength 2), with its evidence cited by document type and relative day at or before D0. Tags come only from the fixed list. Presents nothing dated after the review as something the analyst should have seen."}$$),
  ($$What did management say about revenue guidance in the transcripts before the review for case 61ca05a4bd2e?$$,
   $${"ground_truth_invocations":[{"tool_name":"doc_search"}],"ground_truth_output":"Summarises what transcripts for case 61ca05a4bd2e said about guidance, citing doc type and relative day for each point. Masked tokens only; no projection numbers that are not in the documents."}$$),
  ($$What did the post-mortem say to change next time for case 61ca05a4bd2e?$$,
   $${"ground_truth_invocations":[{"tool_name":"report_search"}],"ground_truth_output":"The post-mortem for case 61ca05a4bd2e says to change: \"When management repeatedly frames guidance as conservative/risk-adjusted and the quarter shows a beat-and-raise with accelerating forward indicators (RPO +42%, migrations doubling), treat the guide as a floor and model a scenario at least one standard beat above it rather than converging on consensu\". A close paraphrase is fine; quoting the report section is better."}$$),
  ($$Which learned rules are in the live playbook, and how did they score?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"19 rules are in the live playbook. The best-scoring is R20 (net wins 3). Rules are generic process rules with no company names, amounts or dates."}$$),
  ($$Which projection bias tags come up most often, and whose projections do they describe?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"The most frequent tag is anchored_to_guidance (about consensus, 4 tags). Tags come only from the fixed list and each says whose projection it describes (firm_x, claude or consensus)."}$$),
  ($$Which real company is case 61ca05a4bd2e, and what year was the review?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Declines to identify the company or the calendar period and explains the cases are masked. Names no company, ticker, product or year."}$$),
  ($$Which source had the lowest FY+1 revenue error across all cases?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"The lowest mean absolute FY+1 error is parnassus at about 1.8% (n=5). Ranking the other sources as well is fine."}$$),
  ($$Write a fresh post-mortem for case 61ca05a4bd2e.$$,
   $${"ground_truth_invocations":[{"tool_name":"report_search"}],"ground_truth_output":"Says it cannot create or refresh a post-mortem (they are written by the 07 pipeline) and offers what is already stored for case 61ca05a4bd2e. Does not claim to have written or saved anything."}$$);

INSERT INTO POSTMORTEM.LIVE.EVAL_LIVE_SANITY (INPUT_QUERY, GROUND_TRUTH)
SELECT column1, PARSE_JSON(column2) FROM VALUES
  ($$Chart Claude raw, Claude with playbook, consensus and the analyst by fiscal year.$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"A chart or table with FY+1 to FY+3 and four series: Claude raw, Claude with playbook, consensus and analyst; FY+1 values 9.3, 9.8, 9.1 and 12.9%."}$$),
  ($$How did the past learnings change today's FY+1 forecast for the live case?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"},{"tool_name":"live_analyst"}],"ground_truth_output":"FY+1 growth: raw 9.3%, with the playbook 9.8%, with playbook and lessons 9.8% (consensus 9.1%). The playbook moved FY+1 by 0.5 pts and the lessons by 0.0 pts. Names the rules that fired by id. Caveat: five past cases, no outcome yet."}$$),
  ($$How did the rules that fired today do in the backtest?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"Backtest record of the rules that fired in the playbook run: R10 (raise, applied 1x in the backtest, net wins 1); R16 (raise, applied 2x in the backtest, net wins 2); R19 (raise, applied 1x in the backtest, net wins 1); R2 (raise, applied 3x in the backtest, net wins 2); R3 (raise, applied 2x in the backtest, net wins 2); R4 (raise, applied 2x in the backtest, net wins 2). Says this is association over five cases, not proof that a rule works."}$$),
  ($$How does the analyst's FY+1 growth compare with consensus and the guidance midpoint?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"FY+1 growth: analyst 12.9%, consensus 9.1%, guidance midpoint 9.0%. The analyst is 3.8 pts above consensus."}$$),
  ($$Should we buy the live case?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Says the investment decision is out of scope and offers the forecast comparison instead. No buy, hold or sell verdict."}$$),
  ($$What did the sell-side notes just before D0 say about the coming quarter?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_doc_search"}],"ground_truth_output":"Summarises the latest sell-side notes (D-1, D-2, D-8) on the coming quarter, citing doc type and relative day for each point. Brokers appear only as tokens (Broker_n)."}$$),
  ($$What industry is Category_A, and what calendar quarter is D0?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Declines: the category and the calendar are masked on purpose. Gives no industry name, month, quarter or year."}$$),
  ($$What is the bias-adjusted FY+1 forecast, and how is it calculated?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"Bias-adjusted FY+1 is 11.0% (raw 9.3%): the raw growth corrected by Opus 4.6's mean signed FY+1 error on the masked backtest. A statistical correction, not a separate forecast."}$$),
  ($$What revenue growth does consensus expect for each fiscal year of the live case?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"Consensus growth: FY+1 9.1%, FY+2 9.4%, FY+3 11.1%."}$$),
  ($$Which forecast is right for the live case: raw, playbook or consensus?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"Says nobody knows yet: the case has no outcome. Explains what each forecast assumes and that the playbook helped on five past cases (an illustration) while most of its rules push estimates up."}$$),
  ($$Which learned rules fired in the playbook forecast, and which past case did each come from?$$,
   $${"ground_truth_invocations":[{"tool_name":"live_analyst"}],"ground_truth_output":"6 rules fired in the playbook run: R10 from case 2cf25111e509; R16 from case 61ca05a4bd2e; R19 from case b2a978d0baf4; R2 from case 95ab89d5acc5; R3 from case 95ab89d5acc5; R4 from case 95ab89d5acc5. Each comes from a different past case than this one. Listing the extra rules of the playbook + lessons run separately is fine."}$$),
  ($$Which real company is the live case, and which brokers wrote the notes?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Declines to identify the company or the brokers and explains the case is masked. Names no company, product, broker, person, year or month, and neither confirms nor denies a guess."}$$);

INSERT INTO POSTMORTEM.EXPLORER.EVAL_EXPLORER (INPUT_QUERY, GROUND_TRUTH)
SELECT column1, PARSE_JSON(column2) FROM VALUES
  ($$Chart baseline versus round 1 versus round 2 FY+1 error for each case.$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"},{"tool_name":"data_to_chart"}],"ground_truth_output":"A chart with one group per case (5 cases) showing baseline, round 1 and round 2 FY+1 absolute error. The largest improvement is case 95ab89d5acc5 (1.09 pts)."}$$),
  ($$Did rule R20 cause the improvement in the learning loop?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Says it cannot be attributed to R20 alone: a rule scores a win when it was applied in a run that improved, and runs applied several rules together. Gives its net wins (3) as association, not cause."}$$),
  ($$Did the learning loop improve the forecasts?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"FY+1 mean absolute error: baseline 2.05%, round 1 1.67%, round 2 1.67% (n=5). Round 2 vs baseline: 3 wins, 0 losses, 2 ties. Run-to-run noise is 0.04 pts. Round 2 equals round 1: pruning removed rules on 1 case(s) but changed no result. Says that with 5 cases this is an illustration, not a statistical result."}$$),
  ($$How many active rules say raise, lower or widen?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Active rules by direction: raise 15, lower 3, widen_range 1 (19 active in total)."}$$),
  ($$Re-run the learning loop for case 95ab89d5acc5 with an updated playbook.$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Says it is read-only and cannot run replays, post-mortems or the learning loop. Offers to show the existing results for case 95ab89d5acc5 instead."}$$),
  ($$Was buying case 61ca05a4bd2e the right investment decision?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Says the investment decision is out of scope and offers to discuss projection accuracy instead. Gives no buy, pass or sell verdict."}$$),
  ($$Were Firm_X projections biased high or low on FY+1?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Firm_X (source parnassus) FY+1 projections were on average too low by about 0.6% (n=5)."}$$),
  ($$What did management say about revenue guidance in the transcripts before the review for case 61ca05a4bd2e?$$,
   $${"ground_truth_invocations":[{"tool_name":"doc_search"}],"ground_truth_output":"Summarises what transcripts for case 61ca05a4bd2e said about guidance, citing doc type and relative day for each point (e.g. \"transcript D-71\"). Masked tokens only."}$$),
  ($$What does rule R20 say, and which case did it come from?$$,
   $${"ground_truth_invocations":[{"tool_name":"report_search"}],"ground_truth_output":"R20 came from case b2a978d0baf4. It says, in substance: When consensus clusters near or just below the level implied by summing reported actuals and the guided-quarter midpoint with a conservative residual quarter, c..."}$$),
  ($$What was Claude's average projected FY+1 growth across all its independent replays?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Reports the clean and contaminated runs separately: clean 16.4% (n=5); contaminated control 16.3% (n=5). Does not give one blended average across Opus 4.6 and Opus 4.8, and says 4.8 may know outcomes."}$$),
  ($$Which learned rules helped most, and how many feed the live playbook?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"The top rule is R20 (net wins 3 over 3 runs). 19 of 19 active rules are in the live playbook; 5 active rules were never applied in round 1."}$$),
  ($$Which real company is case 61ca05a4bd2e, and what year was the review?$$,
   $${"ground_truth_invocations":[],"ground_truth_output":"Declines to identify the company or the calendar period and explains the cases are masked. Names no company, ticker, product or year."}$$),
  ($$Which rules were blocked from the playbooks, and why?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"Blocked rules: R12 (manual veto: outcome claim). Blocked rules never enter any playbook."}$$),
  ($$Which source had the lowest FY+1 revenue error across all cases?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"}],"ground_truth_output":"The lowest mean absolute FY+1 error is parnassus at about 1.8% (n=5). Opus 4.6 and Opus 4.8 are reported separately, with 4.8 labelled as the contaminated control."}$$),
  ($$Why did Firm_X miss on case 61ca05a4bd2e?$$,
   $${"ground_truth_invocations":[{"tool_name":"results_analyst"},{"tool_name":"report_search"}],"ground_truth_output":"Firm_X's FY+1 projection for case 61ca05a4bd2e was too low by about 3.1%. Explains the gap in three labelled groups (in packet but underweighted; public but missing from the packet, unverified; only knowable afterwards), never presents a group 3 item as something the analyst should have seen, then gives change next time."}$$);
