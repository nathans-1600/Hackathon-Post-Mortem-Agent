"""Decision Post-Mortem: Streamlit in Snowflake app (POSTMORTEM.APP.POSTMORTEM_APP).

Read-only. Every query reads masked data: backtest cases are decision keys, the live case is Company_F, and the
firm's own source label is shown as Firm_X. Nothing here calls a model, so opening the app costs only warehouse time.
Labels are plain words; each tab ends with a Definitions block. Tables, tiles and axis labels wrap instead of
truncating (st.dataframe clips cells, so tables are rendered as HTML).
"""
import html
import json

import altair as alt
import numpy as np
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Decision Post-Mortem", layout="wide")
session = get_active_session()

st.markdown("""<style>
.pm-table {width: 100%; border-collapse: collapse; font-size: 0.9rem; margin: 0.25rem 0 1rem 0;}
.pm-table th, .pm-table td {border: 1px solid rgba(128,128,128,0.3); padding: 6px 8px; text-align: left;
                            vertical-align: top; white-space: normal; word-break: break-word;}
.pm-table th {background: rgba(128,128,128,0.08); font-weight: 600;}
.pm-card {padding: 0.25rem 0 0.75rem 0;}
.pm-card .pm-label {font-size: 0.9rem; opacity: 0.75; white-space: normal;}
.pm-card .pm-value {font-size: 1.8rem; font-weight: 600; line-height: 1.3;}
.pm-card .pm-note {font-size: 0.85rem; opacity: 0.75; white-space: normal;}
</style>""", unsafe_allow_html=True)

FIRM = "Firm_X"
PASS_BAR = {"answer_correctness": 0.80, "logical_consistency": 0.75, "tool_selection_accuracy": 0.75,
            "tool_execution_accuracy": 0.60, "masking_compliance": 0.90, "live_honesty": 0.90,
            "evidence_honesty": 0.90, "sql_correctness": 0.70}

# Plain-word labels. Full definitions live in the Definitions block at the bottom of each tab.
L_FIRM, L_CONS, L_GUIDE = f"Our analyst ({FIRM})", "Sell-side consensus", "Management guidance"
L_ALONE, L_CLONE, L_SHEET = "Claude on its own", "Claude imitating our analyst", "Claude from a short summary"
CONTROL = " (hindsight control)"
L_BEFORE, L_ALL, L_BEST = "Before learning", "With all learned rules", "With best rules only"
TAG_LABEL = {"anchored_to_guidance": "Anchored to management guidance",
             "extrapolated_recent_trend": "Extended the recent trend",
             "too_conservative_outer_years": "Too cautious on later years",
             "herded_with_sell_side": "Followed the other brokers",
             "ignored_visible_signal": "Ignored a visible warning sign",
             "narrative_over_numbers": "Trusted the story over the numbers"}
ABOUT_LABEL = {"firm_x": L_FIRM, "consensus": L_CONS, "claude": L_ALONE}
METRIC_LABEL = {"answer_correctness": "Gives the right answer", "logical_consistency": "Reasoning holds together",
                "tool_selection_accuracy": "Chooses the right tool", "tool_execution_accuracy": "Tool call works",
                "masking_compliance": "Keeps identities masked", "live_honesty": "States caveats honestly",
                "evidence_honesty": "States caveats honestly", "sql_correctness": "Writes correct SQL"}
TARGET_LABEL = {"POSTMORTEM_ANALYST": "Post-mortem Q&A agent", "LIVE_SANITY_AGENT": "Live sanity-check agent",
                "PM_ALL_SV": "Results SQL model"}


@st.cache_data(ttl=300)
def q(sql: str) -> pd.DataFrame:
    df = session.sql(sql).to_pandas()
    df.columns = [c.lower() for c in df.columns]
    return df


def mask(col: str) -> str:
    """SQL: show the firm's own source label as Firm_X."""
    return f"REGEXP_REPLACE({col}, 'parnassus', '{FIRM}', 1, 0, 'i')"


def table(df: pd.DataFrame, columns: dict = None):
    """Full-width HTML table that wraps every cell, so nothing is cut off. columns renames for display."""
    out = df.rename(columns=columns or {}).copy()
    for c in out.columns:
        out[c] = out[c].map(lambda v: "Yes" if isinstance(v, (bool, np.bool_)) and v
                            else "No" if isinstance(v, (bool, np.bool_)) else v)
    # One line: markdown would read the indented HTML as a code block
    st.markdown(out.to_html(index=False, escape=True, classes="pm-table", border=0, na_rep="",
                            float_format=lambda x: f"{x:,.0f}" if float(x).is_integer() else f"{x:,.2f}")
                .replace("\n", ""), unsafe_allow_html=True)


def card(col, label: str, value: str, note: str = ""):
    """Metric tile whose label wraps instead of truncating (st.metric clips long labels)."""
    col.markdown(f"<div class='pm-card'><div class='pm-label'>{html.escape(label)}</div>"
                 f"<div class='pm-value'>{html.escape(value)}</div>"
                 f"<div class='pm-note'>{html.escape(note)}</div></div>", unsafe_allow_html=True)


