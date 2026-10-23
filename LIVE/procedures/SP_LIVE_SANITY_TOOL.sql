-- POSTMORTEM.LIVE.SP_LIVE_SANITY_TOOL (stored procedure)
-- Wrapper the agents call: resolves the live case key (falls back to the live case if the key is unknown),
-- runs SP_LIVE_SANITY and returns the report.
--
-- Uses: POSITIONS, SP_LIVE_SANITY, SANITY_REPORTS

CREATE OR REPLACE PROCEDURE POSTMORTEM.LIVE.SP_LIVE_SANITY_TOOL("DK" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  k STRING;
BEGIN
  k := COALESCE((SELECT MAX(decision_key) FROM POSTMORTEM.LIVE.POSITIONS WHERE decision_key = :dk AND is_live),
                (SELECT MIN(decision_key) FROM POSTMORTEM.LIVE.POSITIONS WHERE is_live));
  IF (k IS NULL) THEN
    RETURN ''No live case loaded in POSTMORTEM.LIVE.'';
  END IF;
  CALL POSTMORTEM.LIVE.SP_LIVE_SANITY(:k);
  RETURN (SELECT report FROM POSTMORTEM.LIVE.SANITY_REPORTS WHERE decision_key = :k ORDER BY created_at DESC LIMIT 1);
END;
';
