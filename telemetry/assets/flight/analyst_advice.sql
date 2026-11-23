/* @bruin
name: flight.analyst_advice
type: duckdb.sql
depends:
  - flight.reactions
  - flight.court_scoreboard
materialization:
  type: table
custom_checks:
  - name: Advice only names a move that is legal in its phase
    query: |
      SELECT count(*) FROM flight.analyst_advice
      WHERE NOT list_contains(CASE phase WHEN 'carry' THEN ['drive','flank','pass','finish','evade']
                                         WHEN 'support' THEN ['outlet','advance']
                                         WHEN 'defend' THEN ['screen','cut','press']
                                         WHEN 'loose' THEN ['recover','lead'] ELSE [] END, prefer)
         OR NOT list_contains(CASE phase WHEN 'carry' THEN ['drive','flank','pass','finish','evade']
                                         WHEN 'support' THEN ['outlet','advance']
                                         WHEN 'defend' THEN ['screen','cut','press']
                                         WHEN 'loose' THEN ['recover','lead'] ELSE [] END, avoid)
    value: 0
  - name: A robot only learns from its teammates, never from itself
    query: SELECT count(*) FROM flight.analyst_advice WHERE teacher = robot
    value: 0
@bruin */
-- Peer learning. For each robot, phase and situation, the move with which its TEAMMATES reacted best
-- and the one with which they reacted worst, over the newest match and the two before it in that
-- mode. Situations come at three levels: exact ("near/coming/ahead/pressed/wall"), broad (the first
-- three parts: where the star is and how it moves) and '*' (the phase as a whole). A move needs 5
-- reactions at that level, and the best must beat the worst by 0.08. The robot keeps its own memory
-- and weighs this as advice for the most exact level it has.
WITH newest AS (
    SELECT run, mode FROM flight.court_scoreboard
    WHERE run IN (SELECT run FROM flight.reactions)
    ORDER BY try_cast(split_part(run, '-', 1) AS BIGINT) DESC LIMIT 1
), recent AS (
    SELECT s.run FROM flight.court_scoreboard s, newest n
    WHERE s.mode IS NOT DISTINCT FROM n.mode
    ORDER BY try_cast(split_part(s.run, '-', 1) AS BIGINT) DESC LIMIT 3
), seen AS (
    SELECT r.* FROM flight.reactions r JOIN recent USING (run) WHERE r.move IS NOT NULL
), by_robot AS (
    SELECT seat, any_value(robot) AS robot, phase, '*' AS scene, move, count(*) AS n, avg(reaction) AS score
    FROM seen GROUP BY seat, phase, move HAVING count(*) >= 5
    UNION ALL
    -- The broader situation: where the star is and how it moves, without the human and the wall.
    SELECT seat, any_value(robot), phase, array_to_string(string_split(scene, '/')[1:3], '/'), move, count(*), avg(reaction)
    FROM seen WHERE scene IS NOT NULL GROUP BY 1, 3, 4, 5 HAVING count(*) >= 5
    UNION ALL
    SELECT seat, any_value(robot), phase, scene, move, count(*), avg(reaction)
    FROM seen WHERE scene IS NOT NULL AND len(string_split(scene, '/')) > 3
    GROUP BY seat, phase, scene, move HAVING count(*) >= 5
), learner AS (
    SELECT * FROM (VALUES (2, 'Pip'), (3, 'Morrow'), (4, 'Zip')) v(seat, robot)
), peer AS (
    SELECT l.seat, l.robot, b.phase, b.scene, b.move, sum(b.n) AS n, sum(b.score * b.n) / sum(b.n) AS score,
           arg_max(b.robot, b.score) AS teacher, max(b.score) AS teacher_score, arg_max(b.n, b.score) AS teacher_n
    FROM learner l JOIN by_robot b ON b.seat <> l.seat
    GROUP BY l.seat, l.robot, b.phase, b.scene, b.move
), ranked AS (
    SELECT seat, any_value(robot) AS robot, phase, scene, count(*) AS moves_compared, sum(n) AS evidence,
           arg_max(move, score) AS prefer, max(score) AS prefer_score,
           arg_min(move, score) AS avoid, min(score) AS avoid_score,
           arg_max(teacher, score) AS teacher, arg_max(teacher_score, score) AS teacher_score,
           arg_max(teacher_n, score) AS teacher_n
    FROM peer GROUP BY seat, phase, scene
)
SELECT (SELECT run FROM newest) AS run, k.seat, k.robot, k.phase, k.scene, k.prefer, round(k.prefer_score, 3) AS prefer_score,
       k.avoid, round(k.avoid_score, 3) AS avoid_score, k.evidence, k.teacher, round(k.teacher_score, 3) AS teacher_score,
       round(o.score, 3) AS own_score_with_prefer,
       (SELECT max(tick) FROM flight.reactions WHERE run = (SELECT run FROM newest)) AS through_tick,
       printf('Learned from %s%s: %s reacted %.2f (%d plays), %s %.2f', k.teacher,
              CASE WHEN k.scene = '*' THEN '' ELSE ' when ' || replace(k.scene, '/', ', ') END,
              k.prefer, k.teacher_score, k.teacher_n, k.avoid, k.avoid_score) AS reason
FROM ranked k
LEFT JOIN by_robot o ON o.seat = k.seat AND o.phase = k.phase AND o.scene = k.scene AND o.move = k.prefer
WHERE k.moves_compared >= 2 AND k.prefer_score - k.avoid_score >= 0.08
