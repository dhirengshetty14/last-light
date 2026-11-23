/* @bruin
name: flight.agent_decisions
type: duckdb.sql
depends:
  - flight.events
  - flight.outcomes
  - flight.model_calls
materialization:
  type: table
custom_checks:
  - name: Applied model moves match the proposal and its originating robot
    query: SELECT count(*) FROM flight.agent_decisions WHERE disposition='applied' AND (tactic IS DISTINCT FROM proposal OR request_tick IS NULL)
    value: 0
@bruin */
WITH transport AS (
    SELECT run,seat,seq,payload->>'result' AS radio_state FROM flight.events WHERE kind='model_transport'
)
SELECT i.run,i.origin,i.seat,CASE i.seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS robot,
       i.tick,i.cause AS decision_id,i.payload->>'context' AS context,i.payload->>'goal' AS goal,
       i.payload->'legal_choices' AS legal_choices,i.payload->>'reason' AS public_reason,i.choice AS tactic,
       CASE WHEN i.payload->'gemini'->>'disposition'='applied' THEN 'gemini' ELSE 'local' END AS decision_source,
       i.payload->'gemini'->>'proposal' AS proposal,i.payload->'gemini'->>'rationale' AS model_reason,
       i.payload->'gemini'->>'disposition' AS disposition,m.request_id,m.request_tick,m.requested_model,m.served_version,
       m.latency_ms,coalesce(t.radio_state,'no_request_yet') AS last_transport_state,o.tick AS resolved_tick,o.flags AS verifier_checks,o.points/100.0 AS score,o.full_pass
FROM flight.events i
ASOF LEFT JOIN transport t ON t.run=i.run AND t.seat=i.seat AND i.seq>=t.seq
LEFT JOIN flight.model_calls m ON m.run=i.run AND m.seat=i.seat AND m.request_id=try_cast(i.payload->'gemini'->>'request_id' AS BIGINT)
LEFT JOIN flight.outcomes o ON o.run=i.run AND o.seat=i.seat AND o.cause=i.cause AND o.category='response'
WHERE i.kind='response_intent' AND (i.payload->>'context') LIKE 'star2/%'
