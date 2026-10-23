-- POSTMORTEM (database) and its schemas
-- Hand-written. The RAW and PUBLIC schemas are empty on the source and not created here.
-- Safe to re-run (IF NOT EXISTS).

CREATE DATABASE IF NOT EXISTS POSTMORTEM;

-- Masked packets: positions, revenue history, consensus, guidance, documents
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.MASKED;
-- Reported (actual) revenue, relative to the review date
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.OUTCOMES;
-- Replays, post-mortems, learning loop, evals
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.RESULTS;
-- Evaluation data of the retired Explorer agent
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.EXPLORER;
-- The live (no outcome yet) sanity-check case
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.LIVE;
-- The Streamlit in Snowflake app and its source stage
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.APP;
