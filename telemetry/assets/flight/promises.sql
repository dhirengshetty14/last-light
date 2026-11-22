/* @bruin
name: flight.promises
type: duckdb.sql
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: No promise settles twice
    query: SELECT count(*) FROM (SELECT run, json_extract_string(payload,'$.deal') FROM flight.events WHERE kind='deal_end' GROUP BY ALL HAVING count(*) > 1)
    value: 0
  - name: Only a robot calls or forms a union
    query: SELECT count(*) FROM flight.events WHERE kind IN ('union_call','union') AND seat NOT BETWEEN 2 AND 4
    value: 0
@bruin */
-- One row per promise a captain made to a robot in Free Agents, with how the court settled it.
WITH opened AS (
    SELECT run, seat, tick, try_cast(json_extract_string(payload,'$.deal') AS INTEGER) AS deal,
           try_cast(json_extract_string(payload,'$.human') AS INTEGER) AS human,
           json_extract_string(payload,'$.terms') AS terms, choice AS currency
    FROM flight.events WHERE kind='deal'
), settled AS (
    SELECT run, tick, try_cast(json_extract_string(payload,'$.deal') AS INTEGER) AS deal,
           json_extract_string(payload,'$.state') AS outcome,
           json_extract_string(payload,'$.reason') AS reason
    FROM flight.events WHERE kind='deal_end'
), walkout AS (
    SELECT run, min(tick) AS union_tick FROM flight.events WHERE kind='union' GROUP BY run
)
SELECT o.run, o.deal,
       CASE o.human WHEN 0 THEN 'Nell' ELSE 'Rafi' END AS captain,
       CASE o.seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS robot,
       o.currency, o.terms, o.tick AS opened_tick, s.tick AS settled_tick,
       coalesce(s.outcome, 'open') AS outcome, s.reason,
       w.union_tick IS NOT NULL AS match_ended_in_union
FROM opened o
LEFT JOIN settled s ON s.run=o.run AND s.deal=o.deal
LEFT JOIN walkout w ON w.run=o.run
