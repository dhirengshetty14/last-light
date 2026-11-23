/* @bruin
name: flight.robot_talk
type: duckdb.sql
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Only robots talk, and only to other robots
    query: SELECT count(*) FROM flight.robot_talk WHERE speaker IS NULL OR len(listeners) = 0 OR list_contains(listeners, 'a person')
    value: 0
  - name: A robot never talks to itself
    query: SELECT count(*) FROM flight.robot_talk WHERE list_contains(listeners, speaker)
    value: 0
@bruin */
-- Every message one robot sent to other robots (court 14 on): a warning about a player who keeps
-- robbing it, a tip for a situation after it changed a habit, or a crewmate saying it used a tip.
WITH said AS (
    SELECT run, seq, tick, seat,
           json_extract_string(payload, '$.topic') AS topic,
           from_json(json_extract(payload, '$.to'), '["INTEGER"]') AS seats,
           json_extract_string(payload, '$.line') AS line,
           json_extract_string(payload, '$.situation') AS situation
    FROM flight.events WHERE kind = 'talk'
)
SELECT run, seq, tick,
       CASE seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS speaker,
       topic,
       list_transform(seats, x -> CASE x WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' ELSE 'a person' END) AS listeners,
       line, situation
FROM said
