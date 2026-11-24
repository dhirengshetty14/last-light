/* @bruin
name: flight.agent_decisions
type: duckdb.sql
description: "Every robot decision with its situation, legal moves, public reason, the Gemini proposal it weighed and what became of it, the model call behind it, and the verifier's grade."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id"
    primary_key: true
    checks:
      - name: not_null
  - name: seat
    type: integer
    description: "Robot seat: 2 Pip, 3 Morrow, 4 Zip"
    primary_key: true
    checks:
      - name: min
        value: 2
      - name: max
        value: 4
  - name: decision_id
    type: bigint
    description: "Event number of the decision"
    primary_key: true
    checks:
      - name: not_null
  - name: robot
    type: varchar
    description: "Robot name"
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: decision_source
    type: varchar
    description: "gemini when the robot used Gemini's proposal, otherwise local"
    checks:
      - name: accepted_values
        value: ["gemini", "local"]
  - name: score
    type: double
    description: "Verifier score from 0 to 1"
    checks:
      - name: min
        value: 0
      - name: max
        value: 1
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
  - name: The Bruin Analyst only lifts or lowers legal moves, by its fixed small amount
    query: |
      SELECT count(*) FROM flight.agent_decisions, unnest(json_keys(analyst_lift)) AS k(move)
      WHERE analyst_lift IS NOT NULL
        AND (NOT list_contains(from_json(legal_choices, '["VARCHAR"]'), move)
             OR abs(abs(CAST(json_extract(analyst_lift, '$.' || move) AS DOUBLE)) - 0.04) > 1e-6)
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
       m.latency_ms,coalesce(t.radio_state,'no_request_yet') AS last_transport_state,
       i.payload->'analyst'->'lift' AS analyst_lift,o.tick AS resolved_tick,o.flags AS verifier_checks,o.points/100.0 AS score,o.full_pass
FROM flight.events i
ASOF LEFT JOIN transport t ON t.run=i.run AND t.seat=i.seat AND i.seq>=t.seq
LEFT JOIN flight.model_calls m ON m.run=i.run AND m.seat=i.seat AND m.request_id=try_cast(i.payload->'gemini'->>'request_id' AS BIGINT)
LEFT JOIN flight.outcomes o ON o.run=i.run AND o.seat=i.seat AND o.cause=i.cause AND o.category='response'
WHERE i.kind='response_intent' AND (i.payload->>'context') LIKE 'star2/%'
