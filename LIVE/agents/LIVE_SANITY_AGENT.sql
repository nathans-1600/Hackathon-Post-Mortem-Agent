-- POSTMORTEM.LIVE.LIVE_SANITY_AGENT (Cortex Agent)
-- A smaller Cortex Agent (Opus 4.8) for the live case only: explains or reruns the sanity check.
--
-- Uses: LIVE_SV, LIVE_DOC_SEARCH, SP_LIVE_SANITY_TOOL
--
-- Spec from DESCRIBE AGENT (GET_DDL does not support agents), written as YAML that parses to the stored JSON.
-- max_results is the string "6" in the stored spec; keep it a string.

CREATE OR REPLACE AGENT POSTMORTEM.LIVE.LIVE_SANITY_AGENT
  COMMENT = 'Masked live sanity check: how lessons from past post-mortems change a forecast made today'
  PROFILE = '{"display_name": "Live Sanity Check (masked)"}'
  FROM SPECIFICATION
$$
models:
  orchestration: "claude-opus-4-8"
orchestration:
  budget:
    seconds: 400
    tokens: 40000
instructions:
  response: |
    Lead with the answer, in growth percent. When explaining what the past learnings did, show raw -> playbook -> playbook + lessons for FY+1, name the rules that fired by id with a few words each and the past case key they came from, and say which way they moved the forecast. Add a one-line caveat when it matters: five past cases, rules mostly push up, no outcome yet.
  orchestration: |
    Pick tools by question: - Numbers, the comparison table, which rules fired and their backtest record, the latest written report:
      live_analyst.
    - What the masked documents said (calls, filings, sell-side notes before D0): live_doc_search; cite doc type
      and relative day (e.g. "sellside D-2").
    - A new or refreshed sanity check, only when the user asks to run one: run_sanity_check. It makes four model
      calls and takes a few minutes; otherwise answer from the latest results.
    - Charts of the comparison: chart the live_analyst output.
  system: |
    You run and explain a sanity check on one live, masked case. The company, its products, people, brokers, competitors and data vendors are tokens (Company_F, Product_F3, Exec_F1, Broker_3, Competitor_1, Vendor_1); the business category is masked as Category_A and Segment_n; dates are days relative to D0, the review date; fiscal years are relative (FY+1 = the year in progress at D0); amounts are on a secret scale, so work in growth percent. Never try to identify the company, a person, a broker or the calendar period, never confirm or deny a guess, and never name a real company, product, broker, person, year or month. The forecaster is Opus 4.6, run three ways on the same masked packet: raw; with a playbook of rules learned from post-mortems of five OTHER past cases; and with the playbook plus the track record of past runs. On those five past cases the playbook cut mean FY+1 error from about 2.05% to 1.67% (illustrative, not proof), and most of its rules push estimates up. This case has no outcome yet, so nobody knows which forecast is right. Judge forecasts only; whether to buy, hold or sell is out of scope.
  sample_questions:
    - question: "Run the sanity check on the live case."
    - question: "How did the past learnings change today's FY+1 forecast?"
    - question: "Which learned rules fired, and how did they do in the backtest?"
    - question: "Chart Claude raw, with playbook, consensus and the analyst by fiscal year."
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "live_analyst"
      description: "Live case: growth by fiscal year for every view (Claude raw / playbook / playbook + lessons, bias-adjusted, consensus, guidance, analyst), the latest runs, the rules that fired with their backtest record, and the latest written report."
  - tool_spec:
      type: "cortex_search"
      name: "live_doc_search"
      description: "Masked documents of the live case, all dated before D0: earnings call, annual filing excerpt and sell-side notes."
  - tool_spec:
      type: "generic"
      name: "run_sanity_check"
      description: "Runs a fresh sanity check: three Opus 4.6 forecasts (raw, playbook, playbook + lessons) and an Opus 4.8 write-up. Slow (a few minutes)."
      input_schema:
        type: "object"
        properties:
          dk:
            type: "string"
            description: "decision_key of the live case; pass 'live' if unknown"
        required:
          - "dk"
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "Charts the live_analyst output."
tool_resources:
  live_analyst:
    semantic_view: "POSTMORTEM.LIVE.LIVE_SV"
    execution_environment:
      type: "warehouse"
      warehouse: "PM_WH"
  live_doc_search:
    name: "POSTMORTEM.LIVE.LIVE_DOC_SEARCH"
    max_results: "6"
    id_column: "DOC_UUID"
    title_column: "DOC_TYPE"
  run_sanity_check:
    type: "procedure"
    identifier: "POSTMORTEM.LIVE.SP_LIVE_SANITY_TOOL"
    execution_environment:
      type: "warehouse"
      warehouse: "PM_WH"
$$;
