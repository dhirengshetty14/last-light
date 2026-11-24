/* @bruin
name: flight.reactions
type: duckdb.sql
description: "Every moment something happened to a robot, scored 0 to 1 for how it reacted: a rival passing, catching or stealing the star (ball), a person dashing at it while it carries (human), a crewmate getting the star (teammate), or carrying the star to within 1 m of a side wall (wall). Speed of reaction 0.3, right direction 0.3, outcome 0.4. Each row also has the move the robot reacted with and the situation it decided in. Goals are not used."
owner: last-light-team
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Every reaction score is between 0 and 1
    query: SELECT count(*) FROM flight.reactions WHERE reaction NOT BETWEEN 0 AND 1 OR speed NOT BETWEEN 0 AND 1 OR direction NOT BETWEEN 0 AND 1 OR outcome NOT BETWEEN 0 AND 1
    value: 0
  - name: One reaction per robot per stimulus
    query: SELECT count(*) FROM (SELECT run, category, stimulus_id, seat FROM flight.reactions GROUP BY ALL HAVING count(*) > 1)
    value: 0
@bruin */
-- How each robot reacts to its world, scored 0 to 1. No goals are involved.
-- A stimulus is something that happens to a robot. Four kinds are scored:
--   ball      a rival passes the star, or catches or steals it    (robot within 5 m)   phase loose/defend
--   human     a human dashes while the robot carries the star     (human within 3.5 m) phase carry
--   teammate  another robot of its crew gets the star                                  phase support
--   wall      the robot, carrying the star, comes within 1 m of a side wall            phase carry
-- Every reaction has the same three parts:
--   speed     0.3  how soon it reacted (position frames come 4 times a second)
--   direction 0.3  whether it moved the right way: closed on the ball, kept its gap from the
--                  human (or sidestepped), found open space, came off the wall
--   outcome   0.4  ball: it won the star 1, a teammate did 0.5. human and wall: not robbed 1.
--                  teammate: received a pass 1, the crew still has the star after 3 s 0.5.
-- Each reaction carries the situation the robot decided in (`scene`, written by the court at the
-- decision: star near or far, coming or going or slow, ahead or behind, a human pressing or not,
-- a wall near), so the Analyst can learn what works in each kind of moment.
WITH frames AS (
    SELECT run, tick, payload,
           CAST(json_extract(payload, '$.owner') AS INTEGER) AS owner,
           CAST(json_extract(payload, '$.star[0]') AS DOUBLE) AS sx,
           CAST(json_extract(payload, '$.star[2]') AS DOUBLE) AS sz
    FROM flight.events WHERE kind = 'court_frame'
), players AS (
    SELECT f.run, f.tick, f.owner, f.sx, f.sz, s.seat,
           CAST(json_extract(f.payload, '$.players[' || s.seat || '][0]') AS DOUBLE) AS x,
           CAST(json_extract(f.payload, '$.players[' || s.seat || '][1]') AS DOUBLE) AS y,
           CAST(json_extract(f.payload, '$.players[' || s.seat || '][2]') AS INTEGER) AS team
    FROM frames f CROSS JOIN (VALUES (0), (1), (2), (3), (4)) s(seat)
), near_human AS (
    SELECT r.run, r.tick, r.seat, min(sqrt(pow(r.x - h.x, 2) + pow(r.y - h.y, 2))) AS human_dist
    FROM players r JOIN players h ON h.run = r.run AND h.tick = r.tick AND h.seat < 2 AND h.team <> r.team
    WHERE r.seat >= 2 GROUP BY ALL
), robot AS (
    SELECT p.run, p.tick, p.seat, p.team, p.owner,
           sqrt(pow(p.x - p.sx, 2) + pow(p.y - p.sz, 2)) AS ball_dist,
           4.65 - abs(p.y) AS wall_gap,
           coalesce(n.human_dist, 99) AS human_dist,
           sqrt(pow(p.x - lag(p.x) OVER w, 2) + pow(p.y - lag(p.y) OVER w, 2)) AS step,
           sqrt(pow(p.x - p.sx, 2) + pow(p.y - p.sz, 2))
               < lag(sqrt(pow(p.x - p.sx, 2) + pow(p.y - p.sz, 2))) OVER w - 0.1 AS closer_ball,
           4.65 - abs(p.y) > lag(4.65 - abs(p.y)) OVER w + 0.1 AS off_wall,
           lag(4.65 - abs(p.y)) OVER w AS wall_gap_before,
           lag(p.owner) OVER w AS owner_before
    FROM players p LEFT JOIN near_human n ON n.run = p.run AND n.tick = p.tick AND n.seat = p.seat
    WHERE p.seat >= 2
    WINDOW w AS (PARTITION BY p.run, p.seat ORDER BY p.tick)
), custody AS (
    SELECT run, tick, seat, try_cast(json_extract_string(payload, '$.team') AS INTEGER) AS team,
           try_cast(json_extract_string(payload, '$.from') AS INTEGER) AS from_seat,
           json_extract_string(payload, '$.method') AS method
    FROM flight.events WHERE kind = 'custody'
), event_stimuli AS (
    -- Stimuli that are events: the ball, a human's dash, a teammate getting the star.
    SELECT e.run, e.seq AS stimulus_id, e.tick, e.kind, e.seat AS actor,
           try_cast(json_extract_string(e.payload, '$.team') AS INTEGER) AS actor_team,
           json_extract_string(e.payload, '$.action') AS action,
           json_extract_string(e.payload, '$.method') AS method
    FROM flight.events e
    WHERE (e.kind = 'throw' AND json_extract_string(e.payload, '$.action') = 'pass')
       OR (e.kind = 'custody' AND json_extract_string(e.payload, '$.method') IN ('catch', 'steal'))
       OR (e.kind = 'dash' AND e.seat < 2)
), at_event AS (
    SELECT s.*, r.seat, r.team, r.owner, r.tick AS f0, r.ball_dist, r.human_dist, r.wall_gap
    FROM event_stimuli s CROSS JOIN (VALUES (2), (3), (4)) k(seat)
    ASOF JOIN robot r ON r.run = s.run AND r.seat = k.seat AND r.tick >= s.tick
), stimuli AS (
    SELECT run, stimulus_id, tick, seat, team, f0, ball_dist, human_dist, wall_gap,
           'ball' AS category,
           CASE kind WHEN 'throw' THEN 'loose' ELSE 'defend' END AS phase,
           CASE kind WHEN 'throw' THEN 'rival pass' ELSE 'rival ' || method END AS stimulus
    FROM at_event
    WHERE kind IN ('throw', 'custody') AND actor_team <> team AND ball_dist <= 5.0
    UNION ALL
    SELECT run, stimulus_id, tick, seat, team, f0, ball_dist, human_dist, wall_gap,
           'human', 'carry', 'human dash'
    FROM at_event
    WHERE kind = 'dash' AND owner = seat AND human_dist <= 3.5
    UNION ALL
    SELECT run, stimulus_id, tick, seat, team, f0, ball_dist, human_dist, wall_gap,
           'teammate', 'support', 'teammate ' || method
    FROM at_event
    WHERE kind = 'custody' AND actor_team = team AND actor >= 2 AND actor <> seat
    UNION ALL
    -- The robot, carrying the star, comes within 1 m of a side wall (the court's "wall" scene).
    SELECT run, -tick AS stimulus_id, tick, seat, team, tick AS f0, ball_dist, human_dist, wall_gap,
           'wall', 'carry', 'side wall'
    FROM robot
    WHERE owner = seat AND wall_gap < 1.0 AND (wall_gap_before >= 1.0 OR owner_before IS DISTINCT FROM seat)
), measured AS (
    SELECT s.*,
           (SELECT min(r.tick) FROM robot r WHERE r.run = s.run AND r.seat = s.seat AND r.tick > s.f0 AND r.tick <= s.f0 + 60
               AND CASE s.category WHEN 'ball' THEN r.closer_ball WHEN 'wall' THEN r.off_wall ELSE r.step > 0.25 END) AS first_move,
           (SELECT any_value(r.ball_dist) FROM robot r WHERE r.run = s.run AND r.seat = s.seat AND r.tick = s.f0 + 60) AS ball_dist_1s,
           (SELECT any_value(r.human_dist) FROM robot r WHERE r.run = s.run AND r.seat = s.seat AND r.tick = s.f0 + 60) AS human_dist_1s,
           (SELECT any_value(r.wall_gap) FROM robot r WHERE r.run = s.run AND r.seat = s.seat AND r.tick = s.f0 + 60) AS wall_gap_1s,
           (SELECT count(*) FROM flight.events j WHERE j.run = s.run AND j.kind = 'juke' AND j.seat = s.seat
               AND j.tick > s.tick AND j.tick <= s.tick + 60) AS juked,
           (SELECT count(*) FROM custody c WHERE c.run = s.run AND c.method = 'steal' AND c.from_seat = s.seat
               AND c.tick > s.tick AND c.tick <= s.tick + 60) AS robbed,
           (SELECT arg_min(CASE WHEN c.seat = s.seat THEN 1.0 ELSE 0.5 END, c.tick) FROM custody c
             WHERE c.run = s.run AND c.tick > s.tick AND c.tick <= s.tick + 120 AND c.team = s.team) AS won_ball,
           (SELECT count(*) FROM custody c WHERE c.run = s.run AND c.seat = s.seat AND c.method = 'catch'
               AND c.tick > s.tick AND c.tick <= s.tick + 180) AS received,
           (SELECT any_value(r.owner) FROM robot r WHERE r.run = s.run AND r.seat = s.seat AND r.tick = s.f0 + 180) AS owner_3s
    FROM stimuli s
), parts AS (
    SELECT m.*,
           CASE WHEN m.category = 'human' AND m.juked > 0 THEN 1.0
                WHEN m.first_move IS NULL THEN 0.0 ELSE (75 - (m.first_move - m.f0)) / 60.0 END AS speed,
           CASE m.category
               WHEN 'ball' THEN CASE WHEN m.ball_dist < 0.9 AND coalesce(m.ball_dist_1s, 9) < 0.9 THEN 1.0
                                     ELSE greatest(0.0, least(1.0, (m.ball_dist - coalesce(m.ball_dist_1s, m.ball_dist))
                                          / CASE m.seat WHEN 2 THEN 3.85 WHEN 3 THEN 3.6 ELSE 4.65 END)) END
               WHEN 'human' THEN CASE WHEN m.juked > 0 THEN 1.0
                                      ELSE least(1.0, coalesce(m.human_dist_1s, 0) / greatest(m.human_dist, 0.1)) END
               WHEN 'teammate' THEN least(1.0, coalesce(m.human_dist_1s, 0) / 2.0)
               ELSE least(1.0, coalesce(m.wall_gap_1s, 0) / 1.5) END AS direction,
           CASE m.category
               WHEN 'ball' THEN coalesce(m.won_ball, 0.0)
               WHEN 'teammate' THEN CASE WHEN m.received > 0 THEN 1.0
                                         WHEN m.owner_3s >= 2 AND m.owner_3s <> m.seat OR m.owner_3s = m.seat THEN 0.5
                                         ELSE 0.0 END
               ELSE CASE WHEN m.robbed > 0 THEN 0.0 ELSE 1.0 END END AS outcome
    FROM measured m
), decision AS (
    SELECT run, seat, tick, choice AS move, json_extract_string(payload, '$.context') AS context,
           split_part(json_extract_string(payload, '$.context'), '/', 3) AS phase,
           json_extract_string(payload, '$.scene') AS scene,
           json_exists(payload, '$.analyst') AS advised
    FROM flight.events WHERE kind = 'response_intent'
)
SELECT p.run, p.category, p.stimulus_id, p.tick, p.stimulus, p.phase, p.seat,
       CASE p.seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' ELSE 'Zip' END AS robot,
       d.move, d.scene, d.context, coalesce(d.advised, false) AS advised,
       round(p.speed, 4) AS speed, round(p.direction, 4) AS direction, round(p.outcome, 4) AS outcome,
       round(0.3 * p.speed + 0.3 * p.direction + 0.4 * p.outcome, 4) AS reaction
FROM parts p
-- The move the robot reacted with: its latest decision for this phase, up to a third of a second
-- after the stimulus.
ASOF LEFT JOIN decision d ON d.run = p.run AND d.seat = p.seat AND d.phase = p.phase AND d.tick <= p.tick + 20
