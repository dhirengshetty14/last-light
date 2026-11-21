# This Side Up

A mother whale has matched speed with a nursery dock above Saturn. Her calf is suspended inside a transport pod. The crew has one good chance to send the calf home. Morrow also wants to send the herd recording home with her.

[Watch ten seconds on the moving dock](docs/living-dock.mp4) · [Watch the opening and rescue](docs/first-shift.mp4) · [Inspect the eight cast views](docs/crew-studio.jpg)

## Play on this Mac

Double-click **Play This Side Up.command**. It opens the native build and starts the local Bruin flight recorder when Bruin is installed. The standalone game also opens directly from **exports/This Side Up.app**. To edit the game, import **project.godot** in Godot 4.7.2. Two people share one display. Both characters accept input at the same time.

**Begin story** introduces the three agents on the dock. In the induction, Nell presses **F** to pay out the line and Rafi presses **period** to plant the kickplate. Let the practice buoy arrive. The rescue starts with a fresh world and fresh attribution for every vote. Space advances the story and Enter skips ahead. **Game modes** opens First Rescue or Ring Storm directly.

| Crew | Movement | Latch / cover | Power | Carry reel | Choose partner / duty | Offer or accept / counter / break |
| --- | --- | --- | --- | --- | --- | --- |
| Nell, tow operator | WASD | E / Space | F, extend flight time | R | Tab / Z | Q / T / X |
| Rafi, receiver | Arrow keys | Enter / slash | Period, bank the arrival | Comma | Right bracket / left bracket | P / O / I |

A single controller pilots Rafi. Two controllers pilot Nell and Rafi in connection order. Use the left stick to move, A to latch, right trigger to cover, right bumper for the tool, X for the reel, Y for a deal, left bumper to select a partner and B to break a deal. On the keyboard, F1 opens controls, F2 opens the verifier, L toggles the public ledger, M mutes audio and B toggles reduced background motion. The controls menu also offers VSync. The default caps rendering at 120 frames per second and keeps 60 Hz physics. Both display preferences persist.

**Meet the crew** opens the same five 3D figures used during a rescue. Left and right select a character, up and down change expression, C changes distance, V rotates the turntable and mouse drag orbits the camera. G or Escape returns.

## Rescue rules

Stand in a lit pad and latch it to cast a persistent vote. Three matching latches held for half a second change gravity. The first CEILING majority sends the pod across the bay and shakes the pinned recording loose. Reach the incoming mark, cover, control the relative impact speed and hold the pod for 18 physics ticks. Send three votes to HATCH for the final leg. Someone can carry the reel from CEILING to HATCH along the way. Delivery with the recording has its own ending. A damaged shell or a missed departure can end the flight.

- **Pip**, the orange rescue hand, has a wide net and a longer cover window. A promise to fetch something can put Pip on the wrong side of the bay for a catch.
- **Morrow**, the brass archivist, reads the landing forecast and can recover the herd recording. If the reel comes loose after Morrow has promised cover, those duties compete.
- **Zip**, the ivory courier, can accelerate along the rail. A closing hatch makes a vote more urgent than a delivery contract.

Any crew member can make a paid offer. The provider can accept, counter or break it. Settlement transfers escrowed chips once. Kept and broken commitments change the buyer's memory of that provider. The ledger shows the decision and its reason. Let both humans stand still to see the agents negotiate and cause the first gravity change themselves.

First Rescue takes place at the Saturn Nursery Dock with a 90-second deadline. Ring Storm moves the shift to the Enceladus ferry, with gust-displaced intercepts, recurring six-second hatch windows and two points of shell integrity. The distant tugs, working overhead crane and breathing mother have independent motion. Activity slows during close catches. Shutters and pilot lamps still convey hatch state with reduced motion enabled.

## Learning and verification

The authoritative simulator uses integer centimetres and a 60 Hz clock. Rendering, camera movement, voice and analytics run independently. A new live shift draws a fresh world seed. Set `-- --seed=17` to reproduce a starting world. Each machine has a seeded decision stream. Navigation, grasping and the motor skills are authored. The learned component is a tabular contextual bandit over four responses to a witnessed event. It updates on each resolved response. There is no payment for repeating a completed check.

| Opportunity | Intermediate checks, in order | Weights |
| --- | --- | --- |
| Catch | Cover armed, receiver reached intercept, assigned receiver made contact, relative speed accepted, six ticks of secure custody, eighteen ticks of secure custody | .10, .15, .20, .20, .20, .15 |
| Social response | Trigger traced to a world event, choice legal when committed, correct lane reached, action physically executed, consequence observed | .15, .15, .20, .25, .25 |

The numeric verifier uses hundredths. Every total below 1.00 fails the action. A stable six-tick grip followed by a slip at tick twelve can score 0.85 and still count as a failure. The acting policy receives legal choices and world context. The learner receives the verified result after the opportunity closes. Catching or healing does not certify a promise to another agent. Keystrokes have no training value on their own.

**learning/checkpoint.json** contains the policy from 400 training flights. **learning/evaluation.json** compares it with the prior using the same 45 held-out seeds in each location, frozen policies, fixed input proxies and 15 hands-off flights per location. These are repeatable local benchmarks. The responses taken can change the number of subsequent opportunities.

| Mode | Full social responses, prior → trained | Full assigned catches, prior → trained | Calves delivered, prior → trained |
| --- | --- | --- | --- |
| First Rescue | 128/377 → 154/380 | 83/90 → 84/90 | 45/45 → 45/45 |
| Ring Storm | 133/341 → 151/336 | 83/91 → 82/91 | 45/45 → 45/45 |

