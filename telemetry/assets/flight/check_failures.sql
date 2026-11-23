/* @bruin
name: flight.check_failures
type: duckdb.sql
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
