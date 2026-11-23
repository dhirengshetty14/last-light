/* @bruin
name: flight.robot_choices
type: duckdb.sql
description: "Every social choice a robot made in Free Agents (which captain to sign with, what to do about a broken promise, an offer, new terms or a vote), the written rule it could have followed, and its grade from the next promise."
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
    description: "Event number of the choice"
    primary_key: true
    checks:
      - name: positive
  - name: robot
    type: varchar
    description: "Robot name"
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: points
    type: integer
    description: "Grade from the next promise: 100 kept, 0 broken, 50 none"
    checks:
      - name: min
        value: 0
      - name: max
        value: 100
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Only a robot makes a social choice
    query: SELECT count(*) FROM flight.robot_choices WHERE robot IS NULL
    value: 0
  - name: A grade is the robot's own result from 0 to 100
    query: SELECT count(*) FROM flight.robot_choices WHERE points IS NOT NULL AND points NOT BETWEEN 0 AND 100
    value: 0
  - name: No choice is graded twice
    query: SELECT count(*) FROM (SELECT run, cause FROM flight.events WHERE kind='decision_grade' GROUP BY ALL HAVING count(*) > 1)
    value: 0
@bruin */
-- One row per social choice a robot made in Free Agents: what it chose, the written rule it could
-- have followed, how often it had made that call before, and its own result at the whistle.
WITH made AS (
    SELECT run, seq, tick, seat, choice,
           json_extract_string(payload,'$.matter') AS matter,
           try_cast(json_extract_string(payload,'$.about') AS INTEGER) AS about,
           json_extract_string(payload,'$.usual') AS usual,
           try_cast(json_extract_string(payload,'$.tried') AS INTEGER) AS tried,
           coalesce(json_extract_string(payload,'$.explored') = 'true', false) AS explored,
           json_extract_string(payload,'$.context') AS context
    FROM flight.events WHERE kind='decision'
), graded AS (
    SELECT run, cause AS source, points FROM flight.events WHERE kind='decision_grade'
)
SELECT m.run, m.seq, m.tick,
       CASE m.seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS robot,
       m.matter,
       -- For a signing the captain is the one chosen. Otherwise it is the one the choice was about.
       CASE WHEN m.matter='draft' THEN (CASE m.choice WHEN 'nell' THEN 'Nell' ELSE 'Rafi' END)
            WHEN m.about=0 THEN 'Nell' ELSE 'Rafi' END AS captain,
       m.choice, m.usual, m.choice <> m.usual AS overrode_rule, m.tried, m.explored, m.context,
       g.points
FROM made m
LEFT JOIN graded g ON g.run=m.run AND g.source=m.seq
