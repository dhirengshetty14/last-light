/* @bruin
name: flight.failure_modes
type: duckdb.sql
description: "For each seat, kind of grade and move over all recorded matches: attempts, full passes, near misses and the mean verified fraction."
owner: last-light-team
columns:
  - name: seat
    type: integer
    description: "Seat graded"
    primary_key: true
  - name: category
    type: varchar
    description: "What was graded"
    primary_key: true
    checks:
      - name: not_null
  - name: choice
    type: varchar
    description: "Move or throw"
    primary_key: true
  - name: eligible
    type: bigint
    description: "Graded attempts"
    checks:
      - name: positive
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
