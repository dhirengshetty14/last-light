/* @bruin
name: flight.outcomes
type: duckdb.sql
description: "Every verifier grade: one row per graded robot decision (response), throw (court_throw) or catch, with its five check results and points out of 100."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id"
    primary_key: true
    checks:
      - name: not_null
  - name: seq
    type: bigint
    description: "Event number of the grade"
    primary_key: true
    checks:
      - name: positive
  - name: category
    type: varchar
    description: "What was graded: response (a robot decision), court_throw or catch"
    checks:
      - name: accepted_values
        value: ["response", "court_throw", "catch"]
  - name: points
    type: integer
    description: "Verifier score out of 100: the weights of the checks that passed"
    checks:
      - name: min
        value: 0
      - name: max
        value: 100
  - name: full_pass
    type: boolean
    description: "True only when all five checks passed"
    checks:
      - name: not_null
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
