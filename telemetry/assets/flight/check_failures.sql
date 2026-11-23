/* @bruin
name: flight.check_failures
type: duckdb.sql
description: "How often each of the five verifier checks is missed, by kind of grade, seat and move. It shows which check a move breaks at."
owner: last-light-team
columns:
  - name: category
    type: varchar
    description: "What was graded: response, court_throw or catch"
    primary_key: true
    checks:
      - name: not_null
  - name: seat
    type: integer
    description: "Seat graded"
    primary_key: true
  - name: choice
    type: varchar
    description: "Move or throw"
    primary_key: true
  - name: checkpoint
    type: bigint
    description: "Which of the five checks, from 1"
    primary_key: true
    checks:
      - name: min
        value: 1
      - name: max
        value: 6
  - name: criterion
    type: varchar
    description: "The check in words"
    primary_key: true
  - name: misses
    type: bigint
    description: "Times that check failed"
    checks:
      - name: non_negative
depends:
  - flight.outcomes
materialization:
  type: table
@bruin */
WITH bits AS (
    SELECT run, seat, category, choice, tick, unnest(flags) AS met,
           generate_subscripts(flags, 1) AS n FROM flight.outcomes
)
SELECT category, seat, choice, n AS checkpoint,
       CASE WHEN category='catch' THEN
          ['cover armed','reached intercept','assigned receiver made contact','relative speed inside envelope','six ticks of custody','eighteen ticks of custody'][n]
       WHEN category='court_throw' THEN
          ['controlled release','target in range','sustained flight','team contact or hoop','intended completion'][n]
       ELSE ['witnessed event','legal response','in correct lane','physical action','world consequence'][n] END AS criterion,
       count(*) AS attempts, count(*) FILTER (WHERE NOT met) AS misses,
       min(tick) FILTER (WHERE NOT met) AS first_failed_tick
FROM bits GROUP BY ALL
