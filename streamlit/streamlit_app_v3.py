"""Decision Post-Mortem: Streamlit in Snowflake app (POSTMORTEM.APP.POSTMORTEM_APP).

Read-only. Every query reads masked data: backtest cases are decision keys, the live case is Company_F, and the
firm's own source label is shown as Firm_X. Nothing here calls a model, so opening the app costs only warehouse time.
"""
import altair as alt
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Decision Post-Mortem", layout="wide")
session = get_active_session()

FIRM = "Firm_X"
PASS_BAR = {"answer_correctness": 0.80, "logical_consistency": 0.75, "tool_selection_accuracy": 0.75,
            "tool_execution_accuracy": 0.60, "masking_compliance": 0.90, "live_honesty": 0.90,
            "evidence_honesty": 0.90, "sql_correctness": 0.70}


@st.cache_data(ttl=300)
def q(sql: str) -> pd.DataFrame:
    df = session.sql(sql).to_pandas()
    df.columns = [c.lower() for c in df.columns]
    return df


def mask(col: str) -> str:
    """SQL: show the firm's own source label as Firm_X."""
    return f"REGEXP_REPLACE({col}, 'parnassus', '{FIRM}', 1, 0, 'i')"


SOURCE_LABEL = f"""CASE source
    WHEN 'parnassus' THEN '{FIRM} (us)'
    WHEN 'consensus' THEN 'Consensus'
    WHEN 'guidance_mid' THEN 'Guidance midpoint'
    ELSE 'Claude ' || REPLACE(source, 'claude_', '') || IFF(model = 'claude-opus-4-8', ' [4.8 control]', ' [4.6]') END"""

cases = q("""SELECT decision_key, tier FROM POSTMORTEM.MASKED.POSITIONS WHERE NOT is_live ORDER BY decision_key""")
case_label = {k: f"Case {i + 1} ({k})" for i, k in enumerate(cases["decision_key"])}

st.title("Decision Post-Mortem")
st.caption("Masked backtest of five past investment reviews, a self-learning playbook, and a live sanity check. "
           "Companies, people, brokers and dates are tokens; amounts are on a secret scale, so everything is in %. "
           f"Claude Opus 4.6 is the clean forecaster (no knowledge after the review dates); Opus 4.8 is a "
           f"contaminated control and is never averaged with 4.6. {FIRM} = our own projections.")

with st.expander("Who's who: what each forecaster means", expanded=True):
    st.markdown(f"""
| Forecaster | What it is |
|---|---|
| **{FIRM} (us)** | Our own analyst's FY+1 to FY+3 revenue projection, from the investment review on the review date (D0). |
| **Consensus** | The sell-side mean revenue estimate as of the day before the review. |
| **Guidance midpoint** | Midpoint of management's latest full-year revenue guide issued before the review. Only cases with a guide (see n). |
| **Claude independent** | Claude reads the same masked pre-review packet (filings, call transcripts, sell-side notes, consensus, guidance, reported revenue) and forecasts on its own. It never sees our memo. |
| **Claude clone** | Same packet, plus our house process and masked reviews of *other* companies, so it forecasts the way a {FIRM} analyst would. Tests whether our style helps or hurts. |
| **Claude factsheet** | Claude first boils the packet down to a 600-word fact sheet, then forecasts from the sheet alone. Tests whether less raw text changes the call. |
| **[4.6]** | Claude Opus 4.6: the clean forecaster. Its knowledge stops before the review dates; probes found no recall of outcomes. |
| **[4.8 control]** | Claude Opus 4.8: a contaminated control that may know what happened. Shown for comparison only, never averaged with 4.6. |

**Error** = forecast / reported revenue - 1. Negative = forecast too low. Absolute error = size of the miss either way.
""")

tabs = st.tabs(["How did we do", "Where each went wrong", "Institutional biases", "Learning loop",
                "Live sanity check: Company_F", "Evals"])

