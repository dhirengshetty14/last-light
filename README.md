# Last Light

At sundown on Saturn's Lamplight Harbor, five dockhands play for the right to switch on the beacon. Nell and Rafi attack the gold ring on the **right**. Pip, Morrow and Zip start in blue. Run the light into range, pass to make space, or dash through a rival to take possession. Every match lasts four minutes and the most goals wins. A tied score shares the light.

Stills from Free Agents on the current court: [the opening comic page](docs/free-agents-opening.jpg), [a broken promise](docs/free-agents-promises.jpg) and [the robots' walkout](docs/free-agents-union.jpg).

[Watch the full Rivals match on the expanded court](docs/last-light-rivals.mp4). That recording predates court version 9, the harbor and the comic panels. Both pilot seats in this recording use automated keyboard input. Play starts at 0:35. [Recorded scores, frame times and Gemini responses](docs/last-light-rivals.json).

**Showing it to someone?** [docs/DEMO.md](docs/DEMO.md) is the four-minute demo: what to do, what the audience will see and what to say.

**New to the project?** Read [CLAUDE.md](CLAUDE.md) first. It has the whole picture: what we are building and why, how the robots think, learn and are verified, a map of the code, the rules that keep replays and learning working, and where the project is heading. To get going:

```sh
godot --headless --path . --import   # once, with Godot 4.7.2
godot --path .                       # play
scripts/check.sh                     # every headless check, about 40 s
docker compose run --rm checks       # the same checks in Docker, no Godot install needed
```

The earlier compact court appears in [Pip’s beacon play in Open Crews](docs/harbor-relay.jpg). [Watch a full Open Crews match with live Gemini and game audio](docs/last-light-live-gemini.mp4). The recording shows the three robots’ service response times and uses automated inputs for Rafi and Nell. [Match measurements](docs/last-light-live-gemini.json).

## Play on this Mac

Double-click **Play Last Light.command** to start the native game and its local Bruin watcher, or run it from source with Godot 4.7.2. The game opens on its title: the name lights up letter by letter like harbor lamps. Press any key and Morrow tells the story as comic pages, then each of the five gets a page with their power. Escape skips straight on. **How to play** shows both players' keys side by side and lets you swap who plays Nell and who plays Rafi. **Choose your game** explains the three modes on cards; pick one and the match starts with a three-two-one countdown. Two players share a keyboard and screen.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | WASD | Arrow keys |
| GO: shoot inside the arc, otherwise dash or steal | Space | Enter |
| SHARE: pass, pay a promise, call for the star, or make a robot an offer | F | Slash |

Two buttons do everything. The bars at the bottom of the screen always say what each of your two buttons will do if you press it now, such as SHOOT!, STEAL, PAY PIP or SIGN ZIP. While you owe a robot a promise, SHARE passes to that robot. Otherwise a pass goes where you steer. The single-purpose keys still work: E shoots, Shift or Period dashes, R or Comma passes to a robot and Q or P makes an offer.

Tab opens the robot notebooks. Each entry shows the robot’s current goal and tactic, what it saw, and how many of its decisions have been graded this match. Escape pauses. The pause screen has separate switches for sound (effects, voices and the sea) and music, and the game remembers them for the next launch. M switches all audio off or back on. B reduces background movement. A single gamepad controls Player 2. With two connected pads, each controls a seat in connection order. Use the left stick, A for GO and X for SHARE. Right shoulder, Y and B keep their single purposes: dash, offer and pass to a robot.

**Rendering and sound.** The game uses Godot's Forward+ renderer (Metal on a Mac) with 4x anti-aliasing, soft shadows, ambient occlusion, bloom and haze, and its lights follow the sunset through the match. The sun sets behind the far rail, so a soft light from the camera side keeps faces lit. Floodlights at the corners come on as it gets dark; the two at the back hang under lamp drones that bob over the court with their rotors spinning. Titles and menus sit on the live scene with edged lettering and small plates behind fine print instead of dark bands across the screen. Every menu move, page turn, countdown, goal, splash and firework has a sound, and the sea plays under everything. On an Apple M5 a full four-minute match runs at about 120 frames a second (median 8.5 ms a frame, 99th percentile 12 ms); one frame in the benchmark match took 28 ms.

**The harbor.** Beyond the rail the dock looks out on a sea that mirrors the sky. The sun sets beside a ringed Saturn during the match and it is night by the whistle. The whales are humpbacks with long flippers, flukes and pleated throats, and they are simulated. A whale only swims where its nose points and turns it a little at a time, so its spine bends into each turn and arches over each dive. It comes up to breathe a few times, blows, then tips over and lifts its flukes for a deep dive. Sometimes it drives up from the deep and breaches, falls under gravity onto its side and throws up spray, a ring of foam and ripples that spread across the water. Two of them swim through the sky and now and then dive into the sea. It is the last night of summer and the harbor holds a carnival. Islands float over the water with candy-coloured trees on top and waterfalls pouring off their rims all the way down into the sea, throwing up spray, with a rainbow in the biggest while the sun is up. Their rock carries crystal veins that glow after dark. Jellyfish rise out of the sea and swim up into the sky, each squeeze of the bell a push, tentacles trailing; one of them is the size of a ship. Striped airships go round wide loops over the bay with banners flapping, sailing boats with bright sails heel round their marks, and a big wheel turns on a pier with its cars hanging level and its lights chasing round the rim. An icy moon and clouds of glowing gas come out in the sky as night falls. When a crew scores, the crystals, jellyfish, airship bulbs, sails and wheel all flash in that crew's colour. A lighthouse sweeps the water and lanterns rise. The stands behind the rail hold a mixed crowd of harbor folk in coats and hats and small hovering dock-bots. No two are placed, dressed or timed alike: they watch the star, turn to each other, wave, start a wave down the stands, and when a goal goes in each reacts in its own time while the other side slumps. Goals send up fireworks. When the robots walk out the harbor goes dark and the whales glow. B reduces all of this motion.

**The rings on the court.** The small ring under each player is their crew's colour. The white circle in the middle is the centre mark. The turning dashed ring around Morrow is his slow zone: carry the star inside it and you slow down.

**The comic.** The opening is told as comic pages: a caption box for the story, then a page for each of the five with their name, their own words in a speech balloon and their power. During a match, sound words land on the court (YOINK!, PAID!, CHEAT!, STRIKE!, GOAL!), a small panel with the speaker's face and a balloon shows every line a robot says, and the picture turns to print for the pause after a goal.

**The story.** When the sun drops behind Saturn, Lamplight Harbor goes dark and the whales follow one light home. The dock crews play for who lights it, and tonight is the last night anyone lights it by hand. The machines have been promised a turn for thirty winters. Tonight they are counting.

**Free Agents** makes Nell and Rafi rival captains. Nell attacks the gold ring on the right, Rafi the blue ring on the left, and the most goals in four minutes wins. Before kickoff each robot picks a captain from what it remembers and signs for a promise the court can check. Pip wants the next shot. Zip wants two passes. Morrow wants the next shot to come off a pass. A promise only runs down while that captain’s crew holds the star, and a captain with two promises pays them in order. Keep one and the robot trusts you more. Break one and it walks out to the other captain, or downs tools if it is the only robot you have, until you offer new terms and keep them. Once both captains have broken a promise, a robot calls a vote on the radio. If two of the three vote to walk out, the robots form their own crew, the harbor lights drop, and Nell and Rafi have to share the gold ring against them, first to two. F or Slash passes where you steer. R or Comma passes to the robot you owe. Q or P beside a robot offers its terms. The promises panel, the labels over each robot and the always-on harbor radio show every deal, reason and ballot. After a paid promise a robot listens to offers for ten seconds, then names new terms, so a captain can never coast. Each robot speaks its own terms, payments, walkouts and ballots in its own recorded voice. Trust carries across matches on this device.

**Rivals** keeps the two people on Gold against three autonomous machines. **Open Crews** moves play to the ring-shadow dock. Walk within two meters of a machine and offer it a jersey. Pip is willing to join early. Morrow helps a trailing team. Zip wants evidence that you pass. One defender always stays with Blue. Recruits can receive and return passes, turn down a call, and return to Blue after two ignored openings. Each robot remembers which pilot broke an agreement across matches on this device. A completed pass to the other pilot can repair trust when the robot sees the catch. Complete two consecutive passes to recharge every dash on your crew. Interceptions, a change of jersey and restarts break the sequence. The top-right bars show when each pilot can dash again. Sideline strips respond to each pass in the sequence, lamps count goals at both ends and the beacon calls an aurora across the gallery.

The court measures 22 meters between rings, a quarter longer and wider than before version 9. Since version 10 every mode is a four-minute match won on goals; earlier versions played two or three minutes, and Rivals and Open Crews ended at three goals. A star that misses can bounce off the end wall and settle behind a ring, farther out than anyone can stand or reach. Since version 11 the deck there tips back towards the court, so it rolls back within reach; before that it stayed there until the whistle. Since version 12 passes fly about a fifth slower (7 m/s; Zip's Express 9.3 m/s). A robot that gets the star also looks up for a random moment before it passes: 0.4 to 0.85 s after a catch, a little less before a shot, and always inside the window in which nobody can take the star. Before that, robots usually passed on the tick they caught the star (a median of 0.02 s in live play), so their passing was a blur.

**Fair play for people (court 14).** A robot now winds up for 0.33 to 0.6 s before it dashes at a person carrying the star, so you can see it coming. A person who gets the star cannot be robbed for 1.4 s (1.7 s after catching a pass); before it was 0.65 s, and three robots dashed the moment it ended. In live play the robots also ease off while they lead the people: for each goal of lead, up to four, they run 5.5% slower and wind up 8 ticks longer. Launch with `-- --full-strength` to turn that off. Training and evaluations never ease off. Against casual scripted pilots, over eight matches, the average score went from 0.9 against 30.9 for the robots on court 13 to 7.2 against 10.0 with fair play and easing. Strong dash-steal pilots still win, 20.1 to 16.6. The painted semicircles mark shooting range. The top-center scoreboard shows both teams, the game clock and the target score. The final card breaks down goals, shots, completed passes and takeaways by team. A dotted arc appears when a human can shoot. Long throws fall short and the ball stays live. Throws lead a running teammate using the expected flight time. Defenders can intercept the ball anywhere along its path. Every character has one power. Nell’s Ferry Run is the longest dash and the only one that protects the star. Rafi’s Long Shot scores from half a meter farther out. Pip’s Getaway is a burst of speed after every steal. Morrow’s Anchor slows any opponent carrying the star inside the ring painted around him. Zip’s Express passes fly a third faster. Beyond those, Rafi has a wider catch, Pip has a longer reach when stripping the ball, Morrow a deep defensive position and wide catch radius, and Zip the quickest recovery between dashes. When a robot scores after unaided machine possession, the far beacon brings a whale across the gallery and widens both hoops for ten seconds.

## Simulation and learning

The same GDScript court runs the rendered match, training episodes and Harbor verifier. It advances at 60 physics ticks per second, with capped acceleration, braking, contact separation, dash cooldowns, swept hoop crossings, gravity, rebounds and handoffs. The render loop interpolates player and ball positions. The controls, local policy, physics, deterministic verifiers, music and recorded voice clips run on the Mac. The optional Gemini connection supplies tactical suggestions in the background.

Pip, Morrow and Zip each have a separate local contextual bandit, scouting notebook and seeded random generator. Pip watches nearby play within 3.2 meters, Morrow watches up to 5.1 meters and Zip up to 4 meters. A pass addressed to a robot is always visible to that receiver. It can pressure, screen, cut a pass, lead a loose ball, offer an outlet, advance, flank, carry, pass, evade or finish. Its context includes possession, range, the observed carrier's shot/pass tendencies and lane. Movement skills and alliance terms are game rules. The policy chooses from legal tactics, reacts to possession changes and calls, and reassesses a continuing opportunity after 35 ticks. Throws settle when the court has an outcome. Historical estimates supply a bounded prior. Recent outcomes can change the next preference within one match. Aggregate preferences carry across matches and launches. Observed shot counts, passing tendencies, running lanes and team membership start fresh each match. Each robot saves its learned estimates and its relationship with Nell and Rafi separately. The relationship follows the character through a player swap.

For a reaction, the simulator checks the witnessed opportunity, legal choice, approach, physical execution and world consequence. It assigns weights of 0.10, 0.10, 0.20, 0.25 and 0.35. Only 1.00 is a full pass. Every throw by a human or robot also has its own five-check outcome. Points are recorded as integer hundredths. The policy receives its observation and legal choices. A separate update consumes the verified grade once per decision. The public ledger shows choices and reasons. These checks and replay tests cover known failure modes. Reward design can still favor an unintended strategy.

The checkpoint comes from 120 simulated matches against four scripted human styles. Frozen comparisons use 32 other seeded matches, common inputs and identical exploration rates. The evaluation file includes win counts, graded reactions, per-action failures, and timing for the chooser and learner callbacks. It was retrained on court 13 and has not been retrained for court 14: the 120 training matches produced 48,402 verified tactical updates for Pip, 48,380 for Morrow and 48,484 for Zip. In the 32 held-out matches the trained robots scored 946 goals against 810 for the starting policy and won 32 matches against 31, and the fraction of fully verified tactics was 29.2% against 28.3%. That is one run, and its spread has not been measured. The same comparison on court 9 showed no gain: 79 goals against 84, and 21.3% against 21.4%. Blue won 21 of 21 trained Rivals fixtures against the four scripted styles. The checkpoint from the court 9 training is kept as [learning/star_checkpoint_court9.json](learning/star_checkpoint_court9.json) for comparisons. The 0.4 compact-court build has a separate historical rendering benchmark. [Frame-time sample](docs/last-light-performance.json).

**Outcome checks that can teach (court 13).** Bruin's failure tables over 33 recorded matches (9,491 graded decisions) showed where the robots were failing. Defending, chasing a loose star and getting open passed all five checks 1% to 21% of the time, against 84% to 90% for carrying, passing and finishing. Nearly all of those failures were the outcome check, and it failed whatever the robot chose:

- Defending only worked if the star was won within the decision's 0.6 seconds.
- Chasing a loose star only worked if that robot ended with it.
- Supporting only worked if the robot reached a spot that had since moved with the carrier.

A check that fails 96% of the time cannot tell a good decision from a bad one, which is why training had not helped. Since version 13:

- **Defending** works if the crew wins the star, or the carrier is held up: over the decision they make under 70% of the ground a free run at the ring would make.
- **Chasing** works if the crew gets the star, or this robot is the nearest player to it.
- **Supporting** works if this robot gets the star, or ends open: a pass away, with nobody in the lane from the carrier and nobody marking it.
- In those three tasks the approach and execution checks follow the play. The robot is graded against where its target is now, not the spot it set off for.

Those situations carry `/t` at the end of their name, so grades given under the old checks never mix with the new ones, and Bruin compares a match only with matches graded the same way. Against the dash-steal pilots below, getting open now passes about half the time (2% to 8% before), and pressing the carrier holds them up 19% of the time against 7% to 9% for cutting or screening. So the checks now separate one move from another.

**Learning not to be robbed (court 12).** In live play on court 10, pilots took the star off a robot 42 times in six matches, 35 of them from Zip, and 37 during a move a Gemini playbook had picked, usually "flank". The robots did not stop, for three reasons. A playbook move was applied unless the robot's recent record was strongly against it. A robot's situation said nothing about who could reach it, so being robbed was averaged in with open play. And it had no move that answers a dash.

Since version 12:

- **Pressure.** A robot with the star knows how far each rival's dash reaches at that moment: steal reach plus 2.7 m for Nell's Ferry Run when it is ready. Each steal adds 0.3 m to the room it gives that pilot, up to 1.2 m. A match's steals count in full in the next match and half as much in each match after that, so a pilot who stops robbing is forgiven in time.
- **Its own situation.** When a rival is within that reach (hot) or 1.3 m of it (warm), the robot decides again in a situation of its own, named by the danger and the rival, for example `carry/hot/nell`. There it can also evade: run away from the rival while still edging towards the ring. If it reads a dash in time (about three in five) it sidesteps with its own dash.
- **Passing.** Passes go to the teammate with the clearest lane.
- **Choosing.** A robot samples its moves in proportion to how well each has done instead of always taking its top one. A move that has done 0.1 worse is picked about a tenth as often, and every draw comes from the robot's own seeded generator, so replays hold. A different random offset on its running line keeps the same tactic from running the same route twice.
- **Gemini is advice.** A playbook move gets a small lift in that weighing, and the robot's record of graded outcomes can outweigh it.
- **Robots talk to each other (court 14).** A robot robbed twice by the same player warns its crewmates, who then give that player 0.15 m more room without having been robbed themselves. A robot that changes a habit tells them the tip (*Crew: near Rafi, pass early. Going wide got me robbed.*), and they weigh the tipped move a little higher and the dropped one a little lower in the same situation. A crewmate that acts on a tip says whose it was (*Zip said: near Rafi, pass early. Doing that.*). Each message is a balloon, a line on the harbor radio naming who it was for, and a `talk` event in the recording. In a test match with aggressive pilots the robots exchanged 15 messages.
- **Lessons out loud.** When a move that got a robot robbed in some situation now weighs less than the one it picks instead, and its graded record there is mostly failures, it says so once in a balloon: *Rafi robbed me going wide. I pass early now.* The line names the player who took the star. The radio log counts repeat steals, and Tab shows how often each pilot has robbed each robot and how many lessons it has learned.

[The steal test](learning/steal_eval.gd) checks this with code. Two scripted pilots play the habit seen in live play: run at the robot with the star, dash in as soon as the dash can reach, carry to the ring and shoot. Each series is three Rivals matches in a row with the robots keeping what they learned, on the same seeds for four kinds of robot: learning robots as shipped, the same robots with learning switched off, the court 12 robots (the old outcome checks and the checkpoint trained on court 9) and the court 11 robots. No robots ease off in this test. [Results](learning/steal_eval.json), 16 series:

| Robots | Steals, match 1 | Steals, match 3 | Robot goals, match 3 | Pilot goals, match 3 | Verifier score |
| --- | --- | --- | --- | --- | --- |
| Learning (court 14) | 9.8 ± 0.9 | 10.0 ± 0.8 | 16.7 | 19.2 | 0.26 |
| Frozen (court 14, no learning) | 7.6 ± 1.0 | 8.8 ± 0.9 | 16.9 | 19.2 | 0.25 |
| Court 12 | 13.8 ± 0.8 | 10.6 ± 1.2 | 17.1 | 18.3 | 0.44 |
| Court 11 | 15.7 ± 1.6 | 13.0 ± 1.1 | 18.0 | 18.5 | 0.28 |

The court 14 robots are robbed less from the first match than any earlier ones, because the retrained checkpoint already holds what the court 12 robots had to learn in play. Learning during these three matches adds nothing measurable on top: learning minus frozen is +2.2 ± 1.1 steals in the first match and +1.3 ± 1.2 in the third, and the steal verifier scores both the same. Goals stay level for every kind of robot (about 17 for the robots, 18 to 19 for the pilots). So against this style of pilot the newer courts have made the robots harder to rob, but not winners.

The verifier gives each series 0.4 if steals in match 3 are at most 80% of match 1, 0.4 if steals in the last two minutes of match 1 are at most 80% of the first two, and 0.2 if robots under pressure pick a move that got them robbed less often after half time. It is a strict, noisy score, and the counts above are the stronger evidence. The evade move added in version 12 passes the approach check if the gap to the rival grew or the robot got out of reach, and is a full success only if the robot still holds the star and was not robbed on the way.

**Learning who to trust.** In Free Agents each robot also keeps its own record of five kinds of social choice: which captain to sign with, what to do about a broken promise (let it go, stop work or leave), whether to take a rival captain's offer, whether to sign again with a captain who wronged it, and how to vote. A choice is graded by the next promise made to that robot. Kept is 100, broken is 0, and a choice that saw no further promise gets 50. The grade goes into the robot's record the moment the promise settles, during the match, and the radio log says so. Winning the showdown after a walkout earns no credit. A robot leaves its written rule for a choice only when its own record in the same situation says, beyond luck, that another choice has done better. The situation is what a spectator could see: the robot's ledger of promises kept and broken by each captain, whether the match is past half time, and one fact for that kind of choice. A robot with no history of either captain signs by the written rule. Launch with `-- --written-rules` to switch this off.

The shipped record is [learning/social_checkpoint.json](learning/social_checkpoint.json). It comes from 2,000 practice series of three matches against scripted captains whose habits with promises are hidden from the robots: always pays, never pays, pays only in the first half, pays one robot only, and pays about half the time. Practice entries are scaled down to 40 tries so that results from live play carry weight. Even so, where the record allows a habit to change at all, it takes about twenty contrary results in the same situation. Within one match a robot adapts through its memory of the captains, not by relearning.

[The held-out test](learning/social_eval.gd) plays 60 more series on seeds never practised. Half include a kind of captain never practised against. A verifier that knows the captains' habits checks every choice as it is made and adds three checks on how each match went, for a score from 0 to 1. [Results on the version 9 court](learning/social_eval.json): random choices 0.557, the written rules 0.649, the trained robots 0.655. Series by series, trained minus written is +0.006 with a standard error of 0.012, so training has not beaten the written rules. Both are well clear of random (+0.097, standard error 0.020). The trained robots overrode a written rule in 261 of 2,769 choices. The record was practised on the earlier, smaller court and has not been retrained for this one, and these results predate the four-minute match of version 10. One learned choice takes about 6 microseconds.

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

Players launch the game, choose a mode and take the court. Both modes work offline with local tactics and recorded character voices. On a Mac configured by the host, even a double-click on the app starts a private loopback service. Pip, Morrow and Zip each call `gemini-3.1-flash-lite` with their own observation, goal and recent history. Every eight seconds each robot can request a small playbook while local movement, input and sound continue. The game checks the reply against the current team and legal moves. Since court version 12 the playbook is advice. Its move gets a small lift in the robot's own weighing, and the robot's graded record can outweigh it. Before version 12 a playbook move was applied unless the robot's recent record was strongly against it. In live play that meant about three robot decisions in five came from Gemini, and it kept sending Zip wide past the pilots. Each request now also tells the model how many times Nell and Rafi have robbed that robot, and the model may propose the new evade move. A robot also only spends a model call when it is struggling: it gets one playbook at kickoff, then asks again once it has been robbed twice or after ten decisions in a row that failed a check, and never more than once in eight seconds. Before, every robot asked every eight seconds whatever was happening, about 90 calls a match, and across 33 recorded matches the decisions that used Gemini's move scored 0.58 against 0.57 for the robots' own. Against the dash-steal pilots the new rule makes about 30 calls a match. A timeout or provider error leaves the robots playing. Tab opens the public tactical notebook.

**Demo host, once per macOS account.** From this checkout run `python3 host/radio.py --configure` and enter the publisher's Gemini key at the hidden prompt. The helper saves it in a mode-0600 file under `~/Library/Application Support/Last Light Host/`. Relaunch the app. An inherited `GEMINI_API_KEY` also works for a developer launch. For a Vertex AI express key, append `--provider vertex` to the configure command. The provider choice is saved on the host alongside the key. Each game starts its helper on a dynamically assigned loopback port and stops it on exit. This path uses the Mac's Python 3 installation. Plain downloads on other Macs play offline until the publisher supplies a shared service.

**Shared hosting is prepared.** Build the included container with `docker build -t last-light-radio host`. Run it behind an HTTPS endpoint, bind its `PORT` to the host platform and supply `GEMINI_API_KEY` as a server secret. Put just its HTTPS origin in the `last_light/radio/url` project setting before export. For development, `LAST_LIGHT_RADIO_URL` overrides that setting. The fixed `POST /v1/playbook` route accepts bounded court observations. The host chooses the prompt, model and schema and returns validated moves, public reasons and token counts. Each service process caps calls at six concurrent, 72 per minute and 900 per rolling hour. A shared deployment needs its own project-wide spending limit. This build ships with an empty shared URL.

## Bruin and replay

**Live robot report.** Run `python3 telemetry/dashboard.py --open` (the Mac launcher starts it too) and keep http://127.0.0.1:8960/ beside the game. It shows, within a couple of seconds of play:

- the seven tasks and which ones each robot is failing (under 25% of at least ten decisions fully verified);
- the moves that cost the most verifier score, and which of the five checks each one misses;
- fully verified decisions match by match;
- model calls, their wait and tokens, and what the robots did with the advice;
- what the robots told each other, and the lessons they said out loud.

Bruin builds all of it. The watcher stages the match logs, re-parsing only the live match, and runs the pipeline: 16 tables and 19 quality checks in about 0.7 s over 33 matches. The last asset, `flight.dashboard_feed`, writes the whole report as one JSON file. The page only reads that file, so a refresh costs no query, and the server listens on this machine only. The tables behind it are `flight.robot_decisions` (every graded decision with its task, situation and the check it broke at), `flight.task_scores`, `flight.robot_failure_modes` and `flight.robot_talk` (every message between robots, checked to be robot to robot). A failed quality check stops the pipeline, and so the report, until the bad log is removed.

**Bruin Cloud.** The same pipeline also runs in Bruin Cloud, on a copy of the match data in MotherDuck, so the team can see the runs, the quality checks and the tables, and ask Bruin's agents about them. The live report stays on the game's Mac because it has to update within seconds. A pipeline variable chooses the source: `source="local"` (watch.py) reads the staged logs, and the default, `"cloud"`, reads `raw.match_events` in MotherDuck. In the cloud the report is kept as the table `flight.robot_report`. The first cloud run, over 86 matches (44,651 events), passed all 16 assets and all 19 quality checks in 3 minutes 44 seconds. To set it up once and then upload matches:

```sh
bruin cloud login --global                 # browser sign-in
python3 telemetry/cloud.py configure       # MotherDuck token at a hidden prompt
python3 telemetry/cloud.py connect         # after installing the Bruin GitHub App on the repository
python3 telemetry/cloud.py sync            # upload the recorded matches and start a cloud run
python3 telemetry/cloud.py status
```

The token is kept in `telemetry/local/cloud.bruin.yml` (gitignored, readable by you only) and in Bruin Cloud as the `nursery` connection. `sync` uploads the match logs only: game events, robot decisions and grades, robot talk, and Gemini's requests and replies.

The native launcher starts the watcher if Bruin is installed. Each match writes a locally buffered JSONL trajectory, including a four-Hz court trace, ownership, releases, social changes, tactic decisions, outcomes, verifier flags and scores. Bruin refreshes a DuckDB database from sealed lines approximately every two seconds. Its checks include unique sequence IDs, bounded grading, one resolved learning example per decision, and machine attribution for beacon events. For connected matches, `flight.model_calls` reports the scout snapshot, requested and served model, request status, measured latency, token counts and returned playbook. `flight.agent_decisions` links each decision to its public reason, proposal, whether it was applied, overridden or illegal, most recent transport state and eventual verifier checks. The final whistle shows completed passes, steals, machine-lit beacons and Open Crews relays. The Bruin scoreboard groups those events by match and records the mode and each crew’s relay total. Local verified response summaries feed back into the next launch. The release stores data under the existing `Godot/app_userdata/This Side Up` directory so existing runs stay readable.

```sh
python3 telemetry/watch.py --watch
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.court_scoreboard'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select * from flight.failure_modes'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select robot,situation,move,attempts,full_rate,breaks_at from flight.robot_failure_modes order by lost_score desc limit 10'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select match_number,robot,task,attempts,full_rate,failing from flight.task_scores order by match_number desc limit 21'
bruin query --config-file telemetry/local/bruin.yml -c nursery -q 'select robot,tick,tactic,public_reason,decision_source,score from flight.agent_decisions order by run desc,tick desc limit 12'
```

Recordings made before court version 9 replay on the earlier, smaller court, version 9 recordings replay with their shorter clock, recordings before version 11 replay without the roll-back behind the rings, recordings before version 13 replay with the earlier outcome checks, recordings before version 14 replay without the wind-up and without robot talk, and the replay tool picks the court from the recording's header. The [recorded Gold win](docs/match-87.jsonl) includes the starting policy and both pilots’ input changes. Replay it with `godot --headless --path . -s tools/replay_court.gd -- docs/match-87.jsonl`. The replay checks every recorded event against a fresh simulation.

For seeded runs, launch the app with `-- --seed=87`. Training and automated playtests isolate fixture logs from live player trajectories. Reproduce the checks with Godot 4.7.2. The court playtest uses both keyboard seats and the regular opening, menu, pause and finish flow.

```sh
godot --headless --path . -s tests/star_match_test.gd
godot --headless --path . -s tests/free_agents_test.gd
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --written-rules --seed=87
godot --headless --fixed-fps 60 --path . -s tests/court_playtest.gd -- --court-playtest --free --liars --written-rules --seed=87
godot --headless --path . -s learning/social_eval.gd -- --table=learning/social_checkpoint.json
godot --headless --path . -s learning/steal_eval.gd -- --series=16
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
