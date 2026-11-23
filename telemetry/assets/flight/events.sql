/* @bruin
name: flight.events
type: duckdb.sql
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
