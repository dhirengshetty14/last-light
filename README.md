# Last Light

At sundown on Saturn's Lamplight Harbor, five dockhands play for the right to switch on the beacon. Nell and Rafi attack the gold ring on the **right**. Pip, Morrow and Zip start in blue. Run the light into range, pass to make space, or dash through a rival to take possession. The first crew to three goals wins. At 100 seconds, the higher score wins. A tied score shares the light.

[Watch a two-seat match from the earlier build with sound](docs/last-light-match.mp4).

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

**Rivals** keeps the two people on Gold against three autonomous machines. **Open Crews** moves play to the ring-shadow dock. Walk within two meters of a machine and offer it a jersey. Pip is willing to join early. Morrow helps a trailing team. Zip wants evidence that you pass. One defender always stays with Blue. Recruits can receive and return passes, turn down a call, and return to Blue after two ignored openings. Each robot remembers which pilot broke an agreement across matches on this device. A completed pass to the other pilot can repair trust when the robot sees the catch.

A dotted arc appears when a human can shoot. Long throws fall short and the ball stays live. Players can intercept passes. Nell has the longest dash, Rafi a wider catch, Pip a longer reach when stripping the ball, Morrow a higher catch, and Zip the quickest recovery between dashes. When a robot scores after unaided machine possession, the far beacon brings a whale across the gallery and widens both hoops for ten seconds.

## Simulation and learning

The same GDScript court runs the rendered match, training episodes and Harbor verifier. It advances at 60 physics ticks per second, with capped acceleration, braking, contact separation, dash cooldowns, swept hoop crossings, gravity, rebounds and handoffs. The render loop interpolates player and ball positions. Music, character voice, controls, inference and verification all run locally.

Pip, Morrow and Zip each have a separate local contextual bandit, scouting notebook and seeded random generator. Pip watches nearby play within 3.2 meters, Morrow watches up to 5.1 meters and Zip up to 4 meters. A pass addressed to a robot is always visible to that receiver. It can pressure, screen, cut a pass, lead a loose ball, offer an outlet, advance, flank, carry, pass or finish. Its context includes possession, range, the observed carrier's shot/pass tendencies and lane. Movement skills and alliance terms are game rules. The policy chooses from legal tactics, reacts to possession changes and calls, and reassesses a continuing opportunity after 35 ticks. Throws settle when the court has an outcome. Historical estimates supply a bounded prior. Recent outcomes can change the next preference within one match. Aggregate preferences carry across matches and launches. Observed shot counts, passing tendencies, running lanes and team membership start fresh each match. Each robot saves its learned estimates and its relationship with Nell and Rafi separately. The relationship follows the character through a player swap.

For a reaction, the simulator checks the witnessed opportunity, legal choice, approach, physical execution and world consequence. It assigns weights of 0.10, 0.10, 0.20, 0.25 and 0.35. Only 1.00 is a full pass. Every throw by a human or robot also has its own five-check outcome. Points are recorded as integer hundredths. The policy receives its observation and legal choices. A separate update consumes the verified grade once per decision. The public ledger shows choices and reasons. These checks and replay tests cover known failure modes. Reward design can still favor an unintended strategy.

The checkpoint comes from 120 simulated matches against four scripted human styles. Frozen comparisons use 32 other seeded matches, common inputs and identical exploration rates. The evaluation file includes win counts, graded reactions, per-action failures, and timing for the chooser and learner callbacks. Across 120 training matches, Pip received 3,964 verified tactical updates, Morrow 3,938 and Zip 3,859. In held-out play, full tactical passes rose from 20.2% to 24.6%. Blue won 20 of 21 Rivals fixtures with training and 21 of 21 before training. The local checks and the match score measure different outcomes. The earlier [Mac frame-time sample](docs/last-light-performance.json) covers live play at 1280 × 752 on an Apple M5. Navigation and speech are authored locally. No external model key is required.

- [Authoritative court](game/star_match.gd)
- [Policy](learning/star_policy.gd), [trainer](learning/star_train.gd) and [evaluation](learning/star_eval.json)
- [Visible world, cast and input](game/last_light.gd)
- [Five-condition Harbor task](tasks/ring-window/instruction.md)

## Bruin and replay

The native launcher starts the watcher if Bruin is installed. Each match writes a locally buffered JSONL trajectory, including a four-Hz court trace, ownership, releases, social changes, tactic decisions, outcomes, verifier flags and scores. Bruin refreshes a DuckDB database from sealed lines approximately every two seconds. Its checks include unique sequence IDs, bounded grading, one resolved learning example per decision, and machine attribution for beacon events. Local verified response summaries feed back into the next launch. The release stores data under the existing `Godot/app_userdata/This Side Up` directory so existing runs stay readable.

```sh
python3 telemetry/watch.py --watch
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.court_scoreboard'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.failure_modes'
```

The [recorded Gold win](docs/match-87.jsonl) includes the starting policy and both pilots’ input changes. Replay it with `godot --headless --path . -s tools/replay_court.gd -- docs/match-87.jsonl`. The replay checks every recorded event against a fresh simulation.

For seeded runs, launch the app with `-- --seed=87`. Training and automated playtests isolate fixture logs from live player trajectories. Reproduce the checks with Godot 4.7.2. The second command uses both keyboard seats and the regular opening, menu, pause and finish flow.

```sh
godot --headless --path . -s tests/star_match_test.gd
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --seed=87
godot --headless --path . -s learning/star_train.gd
docker build -t last-light-harbor:4.7.2 -f tasks/Dockerfile .
tasks/check-local.sh ring-window
```

To edit the game, open `project.godot`. The original nursery scenario is available as `game/flight.tscn`. The main scene and native release open Last Light. See [asset and voice credits](licenses/ART-CREDITS.txt).
