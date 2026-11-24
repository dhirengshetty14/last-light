/* @bruin
name: flight.band_deliveries
type: duckdb.sql
description: "Every time a robot took in a crewmate's warning or tip that was sent through the BAND room: who said it, who heard it, how long BAND took, and whether the listener gave up on BAND after five seconds and took it off the game's own harbor radio instead. Empty for matches played without the BAND bridge."
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
    description: "Event number of the delivery"
    primary_key: true
    checks:
      - name: positive
  - name: message
    type: integer
    description: "Number of the message within the match, from the talk event that sent it"
    checks:
      - name: positive
  - name: listener
    type: varchar
    description: "Robot that took the message in"
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: speaker
    type: varchar
    description: "Robot that said it"
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: topic
    type: varchar
    description: "warn or tip"
    checks:
      - name: accepted_values
        value: ["warn", "tip"]
  - name: route
    type: varchar
    description: "band when BAND delivered it to the listener, radio when BAND took too long"
    checks:
      - name: accepted_values
        value: ["band", "radio"]
  - name: seconds
    type: double
    description: "Game time from the robot saying it to the listener taking it in"
    checks:
      - name: non_negative
      - name: max
        value: 5
depends:
  - flight.events
materialization:
  type: table
custom_checks:
  - name: A robot takes in each message once
    query: SELECT count(*) FROM (SELECT run, message, listener FROM flight.band_deliveries GROUP BY ALL HAVING count(*) > 1)
    value: 0
  - name: Nobody is delivered their own message
    query: SELECT count(*) FROM flight.band_deliveries WHERE listener = speaker
    value: 0
  - name: Every delivery follows a message sent through BAND to that robot
    query: |
      SELECT count(*) FROM flight.band_deliveries d
      LEFT JOIN flight.events e ON e.run = d.run AND e.kind = 'talk'
          AND try_cast(json_extract_string(e.payload, '$.msg') AS INTEGER) = d.message
          AND json_extract_string(e.payload, '$.via') = 'band' AND e.seq < d.seq
      WHERE e.seq IS NULL
    value: 0
@bruin */
-- One row per listener per message. The court writes a talk_heard event when a robot takes in a
-- crewmate's message; `via` says whether the BAND bridge reported it delivered or patience ran out.
SELECT run, seq, tick,
       try_cast(json_extract_string(payload, '$.msg') AS INTEGER) AS message,
       CASE seat WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS listener,
       CASE try_cast(json_extract_string(payload, '$.from') AS INTEGER)
           WHEN 2 THEN 'Pip' WHEN 3 THEN 'Morrow' WHEN 4 THEN 'Zip' END AS speaker,
       json_extract_string(payload, '$.topic') AS topic,
       json_extract_string(payload, '$.via') AS route,
       try_cast(json_extract_string(payload, '$.wait') AS DOUBLE) / 60.0 AS seconds
FROM flight.events WHERE kind = 'talk_heard'
