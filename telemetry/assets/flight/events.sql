/* @bruin
name: flight.events
type: duckdb.sql
description: "Every event of every recorded match, one row each: player inputs, possession changes, throws, goals, robot decisions and their verifier grades, robot talk and Gemini traffic. On the game's Mac it is read from the staged match logs; in Bruin Cloud from raw.match_events in MotherDuck."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id: start time in microseconds and the seed"
    primary_key: true
    checks:
      - name: not_null
  - name: seq
    type: bigint
    description: "Event number within the match, from 1 with no gaps"
    primary_key: true
    checks:
      - name: positive
  - name: kind
    type: varchar
    description: "Event type, for example custody, throw, goal, response_intent, action_grade or talk"
    checks:
      - name: not_null
  - name: seat
    type: integer
    description: "Who: 0 Nell, 1 Rafi, 2 Pip, 3 Morrow, 4 Zip, -1 the court itself"
    checks:
      - name: min
        value: -1
      - name: max
        value: 4
  - name: court
    type: integer
    description: "Court version the match was played on; it decides how old matches replay"
materialization:
  type: table
custom_checks:
  - name: Unique event per run and sequence
    query: SELECT COUNT(*) FROM (SELECT run, seq FROM flight.events GROUP BY run, seq HAVING COUNT(*) > 1)
    value: 0
  - name: Complete sequence for each observed prefix
    query: SELECT COUNT(*) FROM (SELECT run FROM flight.events GROUP BY run HAVING MIN(seq) <> 1 OR MAX(seq) <> COUNT(*))
    value: 0
@bruin */
{% if var.source == "local" %}
-- On the game's Mac: the match logs watch.py staged a moment ago.
SELECT * FROM read_json('telemetry/local/events.ndjson', columns={
    run: 'VARCHAR', mode: 'VARCHAR', origin: 'VARCHAR', court: 'INTEGER', seq: 'BIGINT', tick: 'BIGINT', kind: 'VARCHAR', seat: 'INTEGER',
    points: 'INTEGER', full_pass: 'BOOLEAN', category: 'VARCHAR', choice: 'VARCHAR',
    cause: 'BIGINT', flags: 'BOOLEAN[]', payload: 'VARCHAR'
}, format='newline_delimited')
{% else %}
-- In Bruin Cloud: the same rows, uploaded to MotherDuck by telemetry/cloud.py.
SELECT * FROM raw.match_events
{% endif %}
