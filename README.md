# Last Light

At sundown on Saturn's Lamplight Harbor, five dockhands play for the right to switch on the beacon. Nell and Rafi attack the gold ring on the **right**. Pip, Morrow and Zip start in blue. Run the light into range, pass to make space, or dash through a rival to take possession. The first crew to three goals wins. At two minutes, the higher score wins. A tied score shares the light.

Stills from Free Agents on the current court: [the opening comic page](docs/free-agents-opening.jpg), [a broken promise](docs/free-agents-promises.jpg) and [the robots' walkout](docs/free-agents-union.jpg).

[Watch the full Rivals match on the expanded court](docs/last-light-rivals.mp4). That recording predates court version 9, the harbor and the comic panels. Both pilot seats in this recording use automated keyboard input. Play starts at 0:35. [Recorded scores, frame times and Gemini responses](docs/last-light-rivals.json).

The earlier compact court appears in [Pip’s beacon play in Open Crews](docs/harbor-relay.jpg). [Watch a full Open Crews match with live Gemini and game audio](docs/last-light-live-gemini.mp4). The recording shows the three robots’ service response times and uses automated inputs for Rafi and Nell. [Match measurements](docs/last-light-live-gemini.json).

## Play on this Mac

Double-click **Play Last Light.command** to start the native game and its local Bruin watcher. **exports/Last Light.app** also runs independently. The opening plays the theme, Morrow tells the story in three spoken lines, and each of the five is introduced in a voiced close-up with one line on what only they can do. Then you choose one of three modes. Use Space to advance an introduction or Escape to choose a mode immediately. After choosing a mode, select **P1 Nell · P2 Rafi** or **P1 Rafi · P2 Nell**. Each pilot keeps their own ability. The key bindings follow the player number. [See the pilot picker](docs/choose-pilots.jpg). Click **Take the court** after the briefing. Two players can share a keyboard and screen.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | WASD | Arrow keys |
| GO: shoot inside the arc, otherwise dash or steal | Space | Enter |
| SHARE: pass, pay a promise, call for the star, or make a robot an offer | F | Slash |

Two buttons do everything. The bars at the bottom of the screen always say what each of your two buttons will do if you press it now, such as SHOOT!, STEAL, PAY PIP or SIGN ZIP. While you owe a robot a promise, SHARE passes to that robot. Otherwise a pass goes where you steer. The single-purpose keys still work: E shoots, Shift or Period dashes, R or Comma passes to a robot and Q or P makes an offer.

Tab opens the robot notebooks. Each entry shows the robot’s current goal and tactic, what it saw, and how many of its decisions have been graded this match. Escape pauses. M mutes all audio. B reduces background movement. A single gamepad controls Player 2. With two connected pads, each controls a seat in connection order. Use the left stick, A for GO and X for SHARE. Right shoulder, Y and B keep their single purposes: dash, offer and pass to a robot.

**The harbor.** Beyond the rail the dock looks out on a sea that mirrors the sky. The sun sets beside a ringed Saturn during the match and it is night by the whistle. Whales fly and surface around the dock, a lighthouse sweeps the water, ferries cross, lanterns rise, and the crowd behind the rail jumps for the crew that scores. When the robots walk out the harbor goes dark and the whales glow. B reduces all of this motion.

**The comic.** The opening is told as comic pages: a caption box for the story, then a page for each of the five with their name, their own words in a speech balloon and their power. During a match, sound words land on the court (YOINK!, PAID!, CHEAT!, STRIKE!, GOAL!), a small panel with the speaker's face and a balloon shows every line a robot says, and the picture turns to print for the pause after a goal.

**The story.** When the sun drops behind Saturn, Lamplight Harbor goes dark and the whales follow one light home. The dock crews play for who lights it, and tonight is the last night anyone lights it by hand. The machines have been promised a turn for thirty winters. Tonight they are counting.

**Free Agents** makes Nell and Rafi rival captains. Nell attacks the gold ring on the right, Rafi the blue ring on the left, and the most goals in three minutes wins. Before kickoff each robot picks a captain from what it remembers and signs for a promise the court can check. Pip wants the next shot. Zip wants two passes. Morrow wants the next shot to come off a pass. A promise only runs down while that captain’s crew holds the star, and a captain with two promises pays them in order. Keep one and the robot trusts you more. Break one and it walks out to the other captain, or downs tools if it is the only robot you have, until you offer new terms and keep them. Once both captains have broken a promise, a robot calls a vote on the radio. If two of the three vote to walk out, the robots form their own crew, the harbor lights drop, and Nell and Rafi have to share the gold ring against them, first to two. F or Slash passes where you steer. R or Comma passes to the robot you owe. Q or P beside a robot offers its terms. The promises panel, the labels over each robot and the always-on harbor radio show every deal, reason and ballot. After a paid promise a robot listens to offers for ten seconds, then names new terms, so a captain can never coast. Each robot speaks its own terms, payments, walkouts and ballots in its own recorded voice. Trust carries across matches on this device.

**Rivals** keeps the two people on Gold against three autonomous machines. **Open Crews** moves play to the ring-shadow dock. Walk within two meters of a machine and offer it a jersey. Pip is willing to join early. Morrow helps a trailing team. Zip wants evidence that you pass. One defender always stays with Blue. Recruits can receive and return passes, turn down a call, and return to Blue after two ignored openings. Each robot remembers which pilot broke an agreement across matches on this device. A completed pass to the other pilot can repair trust when the robot sees the catch. Complete two consecutive passes to recharge every dash on your crew. Interceptions, a change of jersey and restarts break the sequence. The top-right bars show when each pilot can dash again. Sideline strips respond to each pass in the sequence, lamps count goals at both ends and the beacon calls an aurora across the gallery.

The court measures 22 meters between rings, a quarter longer and wider than before version 9. The painted semicircles mark shooting range. The top-center scoreboard shows both teams, the game clock and the target score. The final card breaks down goals, shots, completed passes and takeaways by team. A dotted arc appears when a human can shoot. Long throws fall short and the ball stays live. Throws lead a running teammate using the expected flight time. Defenders can intercept the ball anywhere along its path. Every character has one power. Nell’s Ferry Run is the longest dash and the only one that protects the star. Rafi’s Long Shot scores from half a meter farther out. Pip’s Getaway is a burst of speed after every steal. Morrow’s Anchor slows any opponent carrying the star inside the ring painted around him. Zip’s Express passes fly a third faster. Beyond those, Rafi has a wider catch, Pip has a longer reach when stripping the ball, Morrow a deep defensive position and wide catch radius, and Zip the quickest recovery between dashes. When a robot scores after unaided machine possession, the far beacon brings a whale across the gallery and widens both hoops for ten seconds.

## Simulation and learning

The same GDScript court runs the rendered match, training episodes and Harbor verifier. It advances at 60 physics ticks per second, with capped acceleration, braking, contact separation, dash cooldowns, swept hoop crossings, gravity, rebounds and handoffs. The render loop interpolates player and ball positions. The controls, local policy, physics, deterministic verifiers, music and recorded voice clips run on the Mac. The optional Gemini connection supplies tactical suggestions in the background.

Pip, Morrow and Zip each have a separate local contextual bandit, scouting notebook and seeded random generator. Pip watches nearby play within 3.2 meters, Morrow watches up to 5.1 meters and Zip up to 4 meters. A pass addressed to a robot is always visible to that receiver. It can pressure, screen, cut a pass, lead a loose ball, offer an outlet, advance, flank, carry, pass or finish. Its context includes possession, range, the observed carrier's shot/pass tendencies and lane. Movement skills and alliance terms are game rules. The policy chooses from legal tactics, reacts to possession changes and calls, and reassesses a continuing opportunity after 35 ticks. Throws settle when the court has an outcome. Historical estimates supply a bounded prior. Recent outcomes can change the next preference within one match. Aggregate preferences carry across matches and launches. Observed shot counts, passing tendencies, running lanes and team membership start fresh each match. Each robot saves its learned estimates and its relationship with Nell and Rafi separately. The relationship follows the character through a player swap.

For a reaction, the simulator checks the witnessed opportunity, legal choice, approach, physical execution and world consequence. It assigns weights of 0.10, 0.10, 0.20, 0.25 and 0.35. Only 1.00 is a full pass. Every throw by a human or robot also has its own five-check outcome. Points are recorded as integer hundredths. The policy receives its observation and legal choices. A separate update consumes the verified grade once per decision. The public ledger shows choices and reasons. These checks and replay tests cover known failure modes. Reward design can still favor an unintended strategy.

The checkpoint comes from 120 simulated matches against four scripted human styles. Frozen comparisons use 32 other seeded matches, common inputs and identical exploration rates. The evaluation file includes win counts, graded reactions, per-action failures, and timing for the chooser and learner callbacks. On the expanded court, 120 training matches produced 5,949 verified tactical updates for Pip, 5,895 for Morrow and 5,786 for Zip. In the 32 held-out matches, the fraction of fully verified tactics was 21.4% for the starting policy and 21.3% for the trained policy. Blue won 21 of 21 trained Rivals fixtures against the four scripted styles. The 0.4 compact-court build has a separate historical rendering benchmark. [Frame-time sample](docs/last-light-performance.json).

**Learning who to trust.** In Free Agents each robot also keeps its own record of five kinds of social choice: which captain to sign with, what to do about a broken promise (let it go, stop work or leave), whether to take a rival captain's offer, whether to sign again with a captain who wronged it, and how to vote. A choice is graded by the next promise made to that robot. Kept is 100, broken is 0, and a choice that saw no further promise gets 50. The grade goes into the robot's record the moment the promise settles, during the match, and the radio log says so. Winning the showdown after a walkout earns no credit. A robot leaves its written rule for a choice only when its own record in the same situation says, beyond luck, that another choice has done better. The situation is what a spectator could see: the robot's ledger of promises kept and broken by each captain, whether the match is past half time, and one fact for that kind of choice. A robot with no history of either captain signs by the written rule. Launch with `-- --written-rules` to switch this off.

The shipped record is [learning/social_checkpoint.json](learning/social_checkpoint.json). It comes from 2,000 practice series of three matches against scripted captains whose habits with promises are hidden from the robots: always pays, never pays, pays only in the first half, pays one robot only, and pays about half the time. Practice entries are scaled down to 40 tries so that results from live play carry weight. Even so, where the record allows a habit to change at all, it takes about twenty contrary results in the same situation. Within one match a robot adapts through its memory of the captains, not by relearning.

[The held-out test](learning/social_eval.gd) plays 60 more series on seeds never practised. Half include a kind of captain never practised against. A verifier that knows the captains' habits checks every choice as it is made and adds three checks on how each match went, for a score from 0 to 1. [Results on the version 9 court](learning/social_eval.json): random choices 0.557, the written rules 0.649, the trained robots 0.655. Series by series, trained minus written is +0.006 with a standard error of 0.012, so training has not beaten the written rules. Both are well clear of random (+0.097, standard error 0.020). The trained robots overrode a written rule in 261 of 2,769 choices. The record was practised on the earlier, smaller court and has not been retrained for this one. One learned choice takes about 6 microseconds.

To check what live play has taught the robots, run the same test on the saved record:

```bash
godot --headless --path . -s learning/social_eval.gd -- --table="$HOME/Library/Application Support/Godot/app_userdata/This Side Up/last-light-policy.json"
```

- [Authoritative court](game/star_match.gd)
- [Policy](learning/star_policy.gd), [trainer](learning/star_train.gd) and [evaluation](learning/star_eval.json)
- [Social practice](learning/social_train.gd), [scripted captains](learning/captains.gd), [held-out test](learning/social_eval.gd) and [its results](learning/social_eval.json)
- [Visible world, cast and input](game/last_light.gd)
- [Five-condition Harbor task](tasks/ring-window/instruction.md)

## Host the game radio

Players launch the game, choose a mode and take the court. Both modes work offline with local tactics and recorded character voices. On a Mac configured by the host, even a double-click on the app starts a private loopback service. Pip, Morrow and Zip each call `gemini-3.1-flash-lite` with their own observation, goal and recent history. Every eight seconds each robot can request a small playbook while local movement, input and sound continue. The game checks the reply against the current team and legal moves. A timeout or provider error leaves the robots playing. Tab opens the public tactical notebook.

**Demo host, once per macOS account.** From this checkout run `python3 host/radio.py --configure` and enter the publisher's Gemini key at the hidden prompt. The helper saves it in a mode-0600 file under `~/Library/Application Support/Last Light Host/`. Relaunch the app. An inherited `GEMINI_API_KEY` also works for a developer launch. For a Vertex AI express key, append `--provider vertex` to the configure command. The provider choice is saved on the host alongside the key. Each game starts its helper on a dynamically assigned loopback port and stops it on exit. This path uses the Mac's Python 3 installation. Plain downloads on other Macs play offline until the publisher supplies a shared service.

**Shared hosting is prepared.** Build the included container with `docker build -t last-light-radio host`. Run it behind an HTTPS endpoint, bind its `PORT` to the host platform and supply `GEMINI_API_KEY` as a server secret. Put just its HTTPS origin in the `last_light/radio/url` project setting before export. For development, `LAST_LIGHT_RADIO_URL` overrides that setting. The fixed `POST /v1/playbook` route accepts bounded court observations. The host chooses the prompt, model and schema and returns validated moves, public reasons and token counts. Each service process caps calls at six concurrent, 72 per minute and 900 per rolling hour. A shared deployment needs its own project-wide spending limit. This build ships with an empty shared URL.

## Bruin and replay

The native launcher starts the watcher if Bruin is installed. Each match writes a locally buffered JSONL trajectory, including a four-Hz court trace, ownership, releases, social changes, tactic decisions, outcomes, verifier flags and scores. Bruin refreshes a DuckDB database from sealed lines approximately every two seconds. Its checks include unique sequence IDs, bounded grading, one resolved learning example per decision, and machine attribution for beacon events. For connected matches, `flight.model_calls` reports the scout snapshot, requested and served model, request status, measured latency, token counts and returned playbook. `flight.agent_decisions` links each decision to its public reason, proposal, whether it was applied, overridden or illegal, most recent transport state and eventual verifier checks. The final whistle shows completed passes, steals, machine-lit beacons and Open Crews relays. The Bruin scoreboard groups those events by match and records the mode and each crew’s relay total. Local verified response summaries feed back into the next launch. The release stores data under the existing `Godot/app_userdata/This Side Up` directory so existing runs stay readable.

```sh
python3 telemetry/watch.py --watch
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.court_scoreboard'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.failure_modes'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select robot,tick,tactic,public_reason,decision_source,score from flight.agent_decisions order by run desc,tick desc limit 12'
```

Recordings made before court version 9 replay on the earlier, smaller court, and the replay tool picks the court from the recording's header. The [recorded Gold win](docs/match-87.jsonl) includes the starting policy and both pilots’ input changes. Replay it with `godot --headless --path . -s tools/replay_court.gd -- docs/match-87.jsonl`. The replay checks every recorded event against a fresh simulation.

For seeded runs, launch the app with `-- --seed=87`. Training and automated playtests isolate fixture logs from live player trajectories. Reproduce the checks with Godot 4.7.2. The court playtest uses both keyboard seats and the regular opening, menu, pause and finish flow.

```sh
godot --headless --path . -s tests/star_match_test.gd
godot --headless --path . -s tests/free_agents_test.gd
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --written-rules --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --written-rules --seed=87
godot --headless --path . -s learning/social_eval.gd -- --table=learning/social_checkpoint.json
godot --headless --path . -s tests/gemini_court.gd
python3 tests/radio_host_test.py
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --rivals --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --swap-pilots --seed=87
godot --headless --path . -s learning/star_train.gd
docker build -t last-light-harbor:4.7.2 -f tasks/Dockerfile .
tasks/check-local.sh ring-window
```

Match sounds and voice lines are rendered offline. `python3 art/source/star_sfx.py` rebuilds the effects and `python3 art/source/star_voices.py --missing` records any voice line that does not exist yet (Pocket TTS). Run `godot --headless --path . --import` afterwards.

To edit the game, open `project.godot`. The original nursery scenario is available as `game/flight.tscn`. The main scene and native release open Last Light. See [asset and voice credits](licenses/ART-CREDITS.txt).
