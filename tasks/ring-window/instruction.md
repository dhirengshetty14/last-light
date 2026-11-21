# Find Nell's shooting window

Nell carries the light on the right wing. Blue has all three defenders. Choose when to dash and how close to get before shooting for Gold. The verifier replays five seeded positions at 60 Hz in the game simulator. It grades the first throw on possession, range, sustained flight, team contact and scoring. A turnover before release earns zero.

Write only a JSON object to `/logs/artifacts/policy.json`. Supply integer `shoot_cm` (80–500, floor distance to the center of the gold ring) and `dash_tick` (0–120). The motor runs toward the ring until release.
