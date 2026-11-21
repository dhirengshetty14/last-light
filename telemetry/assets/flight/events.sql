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
SELECT * FROM read_json('telemetry/local/events.ndjson', columns={
    run: 'VARCHAR', mode: 'VARCHAR', origin: 'VARCHAR', seq: 'BIGINT', tick: 'BIGINT', kind: 'VARCHAR', seat: 'INTEGER',
    points: 'INTEGER', full_pass: 'BOOLEAN', category: 'VARCHAR', choice: 'VARCHAR',
    cause: 'BIGINT', flags: 'BOOLEAN[]', payload: 'VARCHAR'
}, format='newline_delimited')