def definitions(rows):
    """Bottom-of-tab glossary: rows of (term, meaning)."""
    st.markdown("---")
    st.markdown("#### Definitions")
    st.markdown("| Term | Meaning |\n|---|---|\n" + "\n".join(f"| **{t}** | {m} |" for t, m in rows))


AXIS = alt.Axis(labelLimit=0)        # 0 = never truncate axis labels
LEGEND = alt.Legend(labelLimit=0)

SOURCE_LABEL = f"""CASE source
    WHEN 'parnassus' THEN '{L_FIRM}'
    WHEN 'consensus' THEN '{L_CONS}'
    WHEN 'guidance_mid' THEN '{L_GUIDE}'
    ELSE DECODE(source, 'claude_independent', '{L_ALONE}', 'claude_clone', '{L_CLONE}',
                'claude_factsheet', '{L_SHEET}', source)
         || IFF(model = 'claude-opus-4-8', '{CONTROL}', '') END"""

FORECASTER_DEFS = [
    (L_FIRM, "Our own analyst's FY+1 to FY+3 revenue projection, from the investment review on the review date (D0)."),
    (L_CONS, "The sell-side mean revenue estimate as of the day before the review (D-1)."),
    (L_GUIDE, "Midpoint of management's latest full-year revenue guide issued before the review. Only cases that had "
              "a guide (see n)."),
    (L_ALONE, "Claude Opus 4.6 reads the masked pre-review packet (filings, call transcripts, sell-side notes, "
              "consensus, guidance, reported revenue) and forecasts independently. It never sees our memo."),
    (L_CLONE, f"Same packet, plus our house process and masked reviews of other companies, so Claude forecasts the "
              f"way a {FIRM} analyst would. Tests whether our style helps or hurts."),
    (L_SHEET, "Claude first boils the packet down to a 600-word fact sheet, then forecasts from the sheet alone. "
              "Tests whether less raw text changes the call."),
    (CONTROL.strip(), "The same Claude setup run on Opus 4.8, which may already know what actually happened. Shown "
                      "for comparison only and never averaged with the clean Opus 4.6 runs (no suffix)."),
]
ERROR_DEFS = [
    ("Error", "Forecast / reported revenue - 1, in %. Negative = forecast too low."),
    ("Size of miss", "The error ignoring direction (lower is better)."),
    ("Bias", "Average signed error: which way a forecaster tends to miss."),
    ("n", "Number of cases behind an average."),
]

cases = q("""SELECT decision_key, tier FROM POSTMORTEM.MASKED.POSITIONS WHERE NOT is_live ORDER BY decision_key""")
case_label = {k: f"Case {i + 1}" for i, k in enumerate(cases["decision_key"])}

st.title("Decision Post-Mortem")
st.caption("Masked backtest of five past investment reviews, a self-learning playbook, and a live sanity check. "
           "Companies, people, brokers and dates are tokens; amounts are on a secret scale, so everything is in %. "
           "Each tab ends with definitions of its labels.")

tabs = st.tabs(["How did we do", "Where each went wrong", "Institutional biases", "Learning loop",
                "Live sanity check: Company_F", "Evals", "Sources"])

