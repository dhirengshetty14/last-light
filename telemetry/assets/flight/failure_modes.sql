/* @bruin
name: flight.failure_modes
type: duckdb.sql
depends:
  - flight.outcomes
materialization:
  type: table
@bruin */
SELECT seat, category, choice, COUNT(*) AS eligible,
       SUM(CASE WHEN full_pass THEN 1 ELSE 0 END) AS full_passes,
       SUM(CASE WHEN NOT full_pass AND points >= 75 THEN 1 ELSE 0 END) AS near_misses,
       ROUND(AVG(points) / 100, 3) AS mean_verified_fraction,
       MIN(CASE WHEN NOT full_pass THEN tick END) AS first_failed_tick
FROM flight.outcomes GROUP BY ALL