All 30 hands-off runs of the trained crew caused the opening release. These results include the one-catch regression in Ring Storm. An earlier failure in that mode led to a motor fix. After catching a pod off-centre, the receiver now braces at the actual impact position for the full custody window.

## Bruin and replay

Every flight writes an initial policy, ruleset, seed, human input changes, reasons, milestones, evidence IDs, 15-tick spatial samples and a final state digest to JSONL. A worker writes batches off the game thread. F2 also reads the local Bruin summary and shows how many verified reactions passed in full. On macOS the logs are in **~/Library/Application Support/Godot/app_userdata/This Side Up/flights**.

The launcher runs Bruin on changed, complete line prefixes. Six DuckDB tables retain the events, grades, grouped failure modes, per-check misses, causal gravity votes and joined training examples. Five quality checks cover bounded full passes, duplicate grades, sequence gaps and physical vote provenance. Verified local reactions are aggregated by role, context and action and merged into the starting policy of later flights. Each run records its own starting policy for replay. Fixture and camera-capture origins are excluded from personal learning. The watcher publishes grouped observations with an atomic rename. The database lives in **telemetry/local/nursery.duckdb**. [Bruin](https://getbruin.com/docs/bruin/)

With Godot and Bruin on PATH, from the repo root:

```sh
godot --headless --path . --script res://tests/simulation.gd
godot --headless --path . --script res://tests/entrypoints.gd
godot --headless --path . --script res://tools/replay.gd -- docs/sample-flight.jsonl
python3 telemetry/watch.py docs/sample-flight.jsonl
bruin query -c nursery --config-file telemetry/local/bruin.yml -q 'select * from flight.check_failures order by misses desc'
```

To build a fresh policy and evaluation:

```sh
godot --headless --path . --script res://learning/train.gd -- 400
godot --headless --path . --script res://tools/evaluate.gd
```

The two **tasks/** packages use Harbor's separate verifier format. A policy can submit only a bounded pair of numbers. The verifier replays five distinct starts in the same GDScript simulator. **catch-window** tests intercept timing and stable custody. **broken-promise** tests a response to a real broken contract and a change of gravity. The native Harbor Docker provider on this Mac rejected the declared no-network mode. **tasks/check-local.sh** runs the same oracle and verifier scripts in fresh, read-only Docker containers with Docker networking disabled for both. On a Harbor provider that supports the declared mode, use `harbor run -p tasks -a oracle`. [Harbor separate verifiers](https://docs.harborframework.com/tasks/separate-verifier)

```sh
docker build -f tasks/Dockerfile -t this-side-up-harbor:4.7.2 .
./tasks/check-local.sh
```

## Art and sound

The supplied five-character image is the title painting and character reference. Two generated environment plates supply the distant photographic detail. The playable deck, crane, tenders, doors, calf, cargo, characters and collision rules use local geometry and code. The plates have localized eye, breathing and ice-plume deformation. The human performers use two different textured Rocketbox facial rigs with blend shapes and five animation clips. The three machines have independently articulated heads, limbs and expressive optics. Their machining, apron, tape reels, book, net and skates are generated in Blender.

**art/source/** contains the Blender and texture scripts, the recorded voice script, and both exterior prompts. The checked-in runtime assets let a player launch without Blender or a model service. To regenerate the mesh assets, use Python with Pillow and NumPy, then Blender 5.2:

```sh
python3 art/source/fetch_people.py /tmp/nursery-people
python3 art/source/prepare_textures.py /tmp/nursery-people
python3 art/source/weather.py /tmp/nursery-paint
blender --background --python art/source/build_people.py -- /tmp/nursery-people
blender --background --python art/source/build_agents.py -- /tmp/nursery-paint
python3 art/source/fetch_steel.py
godot --headless --editor --path . --import
```

Human rigs and textures are adapted from Microsoft Rocketbox, pinned at revision `0943055db6ec570bcef9f2c8b41c9e5467c808f9`. Its MIT license is in **licenses/Rocketbox-LICENSE.txt**. The photographic deck material is Rob Tuytel's CC0 Metal Plate 02. [Rocketbox](https://github.com/microsoft/Microsoft-Rocketbox) · [Poly Haven](https://polyhaven.com/a/metal_plate_02)

The three voices are pre-rendered Kokoro lines. Each character has its own voice and delivery. Music, gravity calls and mechanical sound effects are synthesized in Godot. **tools/review_frame.py** is an optional, manually invoked Gemini screenshot review using an environment key. Gameplay and scoring run locally. [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) · [Gemini Flash-Lite](https://aistudio.google.com/docs/models/gemini-3.5-flash-lite)

## Measured performance

On an Apple M5 at 1280 × 752, the default native build recorded 1,380 frames per run after a 120-frame warm-up. Both human seats supplied scripted inputs, all three agents planned, and voice and trajectory recording were active. The 95th-percentile frame time was 12.09 ms in First Rescue and 11.23 ms in Ring Storm. With the Bruin watcher also rebuilding its local tables, First Rescue measured 12.62 ms at p95 and 14.70 ms at p99. The engine’s p95 physics step in that run was 0.27 ms. These are steady-state frame intervals on this machine. [Raw timings](docs/performance.json)

## Build and presentation

The macOS export preset builds a universal local app using the Godot 4.7.2 macOS template. `godot --headless --export-release macOS 'exports/This Side Up.app'` rebuilds it. The project currently supports two people at one station. An event presentation can run the native app directly from that machine. The two local preview videos in **docs/** use footage from the game. The full cut includes the title, voices, induction, a time-compressed rescue and the cast studio.

This is a personal pre-event build. The supplied event rules reserve submission code for the event and specify AdaL for the presentation video. [Organizer listing](https://luma.com/stxaoop0)