# ------------------------------------------------------------------------------------------------------------------
with tabs[0]:
    st.subheader("FY+1 revenue error by forecaster, across the five backtest cases")
    sb = q(f"""SELECT {SOURCE_LABEL} AS forecaster, model,
                      ROUND(AVG(abs_pct_error), 2) AS mean_abs_error, ROUND(AVG(pct_error), 2) AS mean_signed_error,
                      COUNT(*) AS n
               FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1'
               GROUP BY 1, 2 ORDER BY mean_abs_error""")
    clean = sb[sb["model"].fillna("") != "claude-opus-4-8"]
    c1, c2, c3, c4 = st.columns(4)
    def metric(col, label, name):
        row = clean[clean["forecaster"] == name]
        if len(row):
            col.metric(label, f"{row['mean_abs_error'].iloc[0]:.2f}%",
                       f"{row['mean_signed_error'].iloc[0]:+.2f}% bias", delta_color="off")
    metric(c1, f"{FIRM} (us)", f"{FIRM} (us)")
    metric(c2, "Claude independent (4.6)", "Claude independent [4.6]")
    metric(c3, "Consensus", "Consensus")
    metric(c4, "Guidance midpoint", "Guidance midpoint")
    st.caption("Mean absolute FY+1 error (lower is better); the small number is the signed bias "
               "(negative = forecast below reported revenue). Guidance exists for only some cases (see n).")

    left, right = st.columns(2)
    left.altair_chart(alt.Chart(clean).mark_bar().encode(
        x=alt.X("mean_abs_error:Q", title="Mean abs FY+1 error, %"),
        y=alt.Y("forecaster:N", sort="x", title=None),
        tooltip=["forecaster", "mean_abs_error", "mean_signed_error", "n"]).properties(height=260,
        title="Accuracy (Opus 4.8 control excluded)"), use_container_width=True)
    right.altair_chart(alt.Chart(clean).mark_bar().encode(
        x=alt.X("mean_signed_error:Q", title="Mean signed FY+1 error, % (negative = too low)"),
        y=alt.Y("forecaster:N", sort="x", title=None),
        color=alt.condition("datum.mean_signed_error < 0", alt.value("#c0392b"), alt.value("#2e86c1")),
        tooltip=["forecaster", "mean_signed_error", "n"]).properties(height=260, title="Bias direction"),
        use_container_width=True)

    st.markdown("**All forecasters, including the Opus 4.8 contaminated control**")
    st.dataframe(sb.drop(columns=["model"]), use_container_width=True)

    st.markdown("**FY+1 signed error by case** (negative = forecast too low)")
    per_case = q(f"""SELECT decision_key, {SOURCE_LABEL} AS forecaster, ROUND(pct_error, 2) AS pct_error
                     FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1'""")
    per_case["case"] = per_case["decision_key"].map(case_label)
    st.altair_chart(alt.Chart(per_case).mark_rect().encode(
        x=alt.X("case:N", title=None), y=alt.Y("forecaster:N", title=None),
        color=alt.Color("pct_error:Q", scale=alt.Scale(scheme="redblue", domainMid=0), title="% error"),
        tooltip=["case", "forecaster", "pct_error"]).properties(height=320), use_container_width=True)

