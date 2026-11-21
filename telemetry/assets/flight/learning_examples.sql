/* @bruin
name: flight.learning_examples
type: duckdb.sql
depends:
  - flight.events
  - flight.outcomes
materialization:
  type: table
custom_checks:
  - name: One resolved reaction per actor and source
    query: SELECT COUNT(*) FROM (SELECT run,seat,cause FROM flight.learning_examples GROUP BY ALL HAVING COUNT(*) > 1)
    value: 0
@bruin */
SELECT g.run, g.seat, g.cause, i.origin, i.choice,
       json_extract_string(i.payload, '$.context') AS context,
       g.points, g.full_pass, g.tick - i.tick AS elapsed_ticks
FROM flight.outcomes g
JOIN flight.events i ON i.run=g.run AND i.seat=g.seat AND i.cause=g.cause
    AND i.kind='response_intent' AND i.seq<g.seq AND i.choice=g.choice
WHERE g.category='response'
