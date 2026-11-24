/* @bruin
name: flight.analyst_feed
type: duckdb.sql
description: "Everything the Bruin Analyst hands on, as one document: its advice for the newest match (what the game reads during play), each robot's reaction score in every match of that mode, and its score in every 15 seconds of the newest match. On the game's Mac it is written to telemetry/local/analyst.json; in Bruin Cloud it is kept as the table flight.analyst_report."
owner: last-light-team
depends:
  - flight.analyst_advice
  - flight.learning_curve
  - flight.score_windows
@bruin */
-- One row, written by this pipeline run. telemetry/analyst.py turns it into the advice file the
-- game reads and the Analyst's page without running a query of its own, so the two-second loop
-- stays short.
{% if var.source == "local" %}COPY ({% else %}CREATE OR REPLACE TABLE flight.analyst_report AS ({% endif %}
    WITH latest AS (
        SELECT run, mode FROM flight.learning_curve ORDER BY started_usec DESC LIMIT 1)
    SELECT
        (SELECT run FROM latest) AS run,
        (SELECT mode FROM latest) AS mode,
        (SELECT list(a ORDER BY a.seat, a.phase, a.scene) FROM (
                SELECT seat, robot, phase, scene, prefer, prefer_score, avoid, avoid_score, evidence,
                       teacher, reason, through_tick
                FROM flight.analyst_advice WHERE run = (SELECT run FROM latest)) a) AS advice,
        (SELECT list(c ORDER BY c.match_number, c.seat) FROM (
                SELECT run, seat, robot, match_number, origin, reactions, reaction, reaction_when_advised,
                       reaction_unadvised, reaction_change, ball, human, teammate, wall, decision_grade,
                       human_goals, robot_goals
                FROM flight.learning_curve
                WHERE mode IS NOT DISTINCT FROM (SELECT mode FROM latest)) c) AS curve,
        (SELECT list(w ORDER BY w.seat, w.start_second) FROM (
                SELECT seat, start_second, reactions, reaction, speed, direction, outcome,
                       advised_reactions, decision_grade
                FROM flight.score_windows WHERE run = (SELECT run FROM latest)) w) AS windows
{% if var.source == "local" %}) TO 'telemetry/local/analyst.json' (FORMAT JSON);{% else %});{% endif %}