# ------------------------------------------------------------------------------------------------------------------
with tabs[1]:
    st.subheader("Where each forecaster went wrong, case by case")
    pick = st.selectbox("Case", list(case_label.keys()), format_func=lambda k: case_label[k])
    errs = q(f"""SELECT {SOURCE_LABEL} AS forecaster, ROUND(pct_error, 2) AS fy1_pct_error,
                        ROUND(abs_pct_error, 2) AS fy1_abs_error
                 FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1' AND decision_key = '{pick}'
                 ORDER BY fy1_abs_error""")
    st.dataframe(errs, use_container_width=True)

    rep = q(f"""SELECT {mask('projected')} AS projected, {mask('reported')} AS reported, {mask('gap')} AS gap,
                       {mask('closer_sources')} AS closer_sources, {mask('change_next_time')} AS change_next_time,
                       {mask("COALESCE(data_to_add_next_time, '')")} AS data_to_add
                FROM POSTMORTEM.RESULTS.PM_REPORTS WHERE decision_key = '{pick}'""")
    if len(rep):
        r = rep.iloc[0]
        a, b = st.columns(2)
        a.markdown(f"**What {FIRM} projected**\n\n{r['projected']}")
        b.markdown(f"**What was reported**\n\n{r['reported']}")
        st.markdown(f"**The gap**\n\n{r['gap']}")
        st.markdown(f"**Who came closer, and why**\n\n{r['closer_sources']}")
    fnd = q(f"""SELECT finding_group, {mask('finding')} AS finding, {mask("COALESCE(source, '')")} AS evidence,
                       COALESCE(public_date, '') AS public_date, {mask("COALESCE(effect, '')")} AS effect
                FROM POSTMORTEM.RESULTS.PM_FINDINGS WHERE decision_key = '{pick}' ORDER BY finding_group""")
    for grp, title, note in [
            ("1", "1. In our packet, but underweighted", "A lesson: we had it and didn't use it enough."),
            ("2", "2. Public before the review, missing from our packet", "Unverified checklist item, with its date."),
            ("3", "3. Only knowable afterwards", "Explains the miss. Never a lesson: nobody could have seen it.")]:
        part = fnd[fnd["finding_group"].str.startswith(grp)]
        with st.expander(f"{title} ({len(part)})", expanded=(grp == "1")):
            st.caption(note)
            st.dataframe(part.drop(columns=["finding_group"]), use_container_width=True)
    if len(rep):
        st.success(f"**Change next time:** {rep.iloc[0]['change_next_time']}")
        if rep.iloc[0]["data_to_add"]:
            st.info(f"**Data to add next time (unverified):** {rep.iloc[0]['data_to_add']}")

# ------------------------------------------------------------------------------------------------------------------
with tabs[2]:
    st.subheader("Institutional biases: patterns tagged by the post-mortems")
    st.caption("A tag needs that forecaster's FY+1 miss to be at least 2%. 'about' says whose projection it describes.")
    tags = q(f"""SELECT IFF(about = 'firm_x', '{FIRM} (us)', INITCAP(about)) AS about, tag, decision_key, strength,
                        {mask('evidence')} AS evidence
                 FROM POSTMORTEM.RESULTS.PM_TAGS ORDER BY about, tag""")
    counts = tags.groupby(["about", "tag"]).size().reset_index(name="tags")
    st.altair_chart(alt.Chart(counts).mark_bar().encode(
        x=alt.X("tags:Q", title="Tags"), y=alt.Y("tag:N", sort="-x", title=None),
        color=alt.Color("about:N", title="Whose projection"), tooltip=["about", "tag", "tags"]).properties(height=260),
        use_container_width=True)
    bias = q("""SELECT ROUND(AVG(pct_error), 2) AS m, COUNT(*) AS n FROM POSTMORTEM.RESULTS.ERRORS
                WHERE source = 'parnassus' AND fy_rel = 'FY+1'""")
    if len(bias) and bias["m"].iloc[0] is not None:
        m = bias["m"].iloc[0]
        st.markdown(f"**{FIRM} on average projected FY+1 {'too low' if m < 0 else 'too high'} by "
                    f"{abs(m):.2f}%** (mean signed error, n={int(bias['n'].iloc[0])}). With five cases this is an "
                    "illustration, not a statistical finding.")
    who = st.radio("Show evidence for", ["All"] + sorted(tags["about"].unique().tolist()), horizontal=True)
    shown = tags if who == "All" else tags[tags["about"] == who]
    shown = shown.assign(case=shown["decision_key"].map(case_label)).drop(columns=["decision_key"])
    st.dataframe(shown, use_container_width=True)

