/* @bruin
name: flight.court_scoreboard
type: duckdb.sql
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
       count(*) FILTER (WHERE kind='custody' AND json_extract_string(payload,'$.method')='steal') AS steals
FROM flight.events
GROUP BY run HAVING count(*) FILTER (WHERE kind='court_frame' OR kind='throw') > 0
