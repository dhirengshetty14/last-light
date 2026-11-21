# Last Light

At sundown on Saturn's Lamplight Harbor, five dockhands play for the right to switch on the beacon. Nell and Rafi attack the gold ring on the **right**. Pip, Morrow and Zip start in blue. Run the light into range, pass to make space, or dash through a rival to take possession. The first crew to three goals wins. At 100 seconds, the higher score wins. A tied score shares the light.

[See Pip trigger the beacon in Open Crews](docs/harbor-relay.jpg). [Watch a two-seat match from the earlier build with sound](docs/last-light-match.mp4).

## Play on this Mac

Double-click **Play Last Light.command** to start the native game and its local Bruin watcher. **exports/Last Light.app** also runs independently. The opening plays the theme, introduces each crew member in a voiced close-up, then shows the two modes. Use Space to advance an introduction or Escape to choose a mode immediately. After choosing a mode, select **P1 Nell · P2 Rafi** or **P1 Rafi · P2 Nell**. Each pilot keeps their own ability. The key bindings follow the player number. [See the pilot picker](docs/choose-pilots.jpg). Click **Take the court** after the briefing. Two players can share a keyboard and screen.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | WASD | Arrow keys |
| Shoot at Gold | E | Enter |
| Pass, or call for the ball from a machine ally | F | Slash |
| Dash or steal from a nearby opponent | Shift | Period |
| Offer a jersey, or end your agreement | Q | P |

Tab opens the robot notebooks. Each entry shows the robot’s current goal and tactic, what it saw, and how many of its decisions have been graded this match. Escape pauses. M mutes all audio. B reduces background movement. A single gamepad controls Player 2. With two connected pads, each controls a seat in connection order. Use the left stick, A to shoot, X to pass, right shoulder to dash and Y to offer a jersey.

**Rivals** keeps the two people on Gold against three autonomous machines. **Open Crews** moves play to the ring-shadow dock. Walk within two meters of a machine and offer it a jersey. Pip is willing to join early. Morrow helps a trailing team. Zip wants evidence that you pass. One defender always stays with Blue. Recruits can receive and return passes, turn down a call, and return to Blue after two ignored openings. Each robot remembers which pilot broke an agreement across matches on this device. A completed pass to the other pilot can repair trust when the robot sees the catch. Complete two consecutive passes to recharge every dash on your crew. Interceptions, a change of jersey and restarts break the sequence. The top-right bars show when each pilot can dash again. Sideline strips respond to each pass in the sequence, lamps count goals at both ends and the beacon calls an aurora across the gallery.

A dotted arc appears when a human can shoot. Long throws fall short and the ball stays live. Throws lead a running teammate using the expected flight time. Defenders can intercept the ball anywhere along its path. Nell has the longest dash, Rafi a wider catch, Pip a longer reach when stripping the ball, Morrow a higher catch, and Zip the quickest recovery between dashes. When a robot scores after unaided machine possession, the far beacon brings a whale across the gallery and widens both hoops for ten seconds.

## Simulation and learning

The same GDScript court runs the rendered match, training episodes and Harbor verifier. It advances at 60 physics ticks per second, with capped acceleration, braking, contact separation, dash cooldowns, swept hoop crossings, gravity, rebounds and handoffs. The render loop interpolates player and ball positions. The controls, local policy, physics, deterministic verifiers, music and recorded voice clips run on the Mac. The optional Gemini connection supplies tactical suggestions in the background.

Pip, Morrow and Zip each have a separate local contextual bandit, scouting notebook and seeded random generator. Pip watches nearby play within 3.2 meters, Morrow watches up to 5.1 meters and Zip up to 4 meters. A pass addressed to a robot is always visible to that receiver. It can pressure, screen, cut a pass, lead a loose ball, offer an outlet, advance, flank, carry, pass or finish. Its context includes possession, range, the observed carrier's shot/pass tendencies and lane. Movement skills and alliance terms are game rules. The policy chooses from legal tactics, reacts to possession changes and calls, and reassesses a continuing opportunity after 35 ticks. Throws settle when the court has an outcome. Historical estimates supply a bounded prior. Recent outcomes can change the next preference within one match. Aggregate preferences carry across matches and launches. Observed shot counts, passing tendencies, running lanes and team membership start fresh each match. Each robot saves its learned estimates and its relationship with Nell and Rafi separately. The relationship follows the character through a player swap.

For a reaction, the simulator checks the witnessed opportunity, legal choice, approach, physical execution and world consequence. It assigns weights of 0.10, 0.10, 0.20, 0.25 and 0.35. Only 1.00 is a full pass. Every throw by a human or robot also has its own five-check outcome. Points are recorded as integer hundredths. The policy receives its observation and legal choices. A separate update consumes the verified grade once per decision. The public ledger shows choices and reasons. These checks and replay tests cover known failure modes. Reward design can still favor an unintended strategy.