# ------------------------------------------------------------------------------------------------------------------
with tabs[3]:
    st.subheader("Learning loop: rules learned from the post-mortems, tested leave-one-out")
    st.caption("Each case is re-forecast by Opus 4.6 with rules learned only from the OTHER cases (round 1), then "
               "with a pruned playbook judged on runs that never saw that case (round 2). A gain smaller than "
               "run-to-run noise is no gain.")
    ls = q("""SELECT decision_key, baseline_abs_err, round1_abs_err, round2_abs_err, round2_gain_pts, noise_pts,
                     round1_rules, round2_rules FROM POSTMORTEM.RESULTS.LEARN_SUMMARY ORDER BY decision_key""")
    if len(ls):
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Baseline mean abs error", f"{ls['baseline_abs_err'].mean():.2f}%")
        c2.metric("With playbook", f"{ls['round2_abs_err'].mean():.2f}%",
                  f"{-ls['round2_gain_pts'].mean():+.2f} pts", delta_color="inverse")
        c3.metric("Wins / losses", f"{(ls['round2_gain_pts'] > 0).sum()} / {(ls['round2_gain_pts'] < 0).sum()}")
        c4.metric("Run-to-run noise", f"{ls['noise_pts'].iloc[0]:.2f} pts")
        long = ls.assign(case=ls["decision_key"].map(case_label)).melt(
            id_vars=["case"], value_vars=["baseline_abs_err", "round1_abs_err", "round2_abs_err"],
            var_name="run", value_name="abs_error")
        long["run"] = long["run"].map({"baseline_abs_err": "Baseline", "round1_abs_err": "Round 1",
                                       "round2_abs_err": "Round 2"})
        st.altair_chart(alt.Chart(long).mark_bar().encode(
            x=alt.X("run:N", title=None), y=alt.Y("abs_error:Q", title="FY+1 abs error, %"),
            color="run:N", column=alt.Column("case:N", title=None),
            tooltip=["case", "run", "abs_error"]).properties(width=110, height=220))
    st.markdown("**Rules** (net wins = association over round-1 runs, not proof a rule caused a gain)")
    rules = q("""SELECT rule_id, direction, source_key AS learned_from_case, times_applied, net_wins,
                        in_live_playbook, gate_ok, gate_hit, rule
                 FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES ORDER BY gate_ok DESC, net_wins DESC NULLS LAST, rule_id""")
    st.dataframe(rules, use_container_width=True)
    if len(rules):
        d = rules[rules["gate_ok"] == True]["direction"].value_counts()
        st.caption("Active rules by direction: " + ", ".join(f"{k} {v}" for k, v in d.items())
                   + ". Most say raise: they were learned in a period that rewarded optimism.")