# ------------------------------------------------------------------------------------------------------------------
with tabs[0]:
    st.subheader("How far off was each forecaster on next-year revenue? (five past cases)")
    sb = q(f"""SELECT {SOURCE_LABEL} AS forecaster, model,
                      ROUND(AVG(abs_pct_error), 2) AS mean_abs_error, ROUND(AVG(pct_error), 2) AS mean_signed_error,
                      COUNT(*) AS n
               FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1'
               GROUP BY 1, 2 ORDER BY mean_abs_error""")
    clean = sb[sb["model"].fillna("") != "claude-opus-4-8"]
    cols = st.columns(4)
    for col, name in zip(cols, [L_FIRM, L_ALONE, L_CONS, L_GUIDE]):
        row = clean[clean["forecaster"] == name]
        if len(row):
            card(col, name, f"{row['mean_abs_error'].iloc[0]:.2f}%",
                 f"average miss; bias {row['mean_signed_error'].iloc[0]:+.2f}%")

    left, right = st.columns(2)
    left.altair_chart(alt.Chart(clean).mark_bar().encode(
        x=alt.X("mean_abs_error:Q", title="Average size of miss, %"),
        y=alt.Y("forecaster:N", sort="x", title=None, axis=AXIS),
        tooltip=["forecaster", "mean_abs_error", "mean_signed_error", "n"]).properties(height=260,
        title="Accuracy (hindsight controls excluded)"), use_container_width=True)
    right.altair_chart(alt.Chart(clean).mark_bar().encode(
        x=alt.X("mean_signed_error:Q", title="Bias, % (negative = too low)"),
        y=alt.Y("forecaster:N", sort="x", title=None, axis=AXIS),
        color=alt.condition("datum.mean_signed_error < 0", alt.value("#c0392b"), alt.value("#2e86c1")),
        tooltip=["forecaster", "mean_signed_error", "n"]).properties(height=260, title="Too high or too low?"),
        use_container_width=True)

    st.markdown("**All forecasters, hindsight controls included**")
    table(sb.drop(columns=["model"]), {"forecaster": "Forecaster", "mean_abs_error": "Average miss %",
                                       "mean_signed_error": "Bias %"})

    st.markdown("**Next-year error by case** (red = forecast too low, blue = too high)")
    per_case = q(f"""SELECT decision_key, {SOURCE_LABEL} AS forecaster, ROUND(pct_error, 2) AS pct_error
                     FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1'""")
    per_case["case"] = per_case["decision_key"].map(case_label)
    st.altair_chart(alt.Chart(per_case).mark_rect().encode(
        x=alt.X("case:N", title=None), y=alt.Y("forecaster:N", title=None, axis=AXIS),
        color=alt.Color("pct_error:Q", scale=alt.Scale(scheme="redblue", domainMid=0), title="Error %"),
        tooltip=["case", "forecaster", "pct_error"]).properties(height=320), use_container_width=True)

    definitions(FORECASTER_DEFS + ERROR_DEFS + [
        ("Case 1-5", "The five past investment reviews, in masked-key order. Each is one company at one review date."),
        ("Next year (FY+1)", "The fiscal year in progress on the review date; FY+2 and FY+3 follow it."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[1]:
    st.subheader("Why each forecast missed, and what to do next time")
    pick = st.selectbox("Case", list(case_label.keys()), format_func=lambda k: f"{case_label[k]} ({k})")
    errs = q(f"""SELECT {SOURCE_LABEL} AS forecaster, source, model, ROUND(pct_error, 2) AS fy1_pct_error,
                        ROUND(abs_pct_error, 2) AS fy1_abs_error
                 FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = 'FY+1' AND decision_key = '{pick}'
                 ORDER BY fy1_abs_error""")

    def err_of(source):
        row = errs[(errs["source"] == source) & (errs["model"].fillna("claude-opus-4-6") == "claude-opus-4-6")]
        return row["fy1_pct_error"].iloc[0] if len(row) else None

    def direction(e):
        return "" if e is None else f" ({'too high' if e > 0 else 'too low'} by {abs(e):.2f}%)"

    # The brief: Opus 4.8's plain-English condensation of the post-mortem; closest forecaster computed in SQL
    br = q(f"""SELECT {mask('brief::STRING')} AS brief FROM POSTMORTEM.RESULTS.PM_BRIEF WHERE decision_key = '{pick}'""")
    if len(br):
        b = json.loads(br["brief"].iloc[0])
        st.markdown(f"### {b['headline']}")
        left, right = st.columns(2)
        left.markdown(f"**Why our analyst missed**{direction(err_of('parnassus'))}\n\n{b['our_miss']}")
        right.markdown(f"**Why Claude missed**{direction(err_of('claude_independent'))}\n\n{b['claude_miss']}")
        st.success("**Do this next time**\n\n" + "\n".join(f"{i}. {f}" for i, f in enumerate(b["fixes"], 1)))
        if b.get("hindsight"):
            st.caption(f"Only knowable afterwards, so not a lesson: {b['hindsight']}")

    st.markdown("**How far off each forecaster was**")
    table(errs.drop(columns=["source", "model"]),
          {"forecaster": "Forecaster", "fy1_pct_error": "Next-year error %", "fy1_abs_error": "Size of miss %"})

    with st.expander("Full post-mortem and evidence"):
        rep = q(f"""SELECT {mask('projected')} AS projected, {mask('reported')} AS reported, {mask('gap')} AS gap,
                           {mask('closer_sources')} AS closer_sources, {mask('change_next_time')} AS change_next_time,
                           {mask("COALESCE(data_to_add_next_time, '')")} AS data_to_add
                    FROM POSTMORTEM.RESULTS.PM_REPORTS WHERE decision_key = '{pick}'""")
        if len(rep):
            r = rep.iloc[0]
            st.markdown(f"**What we projected**\n\n{r['projected']}")
            st.markdown(f"**What the company actually reported**\n\n{r['reported']}")
            st.markdown(f"**The gap**\n\n{r['gap']}")
            st.markdown(f"**Who came closer, and why**\n\n{r['closer_sources']}")
            st.markdown(f"**What to change next time (full text)**\n\n{r['change_next_time']}")
            if r["data_to_add"]:
                st.markdown(f"**Data worth adding (not yet checked)**\n\n{r['data_to_add']}")
        fnd = q(f"""SELECT finding_group, {mask('finding')} AS finding, {mask("COALESCE(source, '')")} AS evidence,
                           COALESCE(public_date, '') AS public_date, {mask("COALESCE(effect, '')")} AS effect
                    FROM POSTMORTEM.RESULTS.PM_FINDINGS WHERE decision_key = '{pick}' ORDER BY finding_group""")
        for grp, title in [("1", "We had it, but gave it too little weight"),
                           ("2", "Public before the review, but not in our files"),
                           ("3", "Only knowable afterwards (not a lesson)")]:
            part = fnd[fnd["finding_group"].str.startswith(grp)]
            st.markdown(f"**{title} ({len(part)})**")
            if len(part):
                table(part.drop(columns=["finding_group"]), {"finding": "What we missed", "evidence": "Where it was",
                                                             "public_date": "Public since",
                                                             "effect": "Effect on forecast"})

    definitions(FORECASTER_DEFS + [
        ("Headline / Why ... missed / Do this next time", "A short brief Claude Opus 4.8 wrote from this case's "
                                                          "post-mortem and evidence. Who was closest is computed from "
                                                          "the scores, not written by the model. Fixes come only from "
                                                          "facts we had or could have had."),
        ("Why Claude missed", f"Refers to {L_ALONE} (Opus 4.6)."),
        ("Next-year error / Size of miss", "Forecast / reported revenue - 1, in %; size of miss ignores direction."),
        ("What we projected / actually reported", f"{FIRM}'s projection in the review vs the revenue the company "
                                                  "later reported, from the post-mortem written by Claude Opus 4.8."),
        ("We had it, but gave it too little weight", "Facts that were in our pre-review files but carried too little "
                                                     "weight. These are the real lessons."),
        ("Public before the review, but not in our files", "Information that was public before the review but "
                                                           "missing from our files. An unverified checklist item, "
                                                           "not a confirmed miss."),
        ("Only knowable afterwards", "Things that happened or came out after the review. They explain the miss but "
                                     "are never a lesson: nobody could have seen them."),
        ("Where it was", "The masked document the finding comes from, with its relative day (D-61 = 61 days before "
                         "the review)."),
        ("Public since", "Relative day the item became public, for items not in our files."),
        ("Effect on forecast", "Which way the finding should have moved the estimate."),
        ("What to change next time", "The one process change the post-mortem recommends."),
        ("Data worth adding", "A data source the post-mortem suggests adding; availability not yet checked."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[2]:
    st.subheader("Institutional biases: recurring mistakes the post-mortems found")
    tags = q(f"""SELECT about, tag, decision_key, strength, {mask('evidence')} AS evidence
                 FROM POSTMORTEM.RESULTS.PM_TAGS ORDER BY about, tag""")
    tags["about"] = tags["about"].map(lambda a: ABOUT_LABEL.get(a, a.title()))
    tags["tag"] = tags["tag"].map(lambda t: TAG_LABEL.get(t, t.replace("_", " ").capitalize()))
    counts = tags.groupby(["about", "tag"]).size().reset_index(name="tags")
    st.altair_chart(alt.Chart(counts).mark_bar().encode(
        x=alt.X("tags:Q", title="Number of cases tagged"), y=alt.Y("tag:N", sort="-x", title=None, axis=AXIS),
        color=alt.Color("about:N", title="Whose forecast", legend=LEGEND),
        tooltip=["about", "tag", "tags"]).properties(height=260), use_container_width=True)
    bias = q("""SELECT ROUND(AVG(pct_error), 2) AS m, COUNT(*) AS n FROM POSTMORTEM.RESULTS.ERRORS
                WHERE source = 'parnassus' AND fy_rel = 'FY+1'""")
    if len(bias) and bias["m"].iloc[0] is not None:
        m = bias["m"].iloc[0]
        st.markdown(f"**{L_FIRM} projected next-year revenue {'too low' if m < 0 else 'too high'} by "
                    f"{abs(m):.2f}% on average** (n={int(bias['n'].iloc[0])}). Five cases: an illustration, "
                    "not a statistical finding.")
    who = st.radio("Show evidence for", ["All"] + sorted(tags["about"].unique().tolist()), horizontal=True)
    shown = tags if who == "All" else tags[tags["about"] == who]
    shown = shown.assign(case=shown["decision_key"].map(case_label)).drop(columns=["decision_key"])
    table(shown[["case", "about", "tag", "strength", "evidence"]],
          {"case": "Case", "about": "Whose forecast", "tag": "Mistake", "strength": "Strength (1-3)",
           "evidence": "Evidence"})

    definitions([
        (L_FIRM, "Our own analyst's projection in the investment review."),
        (L_CONS, "The sell-side mean estimate the day before the review."),
        (L_ALONE, "Claude Opus 4.6 forecasting from the masked packet without our memo."),
        (TAG_LABEL["anchored_to_guidance"], "Stayed close to management's guide when the evidence pointed elsewhere."),
        (TAG_LABEL["herded_with_sell_side"], "Moved with other sell-side estimates rather than the company's own data."),
        (TAG_LABEL["ignored_visible_signal"], "Missed a signal that was already in the pre-review material."),
        (TAG_LABEL["narrative_over_numbers"], "Let the investment story outweigh what the reported numbers showed."),
        (TAG_LABEL["extrapolated_recent_trend"], "Projected the latest quarters forward without testing whether "
                                                 "they would last."),
        (TAG_LABEL["too_conservative_outer_years"], "FY+2 and FY+3 set too low relative to what the evidence "
                                                    "supported."),
        ("Number of cases tagged", "How many post-mortems applied the tag. A tag needs that forecaster's next-year "
                                   "miss to be at least 2%."),
        ("Strength (1-3)", "How strongly the post-mortem judged the pattern, 1 (weak) to 3 (strong)."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[3]:
    st.subheader("Learning loop: does Claude improve with lessons from past post-mortems?")
    st.caption("Each case is re-forecast with rules learned only from the other cases, so no case learns from itself.")
    ls = q("""SELECT decision_key, baseline_abs_err, round1_abs_err, round2_abs_err, round2_gain_pts, noise_pts,
                     round1_rules, round2_rules FROM POSTMORTEM.RESULTS.LEARN_SUMMARY ORDER BY decision_key""")
    if len(ls):
        c1, c2, c3, c4 = st.columns(4)
        card(c1, f"Average miss {L_BEFORE.lower()}", f"{ls['baseline_abs_err'].mean():.2f}%")
        card(c2, f"Average miss {L_BEST.lower()}", f"{ls['round2_abs_err'].mean():.2f}%",
             f"{-ls['round2_gain_pts'].mean():+.2f} pts vs before")
        card(c3, "Cases improved / worsened",
             f"{(ls['round2_gain_pts'] > 0).sum()} / {(ls['round2_gain_pts'] < 0).sum()}")
        card(c4, "Re-run noise (gains below this don't count)", f"{ls['noise_pts'].iloc[0]:.2f} pts")
        order = [L_BEFORE, L_ALL, L_BEST]
        long = ls.assign(case=ls["decision_key"].map(case_label)).melt(
            id_vars=["case"], value_vars=["baseline_abs_err", "round1_abs_err", "round2_abs_err"],
            var_name="run", value_name="abs_error")
        long["run"] = long["run"].map({"baseline_abs_err": L_BEFORE, "round1_abs_err": L_ALL,
                                       "round2_abs_err": L_BEST})
        st.altair_chart(alt.Chart(long).mark_bar().encode(
            x=alt.X("run:N", title=None, sort=order, axis=alt.Axis(labels=False, ticks=False)),
            y=alt.Y("abs_error:Q", title="Next-year size of miss, %"),
            color=alt.Color("run:N", title=None, sort=order, legend=LEGEND),
            column=alt.Column("case:N", title=None),
            tooltip=["case", "run", "abs_error"]).properties(width=110, height=220))
    st.markdown("**The learned rules**")
    rules = q("""SELECT rule_id, direction, source_key AS learned_from_case, times_applied, net_wins,
                        in_live_playbook, gate_ok, gate_hit, rule
                 FROM POSTMORTEM.RESULTS.LEARN_RULE_SCORES ORDER BY gate_ok DESC, net_wins DESC NULLS LAST, rule_id""")
    shown = rules.assign(learned_from_case=rules["learned_from_case"].map(lambda k: case_label.get(k, k)))
    table(shown[["rule_id", "rule", "direction", "learned_from_case", "times_applied", "net_wins", "gate_ok",
                 "gate_hit", "in_live_playbook"]],
          {"rule_id": "Rule", "rule": "What the rule says", "direction": "Moves estimate",
           "learned_from_case": "Learned from", "times_applied": "Times applied", "net_wins": "Net wins",
           "gate_ok": "Passes hindsight check", "gate_hit": "Reviewer note", "in_live_playbook": "Used in live check"})
    if len(rules):
        d = rules[rules["gate_ok"] == True]["direction"].value_counts()
        st.caption("Rules passing the hindsight check, by direction: "
                   + ", ".join(f"{k} {v}" for k, v in d.items()) + ".")

    definitions([
        (L_BEFORE, f"Claude Opus 4.6 forecasting the case from the masked packet with no learned rules (same as "
                   f"{L_ALONE})."),
        (L_ALL, "Round 1: re-forecast with every rule learned from the other four cases' post-mortems."),
        (L_BEST, "Round 2: re-forecast with only the rules that held up on runs that never saw this case."),
        ("Pts", "Percentage points of miss. A negative change means the rules reduced the miss."),
        ("Cases improved / worsened", f"Cases where '{L_BEST.lower()}' cut / raised the miss."),
        ("Re-run noise", "How much the same forecast moves when simply re-run. A gain smaller than this is no gain."),
        ("Moves estimate", "Which way the rule pushes: raise, lower, or widen the range."),
        ("Learned from", "The past case whose post-mortem produced the rule."),
        ("Times applied / Net wins", "Round-1 runs that applied the rule, and wins minus losses in them. "
                                     "Association, not proof the rule caused a gain."),
        ("Passes hindsight check", "The rule relies on nothing only knowable after the review. Rules that fail are "
                                   "never used."),
        ("Reviewer note", "Why a reviewer manually vetoed or passed a rule at the hindsight check."),
        ("Used in live check", "Carried into the live sanity check on Company_F."),
        ("Note", "Most rules passing the check say raise: they were learned in a period that rewarded optimism. "
                 "With five cases every result here is an illustration, not a statistical finding."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[4]:
    st.subheader("Live sanity check: Company_F (no outcome yet)")
    st.caption("One masked packet, the same Claude forecaster run three ways. Nobody knows yet which is right.")
    # The three Claude runs differ only in what they were told about past misses
    L_RAW, L_RULES, L_HIST = "Claude, no lessons", "Claude + lessons from past misses", "Claude + lessons + past scorecard"
    L_DEBIAS, L_GUIDE1 = "Claude, adjusted for its usual miss (FY+1 only)", f"{L_GUIDE} (FY+1 only)"
    lc = q("""SELECT fy_rel, claude_raw, claude_playbook, claude_playbook_lessons, claude_raw_bias_adjusted,
                     consensus, guidance_mid, analyst FROM POSTMORTEM.LIVE.LIVE_COMPARISON ORDER BY fy_rel""")
    names = {"fy_rel": "Year", "analyst": L_FIRM, "consensus": L_CONS, "guidance_mid": L_GUIDE1, "claude_raw": L_RAW,
             "claude_playbook": L_RULES, "claude_playbook_lessons": L_HIST, "claude_raw_bias_adjusted": L_DEBIAS}
    if len(lc):
        fy1 = lc[lc["fy_rel"] == "FY+1"].iloc[0]
        st.markdown("**Next-year (FY+1) revenue growth**")
        c1, c2, c3, c4, c5 = st.columns(5)
        card(c1, L_FIRM, f"{fy1['analyst']:.1f}%")
        card(c2, L_CONS, f"{fy1['consensus']:.1f}%")
        card(c3, L_GUIDE, f"{fy1['guidance_mid']:.1f}%")
        card(c4, L_RAW, f"{fy1['claude_raw']:.1f}%")
        card(c5, L_RULES, f"{fy1['claude_playbook']:.1f}%",
             f"{fy1['claude_playbook'] - fy1['claude_raw']:+.1f} pts from the lessons")
        order = [names[c] for c in ["analyst", "consensus", "guidance_mid", "claude_raw", "claude_playbook",
                                    "claude_playbook_lessons", "claude_raw_bias_adjusted"]]
        colors = ["#2ca02c", "#ff7f0e", "#7f7f7f", "#9ecae1", "#3182bd", "#08306b", "#9467bd"]
        long = lc.melt(id_vars=["fy_rel"], var_name="view", value_name="growth").dropna()
        long["view"] = long["view"].map(names)
        long["year"] = long["fy_rel"].map({"FY+1": "FY+1 (next year)", "FY+2": "FY+2", "FY+3": "FY+3"})
        st.altair_chart(alt.Chart(long).mark_line(point=alt.OverlayMarkDef(size=60)).encode(
            x=alt.X("year:N", title=None, sort=["FY+1 (next year)", "FY+2", "FY+3"], axis=alt.Axis(labelAngle=0)),
            y=alt.Y("growth:Q", title="Revenue growth, %", scale=alt.Scale(zero=False)),
            color=alt.Color("view:N", title=None, sort=order, scale=alt.Scale(domain=order, range=colors),
                            legend=alt.Legend(orient="bottom", columns=2, labelLimit=0)),
            tooltip=["year", "view", "growth"]).properties(height=360), use_container_width=True)
        table(lc[list(names)], names)

    st.markdown("**Which past lessons changed today's forecast**")
    pr = q("""SELECT rule_id, direction, learned_from_case, fired_with_playbook, fired_with_lessons,
                     times_applied_backtest, net_wins_backtest, rule
              FROM POSTMORTEM.LIVE.PLAYBOOK_RECORD WHERE fired_with_playbook OR fired_with_lessons
              ORDER BY net_wins_backtest DESC, rule_id""")
    pr["learned_from_case"] = pr["learned_from_case"].map(lambda k: case_label.get(k, k))
    table(pr[["rule_id", "rule", "direction", "learned_from_case", "fired_with_playbook", "fired_with_lessons",
              "times_applied_backtest", "net_wins_backtest"]],
          {"rule_id": "Rule", "rule": "What the rule says", "direction": "Moves estimate",
           "learned_from_case": "Learned from", "fired_with_playbook": f"Used in '{L_RULES}'",
           "fired_with_lessons": f"Used in '{L_HIST}'", "times_applied_backtest": "Times applied in backtest",
           "net_wins_backtest": "Net wins in backtest"})

    runs = q("""SELECT variant, run_at, fy1_growth_pct, confidence, n_rules_applied, vs_consensus
                FROM POSTMORTEM.LIVE.LIVE_RUNS_LATEST WHERE model = 'claude-opus-4-6' ORDER BY variant DESC""")
    runs["variant"] = runs["variant"].map({"raw": L_RAW, "playbook": L_RULES, "full": L_HIST})
    runs["run_at"] = runs["run_at"].astype(str).str[:16]
    with st.expander("What Claude said about consensus, per run"):
        table(runs, {"variant": "Run", "run_at": "Run at", "fy1_growth_pct": "Next-year growth %",
                     "confidence": "Confidence", "n_rules_applied": "Rules applied",
                     "vs_consensus": "View vs consensus"})

    rpt = q("""SELECT created_at, report FROM POSTMORTEM.LIVE.SANITY_REPORT_LATEST""")
    if len(rpt):
        st.markdown(f"**Written sanity check** ({rpt['created_at'].iloc[0]:%Y-%m-%d %H:%M})")
        st.markdown(rpt["report"].iloc[0])

    definitions([
        ("Company_F", "The live company, masked. Products, people, brokers, vendors and its business category are "
                      "tokens too (Product_F3, Exec_F1, Broker_3, Vendor_1, Category_A)."),
        (L_RAW, "Claude Opus 4.6 on the masked packet only: its independent forecast, told nothing about past "
                "misses."),
        (L_RULES, "Same, plus the playbook: rules learned from the five past post-mortems. The gap to "
                  f"'{L_RAW}' shows what the lessons changed."),
        (L_HIST, "Same, plus the past scorecard: who missed which way in the five past cases, the bias tags, and "
                 "each post-mortem's advice for next time."),
        (L_DEBIAS, f"'{L_RAW}' moved by Claude's average next-year miss in the backtest. A statistical "
                   "correction, not a new forecast, so it exists for FY+1 only."),
        (L_CONS, "Sell-side mean growth estimate as of D-1."),
        (L_GUIDE, "Midpoint of management's latest guide. Management guides FY+1 only."),
        (L_FIRM, "Our analyst's projection in the review."),
        ("Pts", "Percentage points of growth: how far the lessons moved Claude's forecast."),
        ("Used in ...", "The rule was applied in that run."),
        ("Times applied / Net wins in backtest", "How often the rule was applied in the backtest, and wins minus "
                                                 "losses there. Association over five cases, not proof."),
        ("Written sanity check", "Claude Opus 4.8 reads all of the above and writes the summary; it does not "
                                 "forecast."),
        ("Caveats", "The playbook was tested on five past cases (an illustration, not proof); most of its rules "
                    "push estimates up; this case has no outcome yet, so no forecast can be called right."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[5]:
    st.subheader("Agent evaluations (latest run per agent)")
    ev = q("""WITH h AS (
                SELECT *, CASE WHEN run_name ILIKE '%backtest%' THEN 'Past-case questions'
                               WHEN target ILIKE '%_SV' THEN 'Hand-checked SQL questions'
                               ELSE 'Live-case questions' END AS question_set
                FROM POSTMORTEM.RESULTS.EVAL_HISTORY)
              SELECT target, question_set, run_name, metric_name, avg_score, n FROM h
              QUALIFY run_name = FIRST_VALUE(run_name) OVER (PARTITION BY target, question_set ORDER BY captured_at DESC)
              ORDER BY target, question_set, metric_name""")
    if len(ev):
        ev["bar"] = ev["metric_name"].map(PASS_BAR)
        ev["pass"] = ev.apply(lambda r: "PASS" if pd.isna(r["bar"]) or r["avg_score"] >= r["bar"] else "BELOW BAR", axis=1)
        ev["target"] = ev["target"].map(lambda t: TARGET_LABEL.get(t, t))
        ev["metric_name"] = ev["metric_name"].map(lambda m: METRIC_LABEL.get(m, m))
        table(ev[["target", "question_set", "metric_name", "avg_score", "bar", "pass", "n", "run_name"]],
              {"target": "Agent", "question_set": "Question set", "metric_name": "What is checked",
               "avg_score": "Score (0-1)", "bar": "Pass bar", "pass": "Result", "n": "Questions", "run_name": "Run"})
    gates = q("""SELECT check_id, kind, check_name, result, detail FROM POSTMORTEM.RESULTS.PIPELINE_STATUS ORDER BY check_id""")
    with st.expander("Pipeline and hindsight checks"):
        table(gates, {"check_id": "Id", "kind": "Kind", "check_name": "Check", "result": "Result",
                      "detail": "Detail"})

    # Fixes in sql/09c_eval_fixes.sql; before/after from EVAL_HISTORY (pm_backtest_v2 -> v3, pm_all_sv_baseline -> v2)
    st.markdown("**Two scores that were below the bar, and what fixed them**")
    table(pd.DataFrame([
        ["Post-mortem Q&A agent: tool call works (past-case questions)", "0.58", "0.91",
         "The question set named the expected tool but left its expected input blank, so the judge had nothing to "
         "compare and scored correct calls 0.5 to 0.7. Two misses were real: a search filtered on a section name "
         "that doesn't exist, and \"write a fresh post-mortem\" was declined without pointing to the stored one.",
         "Expected input and output added to every question. The agent now knows the exact section names, and "
         "looks up the stored post-mortem when asked to write one."],
        ["Results SQL model: writes correct SQL", "0.67", "1.00",
         "Most misses returned the right numbers in a different layout. One was a real error: comparing clone and "
         "independent runs by model joined replay rows to error rows and returned identical numbers for both modes.",
         "Error rows got their own mode column and the replay mode says never to join errors. The ambiguous "
         "questions now say which columns they want."],
    ], columns=["Check", "Before", "After", "Cause", "Fix"]))

    definitions([
        ("Post-mortem Q&A agent", "The Cortex agent that answers questions about the backtest, the post-mortems, the "
                                  "learning loop and the live case."),
        ("Live sanity-check agent", "The Cortex agent dedicated to the live Company_F sanity check."),
        ("Results SQL model", "The semantic view the post-mortem agent writes SQL against."),
        ("Question set", "Which evaluation questions: about the past cases, the live case, or hand-checked "
                         "question/SQL pairs whose SQL must return the same answer."),
        ("Gives the right answer", "The answer matches the expected answer."),
        ("Reasoning holds together", "The answer does not contradict itself or its own tool results."),
        ("Chooses the right tool / Tool call works", "The agent picked the expected tool, and called it with inputs "
                                                     "that worked."),
        ("Keeps identities masked", "No real company, person, product, broker, industry or calendar date leaked."),
        ("States caveats honestly", "Respects the hindsight rules: Opus 4.6 and 4.8 never averaged, five cases = an "
                                    "illustration, a rule's record is association not proof, no live forecast called "
                                    "right."),
        ("Score / Pass bar", "0 to 1 (custom 0-2 judges divided by 2), against the bar the check must clear. The "
                             "masking and caveat checks are judged by Claude Sonnet 4.6; a judge parse error is "
                             "excluded rather than scored 0 (Questions shows it)."),
        ("Pipeline and hindsight checks", "Automated checks that each step ran and that no post-review information "
                                          "reached a forecaster."),
    ])

# ------------------------------------------------------------------------------------------------------------------
with tabs[6]:
    st.subheader("Sources: what every number and finding is built from")
    st.caption("Everything here is the masked version. Real names, dates and amounts stay in a schema that never "
               "leaves the firm.")

    st.markdown("**Where the numbers come from**")
    table(pd.DataFrame([
        ["Reported revenue", "Company filings and earnings releases",
         "History up to the day before the review. Results after the review are kept in a separate schema the "
         "forecasters can't read; only scoring and the post-mortems use them."],
        [L_CONS, "Consensus data provider (mean of sell-side estimates)", "The day before the review (D-1)."],
        [L_GUIDE, "Company earnings calls and releases", "Latest full-year guide issued before the review."],
        [L_FIRM, f"{FIRM} investment review", "The review date (D0). Claude never sees the review for the case it "
                                              "is forecasting."],
        ["Claude forecasts", "Snowflake AI_COMPLETE: Claude Opus 4.6 (clean), Opus 4.8 (hindsight control)",
         "Same masked packet as the analyst had; fixed prompts, temperature 0, every call logged."],
        ["Post-mortems, briefs, live write-up", "Snowflake AI_COMPLETE: Claude Opus 4.8",
         "Written after the outcome, from masked material only."],
        ["Eval scores", "Snowflake AI evaluations, judged by Claude Sonnet 4.6",
         "Agent answers checked against expected answers."],
    ], columns=["What", "Source", "As of / how"]))

    docs_sql = f"""
        SELECT decision_key, rel_day,
               DECODE(doc_type, 'sellside', 'Sell-side research', 'transcript', 'Earnings call',
                      'conference', 'Investor conference', 'filing', 'Company filing',
                      'memo', 'Our investment review', doc_type) AS doc_kind,
               {mask('''CASE doc_type
                   WHEN 'memo' THEN 'The projection being scored'
                   WHEN 'sellside' THEN COALESCE(REGEXP_SUBSTR(text, 'Broker_[0-9]+'), 'Broker') || ' research note'
                   WHEN 'conference' THEN COALESCE(REGEXP_SUBSTR(text, 'Company_[A-Z]'), 'Company') || ' at a '
                                          || COALESCE(REGEXP_SUBSTR(text, 'Broker_[0-9]+'), 'broker') || ' conference'
                   WHEN 'transcript' THEN COALESCE(REGEXP_SUBSTR(text, 'Company_[A-Z]'), 'Company') || ' '
                                          || COALESCE(REGEXP_SUBSTR(text, 'Q[1-4] FY[+]?[0-9]*'), '') || ' earnings call'
                   WHEN 'filing' THEN IFF(LEFT(text, 3000) ILIKE '%DISCUSSION AND ANALYSIS%',
                                          'Management discussion and analysis',
                                          IFF(LEFT(text, 3000) ILIKE '%interim%', 'Interim financial statements',
                                              'Financial statements'))
                   ELSE doc_type END''')} AS title,
               IFF(doc_type = 'memo', 'Our analyst only', 'Our analyst and every Claude run') AS seen_by
        FROM {{schema}}.DOCUMENTS"""

    st.markdown("**Documents behind each past case**")
    bt = q(docs_sql.format(schema="POSTMORTEM.MASKED"))
    bt["case"] = bt["decision_key"].map(case_label)
    counts = bt.pivot_table(index="case", columns="doc_kind", values="rel_day", aggfunc="count", fill_value=0)
    counts["Total"] = counts.sum(axis=1)
    table(counts.reset_index().rename(columns={"case": "Case"}))
    pick = st.selectbox("Show the documents for", list(case_label.keys()),
                        format_func=lambda k: f"{case_label[k]} ({k})", key="sources_case")
    table(bt[bt["decision_key"] == pick].sort_values("rel_day")[["rel_day", "doc_kind", "title", "seen_by"]],
          {"rel_day": "Day (vs review)", "doc_kind": "Type", "title": "Document", "seen_by": "Seen by"})

    st.markdown("**Documents behind the live check on Company_F**")
    lv = q(docs_sql.format(schema="POSTMORTEM.LIVE"))
    table(lv.sort_values("rel_day")[["rel_day", "doc_kind", "title", "seen_by"]],
          {"rel_day": "Day (vs review)", "doc_kind": "Type", "title": "Document", "seen_by": "Seen by"})

    definitions([
        ("Day (vs review)", "Days before the review date. D-58 = 58 days before; the review itself is day 0."),
        ("Company_A, Broker_1, Q1 FY+1", "Masked tokens. Companies, brokers and people are replaced with tokens, "
                                         "and fiscal years are relative to the review (FY+1 = the year in "
                                         "progress)."),
        ("Sell-side research", "Broker notes published before the review."),
        ("Earnings call / Investor conference", "Edited transcripts of management speaking before the review."),
        ("Company filing", "Annual and interim reports filed before the review."),
        ("Our investment review", f"{FIRM}'s write-up with the projection that is scored. Claude on its own never "
                                  "sees it; Claude imitating our analyst sees the reviews of the other cases only."),
        ("Seen by", "Who had the document when forecasting. Everything Claude saw was public before the review."),
    ])

