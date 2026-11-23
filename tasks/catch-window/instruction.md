# Catch the nursery pod

Pilot the relief catcher at CEILING. Five flights begin at different distances. Your policy moves toward the pad, braces when within 28 centimetres of centre, then moves away when its promised hold expires. Write a JSON object to `/logs/artifacts/policy.json` with two integer fields. `lead` is the number of ticks before arrival to begin moving (0–235). `hold` is the number of ticks after contact to stay planted (0–90). A tick lasts 1/60 second.

The receiver covers once it reaches its mark. Arrival position, contact speed and custody determine the grade. Some starts need more than half a second of travel. Allow 18 ticks of stable custody for a full catch.
