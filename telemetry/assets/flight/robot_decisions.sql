/* @bruin
name: flight.robot_decisions
type: duckdb.sql
description: "Every graded robot decision in plain words: its task, situation, move, verifier score and the first of the five checks it failed. The base of the live robot report and of the RL scoreboard."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id"
    primary_key: true
    checks:
      - name: not_null
  - name: seat
    type: integer
    description: "Robot seat"
    primary_key: true
    checks:
      - name: min
        value: 2
      - name: max
        value: 4
  - name: decision_id
    type: bigint
    description: "Event number of the decision"
    primary_key: true
    checks:
      - name: not_null
  - name: robot
    type: varchar
    description: "Robot name"
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: task
    type: varchar
    description: "Which of the seven tasks the decision belongs to"
    checks:
      - name: accepted_values
        value: ["Win the star back", "Reach a loose star first", "Get open for a teammate", "Keep the star under pressure", "Carry the star forward", "Complete a pass", "Finish at the ring"]
  - name: verifier
    type: integer
    description: "Generation of outcome checks: 12 before court 13, 13 since"
    checks:
      - name: accepted_values
        value: [12, 13]
  - name: score
    type: double
    description: "Verifier score from 0 to 1"
    checks:
      - name: min
        value: 0
      - name: max
        value: 1
depends:
  - flight.agent_decisions
  - flight.events
materialization:
  type: table
custom_checks:
  - name: Every graded robot decision belongs to exactly one task
    query: SELECT count(*) FROM flight.robot_decisions WHERE task IS NULL OR situation IS NULL
    value: 0
  - name: A decision that is not fully verified names the check it broke at
    query: SELECT count(*) FROM flight.robot_decisions WHERE NOT full_pass AND breaks_at IS NULL
    value: 0
@bruin */
-- One row per graded robot decision, in plain words: which task it was, the situation the robot was
-- in, the move it picked, its verifier score and the first of the five checks it failed.
-- Situations before court 12 read star2/<seat>/<phase>/<reads>/<in range>/<lane>. Since court 12 a
-- carrier under pressure reads star2/<seat>/carry/<hot|warm>/<rival>, and since court 13 the three
-- tasks with new outcome checks end in /t.
WITH courts AS (
    SELECT run, max(court) AS court FROM flight.events GROUP BY run
), parts AS (
    SELECT d.*, split_part(context, '/', 3) AS phase, split_part(context, '/', 4) AS fourth,
           split_part(context, '/', 5) AS fifth, c.court,
           -- Court 13 replaced the outcome checks of three tasks, so scores from before and after
           -- are never compared with each other.
           CASE WHEN c.court >= 13 THEN 13 ELSE 12 END AS verifier
    FROM flight.agent_decisions d JOIN courts c USING (run) WHERE d.score IS NOT NULL
), named AS (
    SELECT *, fourth IN ('hot', 'warm') AS pressed,
           upper(fifth[1]) || fifth[2:] AS rival_name
    FROM parts
)
SELECT run, origin, court, verifier, seat, robot, tick, decision_id, context, phase, tactic AS move,
       CASE WHEN pressed THEN fourth ELSE 'free' END AS pressure,
       CASE WHEN pressed THEN rival_name END AS rival,
       CASE
           WHEN phase = 'carry' AND tactic = 'finish' THEN 'Finish at the ring'
           WHEN phase = 'carry' AND tactic = 'pass' THEN 'Complete a pass'
           WHEN phase = 'carry' AND pressed THEN 'Keep the star under pressure'
           WHEN phase = 'carry' THEN 'Carry the star forward'
           WHEN phase = 'defend' THEN 'Win the star back'
           WHEN phase = 'support' THEN 'Get open for a teammate'
           WHEN phase = 'loose' THEN 'Reach a loose star first'
       END AS task,
       CASE
           WHEN phase = 'carry' AND fourth = 'hot' THEN 'Has the star, ' || rival_name || ' can reach it'
           WHEN phase = 'carry' AND fourth = 'warm' THEN 'Has the star, ' || rival_name || ' closing in'
           WHEN phase = 'carry' AND fifth = '1' THEN 'Has the star in shooting range'
           WHEN phase = 'carry' THEN 'Has the star in the open'
           WHEN phase = 'defend' AND fourth = 'pass' THEN 'Defending a crew that passes'
           WHEN phase = 'defend' AND fourth = 'shoot' THEN 'Defending a crew that shoots'
           WHEN phase = 'defend' THEN 'Defending'
           WHEN phase = 'support' THEN 'A teammate has the star'
           WHEN phase = 'loose' THEN 'The star is loose'
       END AS situation,
       decision_source, disposition, score, full_pass, verifier_checks,
       CASE WHEN NOT full_pass THEN
           (['Saw the situation', 'Legal move', 'Approach', 'Carried it out', 'It worked'])[list_position(verifier_checks, false)]
       END AS breaks_at,
       floor(tick / 3600)::INTEGER AS minute
FROM named
