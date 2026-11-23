/* @bruin
name: flight.dashboard_feed
type: duckdb.sql
depends:
  - flight.events
  - flight.robot_decisions
  - flight.task_scores
  - flight.robot_failure_modes
  - flight.model_calls
  - flight.court_scoreboard
  - flight.robot_talk
@bruin */
-- The live dashboard's whole feed, written by this pipeline run as one JSON document. The page
-- (telemetry/dashboard.html, served by telemetry/dashboard.py) only reads this file, so a refresh
-- costs the dashboard no query at all. "Now" is the match that started last. In Bruin Cloud the same
-- report is kept as the table flight.robot_report instead, for cloud dashboards and agents.
{% if var.source == "local" %}COPY ({% else %}CREATE OR REPLACE TABLE flight.robot_report AS ({% endif %}
    WITH now_run AS (SELECT max(run) AS run FROM flight.events),
    now_verifier AS (
        SELECT coalesce(max(verifier), 13) AS verifier FROM flight.robot_decisions
        WHERE run = (SELECT run FROM now_run)),
    -- Only matches graded by the same outcome checks as the live one, so "earlier" is comparable.
    dec AS (
        SELECT d.*, d.run = (SELECT run FROM now_run) AS live FROM flight.robot_decisions d
        WHERE d.verifier = (SELECT verifier FROM now_verifier)),
    ev AS (SELECT * FROM flight.events WHERE run = (SELECT run FROM now_run)),
    calls AS (SELECT c.*, c.run = (SELECT run FROM now_run) AS live FROM flight.model_calls c)
    SELECT
        (extract(epoch FROM now()) * 1000)::BIGINT AS updated_ms,
        (SELECT count(DISTINCT run) FROM flight.robot_decisions) AS matches,
        (SELECT count(*) FROM flight.robot_decisions) AS decisions,
        (SELECT verifier FROM now_verifier) AS verifier,
        (SELECT count(DISTINCT run) FROM dec) AS matches_same_verifier,
        (SELECT count(*) FROM dec) AS decisions_same_verifier,
        (SELECT {
                'run': (SELECT run FROM now_run),
                'mode': max(mode),
                'seconds': round(max(tick) / 60.0),
                'gold': count(*) FILTER (WHERE kind = 'goal' AND json_extract_string(payload, '$.team') = '0'),
                'blue': count(*) FILTER (WHERE kind = 'goal' AND json_extract_string(payload, '$.team') = '1'),
                'finished': count(*) FILTER (WHERE kind = 'final') > 0,
                'robbed': count(*) FILTER (
                    WHERE kind = 'custody' AND json_extract_string(payload, '$.method') = 'steal' AND seat < 2
                    AND try_cast(json_extract_string(payload, '$.from') AS INTEGER) >= 2),
                'won_back': count(*) FILTER (
                    WHERE kind = 'custody' AND json_extract_string(payload, '$.method') = 'steal' AND seat >= 2
                    AND try_cast(json_extract_string(payload, '$.from') AS INTEGER) < 2),
                'lessons': count(*) FILTER (WHERE kind = 'lesson'),
                'talks': count(*) FILTER (WHERE kind = 'talk'),
                'jukes': count(*) FILTER (WHERE kind = 'juke'),
                'beacons': count(*) FILTER (WHERE kind = 'aurora')
            } FROM ev) AS "match",
        (SELECT {
                'graded': count(*) FILTER (WHERE live),
                'full_rate': avg(full_pass::INTEGER) FILTER (WHERE live),
                'mean_score': avg(score) FILTER (WHERE live),
                'graded_before': count(*) FILTER (WHERE NOT live),
                'full_rate_before': avg(full_pass::INTEGER) FILTER (WHERE NOT live),
                'mean_score_before': avg(score) FILTER (WHERE NOT live)
            } FROM dec) AS grades,
        (SELECT list(t ORDER BY t.task_order, t.robot) FROM (
                SELECT task, robot,
                       CASE task
                           WHEN 'Win the star back' THEN 1
                           WHEN 'Reach a loose star first' THEN 2
                           WHEN 'Get open for a teammate' THEN 3
                           WHEN 'Keep the star under pressure' THEN 4
                           WHEN 'Carry the star forward' THEN 5
                           WHEN 'Complete a pass' THEN 6
                           ELSE 7
                       END AS task_order,
                       count(*) FILTER (WHERE live) AS attempts,
                       avg(full_pass::INTEGER) FILTER (WHERE live) AS full_rate,
                       avg(score) FILTER (WHERE live) AS mean_score,
                       count(*) FILTER (WHERE NOT live) AS attempts_before,
                       avg(full_pass::INTEGER) FILTER (WHERE NOT live) AS full_rate_before,
                       avg(score) FILTER (WHERE NOT live) AS mean_score_before
                FROM dec GROUP BY task, robot) t) AS tasks,
        (SELECT list(f ORDER BY f.lost_score DESC) FROM (
                SELECT robot, task, situation, move, count(*) AS attempts,
                       avg(score) AS mean_score, avg(full_pass::INTEGER) AS full_rate,
                       avg((NOT verifier_checks[3])::INTEGER) AS miss_approach,
                       avg((NOT verifier_checks[4])::INTEGER) AS miss_execution,
                       avg((NOT verifier_checks[5])::INTEGER) AS miss_outcome,
                       mode(breaks_at) AS breaks_at,
                       count(*) * (1 - avg(score)) AS lost_score
                FROM dec WHERE live GROUP BY robot, task, situation, move HAVING count(*) >= 3
                ORDER BY lost_score DESC LIMIT 8) f) AS failures_now,
        (SELECT list(f ORDER BY f.lost_score DESC) FROM (
                SELECT * FROM flight.robot_failure_modes
                WHERE verifier = (SELECT verifier FROM now_verifier)
                ORDER BY lost_score DESC LIMIT 8) f) AS failures_all,
        (SELECT list(t ORDER BY t.match_number, t.robot) FROM (
                SELECT match_number, run, robot, sum(attempts) AS attempts,
                       sum(full_rate * attempts) / sum(attempts) AS full_rate,
                       sum(mean_score * attempts) / sum(attempts) AS mean_score
                FROM (
                    SELECT * EXCLUDE (match_number), dense_rank() OVER (ORDER BY run) AS match_number
                    FROM flight.task_scores WHERE verifier = (SELECT verifier FROM now_verifier))
                GROUP BY match_number, run, robot HAVING sum(attempts) >= 20
                QUALIFY dense_rank() OVER (ORDER BY match_number DESC) <= 12) t) AS trend,
        (SELECT list(m ORDER BY m.minute, m.robot) FROM (
                SELECT minute, robot, count(*) AS attempts, avg(full_pass::INTEGER) AS full_rate,
                       avg(score) AS mean_score
                FROM dec WHERE live GROUP BY minute, robot) m) AS minutes,
        (SELECT {
                'calls': count(*) FILTER (WHERE live),
                'answered': count(*) FILTER (WHERE live AND status = 'available'),
                'median_ms': median(latency_ms) FILTER (WHERE live),
                'p95_ms': quantile_cont(latency_ms, 0.95) FILTER (WHERE live),
                'tokens': sum(total_tokens) FILTER (WHERE live),
                'calls_all': count(*),
                'median_ms_all': median(latency_ms),
                'tokens_all': sum(total_tokens)
            } FROM calls) AS model_calls,
        (SELECT {
                'advised': count(*) FILTER (WHERE live AND disposition IS NOT NULL),
                'used': count(*) FILTER (WHERE live AND disposition = 'applied'),
                'outweighed': count(*) FILTER (WHERE live AND disposition = 'learner_override'),
                'not_legal': count(*) FILTER (WHERE live AND disposition = 'illegal_here'),
                'score_used': avg(score) FILTER (WHERE live AND disposition = 'applied'),
                'score_own': avg(score) FILTER (WHERE live AND disposition IS DISTINCT FROM 'applied'),
                'used_all': count(*) FILTER (WHERE disposition = 'applied'),
                'advised_all': count(*) FILTER (WHERE disposition IS NOT NULL),
                'score_used_all': avg(score) FILTER (WHERE disposition = 'applied'),
                'score_own_all': avg(score) FILTER (WHERE disposition IS DISTINCT FROM 'applied')
            } FROM dec) AS advice,
        (SELECT list(l ORDER BY l.run DESC, l.tick DESC) FROM (
                SELECT run, tick,
                       CASE seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS robot,
                       json_extract_string(payload, '$.line') AS line
                FROM flight.events WHERE kind = 'lesson' ORDER BY run DESC, tick DESC LIMIT 6) l) AS lessons,
        (SELECT list(t ORDER BY t.run DESC, t.seq DESC) FROM (
                SELECT run, seq, tick, speaker, topic, listeners, line
                FROM flight.robot_talk ORDER BY run DESC, seq DESC LIMIT 8) t) AS talk
{% if var.source == "local" %}) TO 'telemetry/local/dashboard.json' (FORMAT JSON);{% else %});{% endif %}
