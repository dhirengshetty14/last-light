/* @bruin
name: flight.court_scoreboard
type: duckdb.sql
description: "One row per match: mode, length, goals for each crew, completed passes, steals, interceptions, relays and robot-lit beacons."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id"
    primary_key: true
    checks:
      - name: not_null
  - name: gold_goals
    type: bigint
    description: "Goals by Gold (the people in Rivals)"
    checks:
      - name: non_negative
  - name: blue_goals
    type: bigint
    description: "Goals by Blue (the robots in Rivals)"
    checks:
      - name: non_negative
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Beacon attribution belongs to an agent
    query: SELECT count(*) FROM flight.events WHERE kind='aurora' AND seat NOT BETWEEN 2 AND 4
    value: 0
@bruin */
SELECT run, max(mode) AS mode, max(tick) / 60.0 AS seconds_played,
       count(*) FILTER (WHERE kind='action_grade' AND category='court_throw' AND choice='pass' AND full_pass) AS completed_passes,
       count(*) FILTER (WHERE kind='goal' AND json_extract_string(payload,'$.team')='0') AS gold_goals,
       count(*) FILTER (WHERE kind='goal' AND json_extract_string(payload,'$.team')='1') AS blue_goals,
       count(*) FILTER (WHERE kind='aurora') AS robot_beacons,
       count(*) FILTER (WHERE kind='alliance' AND json_extract_string(payload,'$.changed')='true') AS jersey_changes,
       count(*) FILTER (WHERE kind='dock_relay' AND json_extract_string(payload,'$.charged')='true' AND json_extract_string(payload,'$.team')='0') AS gold_relays,
       count(*) FILTER (WHERE kind='dock_relay' AND json_extract_string(payload,'$.charged')='true' AND json_extract_string(payload,'$.team')='1') AS blue_relays,
       count(*) FILTER (WHERE kind='custody' AND json_extract_string(payload,'$.method')='steal') AS steals,
       count(*) FILTER (WHERE kind='custody' AND json_extract_string(payload,'$.intercepted')='true') AS interceptions,
       -- Version 6 records the player's jersey on release, including recruited machines.
       -- Older recordings still contribute to the existing match-wide totals.
       CASE WHEN count(*) FILTER (WHERE kind='throw' AND json_exists(payload,'$.team')) > 0
            THEN count(*) FILTER (WHERE kind='action_grade' AND category='court_throw' AND choice='pass' AND full_pass AND json_extract_string(payload,'$.team')='0') END AS gold_completed_passes,
       CASE WHEN count(*) FILTER (WHERE kind='throw' AND json_exists(payload,'$.team')) > 0
            THEN count(*) FILTER (WHERE kind='throw' AND choice='shot' AND json_extract_string(payload,'$.team')='0') END AS gold_shots,
       CASE WHEN count(*) FILTER (WHERE kind='throw' AND json_exists(payload,'$.team')) > 0
            THEN count(*) FILTER (WHERE kind='action_grade' AND category='court_throw' AND choice='pass' AND full_pass AND json_extract_string(payload,'$.team')='1') END AS blue_completed_passes,
       CASE WHEN count(*) FILTER (WHERE kind='throw' AND json_exists(payload,'$.team')) > 0
            THEN count(*) FILTER (WHERE kind='throw' AND choice='shot' AND json_extract_string(payload,'$.team')='1') END AS blue_shots
FROM flight.events
GROUP BY run HAVING count(*) FILTER (WHERE kind='court_frame' OR kind='throw') > 0
