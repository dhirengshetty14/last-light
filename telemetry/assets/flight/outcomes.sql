/* @bruin
name: flight.outcomes
type: duckdb.sql
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Exact pass and bounded score
    query: SELECT COUNT(*) FROM flight.outcomes WHERE points IS NULL OR points NOT BETWEEN 0 AND 100 OR full_pass IS DISTINCT FROM (points = 100) OR (points = 100 AND list_contains(flags, false))
    value: 0
@bruin */
SELECT run, seq, tick, seat, category, choice, cause, flags, points, full_pass
FROM flight.events WHERE kind='action_grade'