# ------------------------------------------------------------------------------------------------------------------
with tabs[4]:
    st.subheader("Live sanity check: Company_F (masked; no outcome yet)")
    st.caption("The same Opus 4.6 forecaster run three ways on one masked packet: raw; with the learned playbook; "
               "with the playbook plus the track record of past runs. Nobody knows yet which forecast is right.")
    st.markdown(f"""
| View | What it is |
|---|---|
| **Claude raw** | Opus 4.6 on the masked packet only: the independent forecast, no past learnings. |
| **Claude + playbook** | Same, plus the rules learned from the five past post-mortems. Shows what the learnings changed. |
| **Claude + playbook + lessons** | Same, plus the track record of past runs (who erred which way, bias tags, change next time). |
| **Claude raw, bias-adjusted** | The raw FY+1 forecast corrected by Opus 4.6's average past FY+1 error: a statistical fix, not a new forecast. |
| **Consensus / Guidance midpoint** | Sell-side mean as of D-1 / midpoint of the latest management guide. |
| **{FIRM} analyst** | Our analyst's projection in the review. |
""")
    lc = q("""SELECT fy_rel, claude_raw, claude_playbook, claude_playbook_lessons, claude_raw_bias_adjusted,
                     consensus, guidance_mid, analyst FROM POSTMORTEM.LIVE.LIVE_COMPARISON ORDER BY fy_rel""")
    if len(lc):
        fy1 = lc[lc["fy_rel"] == "FY+1"].iloc[0]
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Claude raw FY+1", f"{fy1['claude_raw']:.1f}%")
        c2.metric("+ playbook", f"{fy1['claude_playbook']:.1f}%",
                  f"{fy1['claude_playbook'] - fy1['claude_raw']:+.1f} pts")
        c3.metric("Consensus", f"{fy1['consensus']:.1f}%")
        c4.metric("Guidance mid", f"{fy1['guidance_mid']:.1f}%")
        c5.metric(f"{FIRM} analyst", f"{fy1['analyst']:.1f}%")
        names = {"claude_raw": "Claude raw", "claude_playbook": "Claude + playbook",
                 "claude_playbook_lessons": "Claude + playbook + lessons", "claude_raw_bias_adjusted": "Claude raw, bias-adjusted",
                 "consensus": "Consensus", "guidance_mid": "Guidance midpoint", "analyst": f"{FIRM} analyst"}
        long = lc.melt(id_vars=["fy_rel"], var_name="view", value_name="growth").dropna()
        long["view"] = long["view"].map(names)
        st.altair_chart(alt.Chart(long).mark_line(point=True).encode(
            x=alt.X("fy_rel:N", title=None), y=alt.Y("growth:Q", title="Revenue growth, %", scale=alt.Scale(zero=False)),
            color=alt.Color("view:N", title=None), tooltip=["fy_rel", "view", "growth"]).properties(height=320),
            use_container_width=True)
        st.dataframe(lc.rename(columns=names), use_container_width=True)

    st.markdown("**How past learnings bled into today's forecast: rules that fired**")
    pr = q("""SELECT rule_id, direction, learned_from_case, fired_with_playbook, fired_with_lessons,
                     times_applied_backtest, net_wins_backtest, rule
              FROM POSTMORTEM.LIVE.PLAYBOOK_RECORD WHERE fired_with_playbook OR fired_with_lessons
              ORDER BY net_wins_backtest DESC, rule_id""")
    pr["learned_from_case"] = pr["learned_from_case"].map(lambda k: case_label.get(k, k))
    st.dataframe(pr, use_container_width=True)
    st.caption("Every rule comes from a different past case. Backtest record is association over five cases, not proof.")

    runs = q("""SELECT variant, run_at, fy1_growth_pct, confidence, n_rules_applied, vs_consensus
                FROM POSTMORTEM.LIVE.LIVE_RUNS_LATEST WHERE model = 'claude-opus-4-6' ORDER BY variant DESC""")
    with st.expander("What Claude said about consensus, per run"):
        st.dataframe(runs, use_container_width=True)

    rpt = q("""SELECT created_at, report FROM POSTMORTEM.LIVE.SANITY_REPORT_LATEST""")
    if len(rpt):
        st.markdown(f"**Written sanity check** (Opus 4.8, {rpt['created_at'].iloc[0]:%Y-%m-%d %H:%M})")
        st.markdown(rpt["report"].iloc[0])
    st.warning("Caveats: the playbook was tested on five past cases (an illustration, not proof); most of its rules "
               "push estimates up; this case has no outcome yet.")

# ------------------------------------------------------------------------------------------------------------------
with tabs[5]:
    st.subheader("Agent evaluations (latest run per target)")
    ev = q("""WITH h AS (
                SELECT *, CASE WHEN run_name ILIKE '%backtest%' THEN 'backtest questions'
                               WHEN target ILIKE '%_SV' THEN 'verified queries' ELSE 'live questions' END AS question_set
                FROM POSTMORTEM.RESULTS.EVAL_HISTORY)
              SELECT target, question_set, run_name, metric_name, avg_score, n FROM h
              QUALIFY run_name = FIRST_VALUE(run_name) OVER (PARTITION BY target, question_set ORDER BY captured_at DESC)
              ORDER BY target, question_set, metric_name""")
    if len(ev):
        ev["bar"] = ev["metric_name"].map(PASS_BAR)
        ev["pass"] = ev.apply(lambda r: "PASS" if pd.isna(r["bar"]) or r["avg_score"] >= r["bar"] else "BELOW BAR", axis=1)
        st.dataframe(ev[["target", "question_set", "run_name", "metric_name", "avg_score", "bar", "pass", "n"]],
                     use_container_width=True)
        st.caption("Scores 0-1 (custom 0-2 judges divided by 2). Masking and honesty are judged by Claude Sonnet 4.6; "
                   "a judge parse error is excluded rather than counted as 0 (n shows it).")
    gates = q("""SELECT check_id, kind, check_name, result, detail FROM POSTMORTEM.RESULTS.PIPELINE_STATUS ORDER BY check_id""")
    with st.expander("Pipeline and hindsight gates"):
        st.dataframe(gates, use_container_width=True)



