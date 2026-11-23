/* @bruin
name: flight.model_calls
type: duckdb.sql
description: "Every Gemini playbook request: which robot asked, what it saw, the reply status, how long it took, the tokens used and the playbook returned."
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
    description: "Robot seat that asked"
    primary_key: true
    checks:
      - name: min
        value: 2
      - name: max
        value: 4
  - name: request_id
    type: bigint
    description: "That robot's request number in the match"
    primary_key: true
    checks:
      - name: not_null
  - name: status
    type: varchar
    description: "available, stale, cancelled, timeout, an error, or pending"
    checks:
      - name: not_null
  - name: latency_ms
    type: bigint
    description: "Time from request to reply in milliseconds"
    checks:
      - name: non_negative
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: One request per robot and call
    query: SELECT count(*) FROM (SELECT run, seat, request_id FROM flight.model_calls GROUP BY ALL HAVING count(*) > 1)
    value: 0
@bruin */
WITH packets AS (
    SELECT run,origin,seat,seq,tick,payload->'packet' AS p,payload->>'result' AS result
    FROM flight.events WHERE kind='model_transport'
), calls AS (
    SELECT *, (p->>'id')::BIGINT AS request_id FROM packets
)
SELECT q.run,q.origin,q.seat,q.request_id,q.p->>'model' AS requested_model,
       q.tick AS request_tick,q.p->'observation' AS observation,
       r.tick AS result_tick,coalesce(r.result,'pending') AS status,
       r.p->>'model_version' AS served_version,(r.p->>'latency_ms')::BIGINT AS latency_ms,
       (r.p->>'http_status')::INTEGER AS http_status,(r.p->>'input_tokens')::INTEGER AS input_tokens,
       (r.p->>'output_tokens')::INTEGER AS output_tokens,(r.p->>'total_tokens')::INTEGER AS total_tokens,r.p->'plan' AS returned_playbook
FROM calls q LEFT JOIN calls r ON r.run=q.run AND r.seat=q.seat AND r.request_id=q.request_id AND r.seq>q.seq AND r.result<>'requested'
WHERE q.result='requested'
