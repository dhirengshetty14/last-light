/* @bruin
name: flight.learning_examples
type: duckdb.sql
description: "One resolved learning example per robot decision: the situation, the move and its grade. This is what each robot's learner consumes, and what watch.py exports as verified examples that the game loads at its next launch."
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
    description: "Robot seat"
    primary_key: true
    checks:
      - name: min
        value: 2
      - name: max
        value: 4
  - name: cause
    type: bigint
    description: "Event number of the decision this example grades"
    primary_key: true
    checks:
      - name: not_null
  - name: points
    type: integer
    description: "Verifier score out of 100"
    checks:
      - name: min
        value: 0
      - name: max
        value: 100
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