The checkpoint comes from 120 simulated matches against four scripted human styles. Frozen comparisons use 32 other seeded matches, common inputs and identical exploration rates. The evaluation file includes win counts, graded reactions, per-action failures, and timing for the chooser and learner callbacks. Across 120 training matches, Pip received 3,964 verified tactical updates, Morrow 3,938 and Zip 3,859. In held-out play, full tactical passes rose from 20.2% to 24.6%. Blue won 20 of 21 Rivals fixtures with training and 21 of 21 before training. The local checks and the match score measure different outcomes. The signed 0.4 Mac build rendered 972 measured match frames at 1280 × 752 on an Apple M5 with the local policy. Median frame time was 8.49 ms and the 95th percentile was 11.66 ms. [Frame-time sample](docs/last-light-performance.json).

- [Authoritative court](game/star_match.gd)
- [Policy](learning/star_policy.gd), [trainer](learning/star_train.gd) and [evaluation](learning/star_eval.json)
- [Visible world, cast and input](game/last_light.gd)
- [Five-condition Harbor task](tasks/ring-window/instruction.md)

## Host the game radio

Players launch the game, choose a mode and take the court. Both modes work offline with local tactics and recorded character voices. On a Mac configured by the host, even a double-click on the app starts a private loopback service. Pip, Morrow and Zip each call `gemini-3.1-flash-lite` with their own observation, goal and recent history. Every eight seconds each robot can request a small playbook while local movement, input and sound continue. The game checks the reply against the current team and legal moves. A timeout or provider error leaves the robots playing. Tab opens the public tactical notebook.

**Demo host, once per macOS account.** From this checkout run `python3 host/radio.py --configure` and enter the publisher's Gemini key at the hidden prompt. The helper saves it in a mode-0600 file under `~/Library/Application Support/Last Light Host/`. Relaunch the app. An inherited `GEMINI_API_KEY` also works for a developer launch. The key stays on the host. Each game starts its helper on a dynamically assigned loopback port and stops it on exit. This path uses the Mac's Python 3 installation. Plain downloads on other Macs play offline until the publisher supplies a shared service.

**Shared hosting is prepared.** Build the included container with `docker build -t last-light-radio host`. Run it behind an HTTPS endpoint, bind its `PORT` to the host platform and supply `GEMINI_API_KEY` as a server secret. Put just its HTTPS origin in the `last_light/radio/url` project setting before export. For development, `LAST_LIGHT_RADIO_URL` overrides that setting. The fixed `POST /v1/playbook` route accepts bounded court observations. The host chooses the prompt, model and schema and returns validated moves, public reasons and token counts. Each service process caps calls at six concurrent, 72 per minute and 900 per rolling hour. A shared deployment needs its own project-wide spending limit. This build ships with an empty shared URL.

## Bruin and replay

The native launcher starts the watcher if Bruin is installed. Each match writes a locally buffered JSONL trajectory, including a four-Hz court trace, ownership, releases, social changes, tactic decisions, outcomes, verifier flags and scores. Bruin refreshes a DuckDB database from sealed lines approximately every two seconds. Its checks include unique sequence IDs, bounded grading, one resolved learning example per decision, and machine attribution for beacon events. For connected matches, `flight.model_calls` reports the scout snapshot, requested and served model, request status, measured latency, token counts and returned playbook. `flight.agent_decisions` links each decision to its public reason, proposal, whether it was applied, overridden or illegal, most recent transport state and eventual verifier checks. The final whistle shows completed passes, steals, machine-lit beacons and Open Crews relays. The Bruin scoreboard groups those events by match and records the mode and each crew’s relay total. Local verified response summaries feed back into the next launch. The release stores data under the existing `Godot/app_userdata/This Side Up` directory so existing runs stay readable.

```sh
python3 telemetry/watch.py --watch
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.court_scoreboard'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.failure_modes'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select robot,tick,tactic,public_reason,decision_source,score from flight.agent_decisions order by run desc,tick desc limit 12'
```

The [recorded Gold win](docs/match-87.jsonl) includes the starting policy and both pilots’ input changes. Replay it with `godot --headless --path . -s tools/replay_court.gd -- docs/match-87.jsonl`. The replay checks every recorded event against a fresh simulation.

For seeded runs, launch the app with `-- --seed=87`. Training and automated playtests isolate fixture logs from live player trajectories. Reproduce the checks with Godot 4.7.2. The court playtest uses both keyboard seats and the regular opening, menu, pause and finish flow.

```sh
godot --headless --path . -s tests/star_match_test.gd
godot --headless --path . -s tests/gemini_court.gd
python3 tests/radio_host_test.py
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --seed=87
godot --headless --path . -s learning/star_train.gd
docker build -t last-light-harbor:4.7.2 -f tasks/Dockerfile .
tasks/check-local.sh ring-window
```

To edit the game, open `project.godot`. The original nursery scenario is available as `game/flight.tscn`. The main scene and native release open Last Light. See [asset and voice credits](licenses/ART-CREDITS.txt).
