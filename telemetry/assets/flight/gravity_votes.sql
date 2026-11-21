/* @bruin
name: flight.gravity_votes
type: duckdb.sql
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Every gravity change has three distinct preceding physical votes
    query: SELECT COUNT(*) FROM flight.gravity_votes WHERE distinct_voters<3 OR valid_causes<>expected_causes OR (hands_off AND human_votes<>0)
    value: 0
@bruin */
WITH flips AS (
    SELECT run,seq,tick,CAST(json_extract(payload,'$.axis') AS INTEGER) AS axis,
           CAST(json_extract(payload,'$.hands_off') AS BOOLEAN) AS hands_off,
           CAST(json_extract(payload,'$.released_reel') AS BOOLEAN) AS released_reel,
           unnest(CAST(json_extract(payload,'$.causes') AS BIGINT[])) AS latch
    FROM flight.events WHERE kind='gravity'
)
SELECT f.run,f.seq,f.tick,f.axis,f.hands_off,f.released_reel,count(*) AS expected_causes,
       count(v.seq) AS valid_causes,count(DISTINCT v.seat) AS distinct_voters,
       count(*) FILTER (WHERE v.seat IN (0,1)) AS human_votes
FROM flips f LEFT JOIN flight.events v ON v.run=f.run AND v.seq=f.latch AND v.seq<f.seq
  AND v.kind='latch' AND cast(json_extract(v.payload,'$.zone') AS INTEGER)=f.axis
GROUP BY ALL
