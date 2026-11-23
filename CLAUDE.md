# Last Light: full project context

Read this first. It is the shared context for every teammate and every Claude Code session on this
project. It covers what we are building, how the game and its robots work, how the RL environment and
its verifiers are built, how to run and test everything, the rules that keep it working, and where it
is heading. When you change something important, update this file in the same commit.

The player-facing description, with every rule and number, is in [README.md](README.md). This file is
the map behind it.

---

## 1. What we are building

**Last Light** is a 3D local-multiplayer game in Godot 4.7.2, built for the *Multiplayer AI*
hackathon (Monday 23 November 2026), **Track 2: Co-op Multiplayer**. Two people share one keyboard
(or gamepads) and play four-minute matches with three AI robots that ally, trade, compete and betray.

The robots are agents in an RL environment. Every decision a robot makes is checked by code and scored
from 0 to 1, and that score changes its next decision, both during the match and in later matches.

The track brief as we understand it, and where the game meets it:

| Requirement | Where it is in the game |
| --- | --- |
| 2 humans and 3 agents | Nell and Rafi (the players); Pip, Morrow and Zip (the robots) |
| Agents ally, trade, compete and betray | **Free Agents**: robots sign with a captain for a promise, walk out when it is broken, and vote to form their own crew. **Open Crews**: robots take jerseys and can leave you. **Rivals**: robots against both players. |
| A major world event caused by agents alone | **Beacon**: when the robots score after a robot-only possession chain, a whale crosses the sky and both hoops widen for 10 s. **Union**: in Free Agents the robots walk out together, the harbor goes dark, and it becomes humans against robots. |
| Bruin (mandatory) | Every match writes a JSONL trajectory. `telemetry/` loads it into DuckDB with Bruin and runs data checks. |
| Bonus: ML or trained agents | Each robot has its own learner (a contextual bandit) trained on simulated matches and updated live from verified grades, plus optional Gemini playbooks. |
| Bonus: voice | Recorded character voices (Kyutai Pocket TTS) for terms, payments, walkouts and votes |
| Bonus: 3D | Forward+ renderer; a living harbor and floating carnival around the court |

**History.** The project started on 2026-11-21 as *This Side Up*, an orbital nursery rescue whose code
is still in `game/flight*.gd`, and became Last Light the same day. `git log` has the whole story.

---

## 2. The game in one minute

At sundown on Saturn's Lamplight Harbor, five dockhands play for the right to switch on the beacon. The
ball is **the star** (also called the light). Score by throwing it through the other crew's ring.
Every mode lasts **4 minutes**, and the most goals wins.

### The five

| Seat | Who | Power | Also |
| --- | --- | --- | --- |
| 0 | **Nell** (player 1) | Ferry Run: the longest dash, and the only one that protects the star | |
| 1 | **Rafi** (player 2) | Long Shot: scores from 0.5 m farther out | Wider catch |
| 2 | **Pip** (robot) | Getaway: a burst of speed after every steal | Longer reach when stripping the ball |
| 3 | **Morrow** (robot) | Anchor: slows any rival carrying the star inside the ring painted around him | Deep defence, wide catch |
| 4 | **Zip** (robot) | Express: passes fly a third faster | Quickest recovery between dashes |

Seat numbers are used everywhere in the code: `pos[i]`, `team[i]`, `agents[i - 2]` for robots.

### Modes

- **Rivals.** Nell and Rafi (Gold) attack the ring on the right; Pip, Morrow and Zip (Blue) defend it.
- **Open Crews.** On the ring-shadow dock you can recruit robots. Walk within 2 m of one and offer it
  a jersey. Pip joins early, Morrow helps a trailing team, and Zip wants proof that you pass. One
  defender always stays Blue. A recruit goes back to Blue after you ignore it twice. Two passes in a
  row recharge every dash on your crew.
- **Free Agents.** Nell and Rafi are rival captains: Nell attacks right, Rafi left. Before kickoff each
  robot signs with a captain for a promise the court can check:
  - Pip wants the next shot.
  - Zip wants two passes.
  - Morrow wants the next shot to come off a pass.

  A promise only runs down while that captain's crew has the star. Keep it and the robot trusts you
  more. Break it and the robot walks out to the other captain, or downs tools if it is your only
  robot. Once both captains have broken a promise, a robot calls a vote. If two of three vote yes, the
  robots form their own crew, the lights drop, and Nell and Rafi share the gold ring against them,
  first to two. Trust carries across matches.

### Controls (two buttons each)

| Action | Player 1 | Player 2 | Gamepad |
| --- | --- | --- | --- |
| Move | WASD | Arrow keys | Left stick |
| **GO**: shoot inside the arc, otherwise dash or steal | Space | Enter | A |
| **SHARE**: pass, pay a promise, call for the star, make an offer | F | Slash | X |

The bars at the bottom always say what each button will do right now. Other keys:

- Tab: robot notebooks (goal, tactic, what the robot saw, decisions graded, who robbed it, lessons)
- Escape: pause, with separate Sound and Music switches
- M: mute everything
- B: reduce background motion

The single-purpose keys still work: E shoots, Shift or Period dashes, R or Comma passes to a robot,
and Q or P makes an offer.

### On screen

- Scoreboard at the top.
- The harbor radio log: every robot line, deal, reason and lesson.
- Comic balloons and sound words: YOINK!, JUKE!, LEARNED!, GOAL!
- A final card with goals, shots, passes and takeaways.

The intro is comic pages that Escape skips. Then come *How to play* and *Choose your game*.

---

## 3. Get it running

### Native (to play)

1. Install **Godot 4.7.2**, the standard build, not .NET. Get it from the
   [official release page](https://github.com/godotengine/godot/releases/tag/4.7.2-stable). The
   version matters: the tests and replays are pinned to 4.7.2.
2. Python 3 (standard library only) is needed for the Gemini host and its test.
3. Import the assets once (a minute or two):
   `godot --headless --path . --import`
4. Play with `godot --path .`. On a Mac the executable is
   `Godot.app/Contents/MacOS/Godot`. Or open `project.godot` in the editor and press F5. On a Mac,
   `Play Last Light.command` also starts the Bruin watcher.
5. Before you push, run `scripts/check.sh` (about 40 s), or `scripts/check.sh --full` to add the six
   full-game playtests (several minutes). Set `GODOT=/path/to/godot` if Godot is not on your PATH.

If `exports/Last Light.app` exists (it is gitignored), the Mac launcher runs that packaged build
instead of the source. That build is stale, so delete it or run from source.

### Docker (headless: tests, evaluations, Gemini host)

A container has no display or GPU, so Docker is for everything except playing.

```sh
docker compose run --rm checks            # every headless check (same as scripts/check.sh)
docker compose run --rm checks --full     # plus the six full-game playtests
docker compose run --rm steal-eval        # the steal test; writes learning/steal_eval.json
docker compose up radio                   # Gemini host on 127.0.0.1:8947 (needs GEMINI_API_KEY in your shell)
```

The root `Dockerfile` installs the official Godot 4.7.2 Linux build with a SHA-256 check, imports the
project and runs `scripts/check.sh`. `tasks/Dockerfile` builds the image for the Harbor tasks, and
`host/Dockerfile` builds the Gemini host.

### Gemini (optional)

Without Gemini the robots play on their own learners. With it, each robot also gets a small playbook
every 8 seconds, as advice.

- **Use your own key. Never commit a key, paste it into a chat, or put it in a file inside this repo.**
- **Mac.** Run `python3 host/radio.py --configure` and enter the key at the hidden prompt. It is saved
  in a mode-0600 file under `~/Library/Application Support/Last Light Host/`. Add
  `--provider vertex` for a Vertex AI express key. Alternatively, `export GEMINI_API_KEY=...` before
  launching. On launch the game starts its own private loopback host.
- **Windows or Linux.** The game only starts the host itself on a Mac. Run it yourself, with either
  `GEMINI_API_KEY=... python3 host/radio.py` or `docker compose up radio`. Then launch with
  `LAST_LIGHT_RADIO_URL=http://127.0.0.1:8947`.
- The model is `gemini-3.1-flash-lite`. The host caps calls at 6 concurrent, 72 a minute and 900 an
  hour.
- A shared hosted service is prepared (`host/Dockerfile`, the `last_light/radio/url` project setting)
  but deliberately **not deployed**. Ask Dhiren before deploying any shared service.

### Bruin (telemetry) and the live robot report

Install the Bruin CLI. Then run this beside the game (the Mac launcher starts it too):

```sh
python3 telemetry/dashboard.py --open     # http://127.0.0.1:8960/
```

It starts the watcher (`telemetry/watch.py --watch`), which stages the match logs into
`telemetry/local/` (gitignored) and runs the Bruin pipeline in `telemetry/assets/flight/*.sql`: 16
tables and 19 quality checks in about 0.7 s. The page shows, within a couple of seconds of play:

- which of the seven tasks each robot is failing;
- the moves that cost the most verifier score and the check each one misses;
- fully verified decisions match by match;
- model calls, and what the robots did with the advice;
- what the robots told each other, and the lessons they said out loud.

The last Bruin asset, `flight.dashboard_feed`, writes the whole report as one JSON file. The page
only reads that file, so a refresh costs no query.

If a Bruin quality check fails (for example a log that does not start at sequence 1), the pipeline
stops and the report stops updating until that log is removed. Check `telemetry/local/live.log`.

### Bruin Cloud

The same pipeline runs in Bruin Cloud (project `last-light`, linked to this repository through the
Bruin GitHub App) against MotherDuck. The pipeline variable `source` picks where events come from:
`"local"` reads `telemetry/local/events.ndjson` (watch.py passes it), the default `"cloud"` reads
`raw.match_events` in MotherDuck. In the cloud, `flight.dashboard_feed` writes the table
`flight.robot_report` instead of the local JSON file.

`telemetry/cloud.py` does the rest: `configure` (MotherDuck token at a hidden prompt, stored
gitignored and as the Bruin Cloud `nursery` connection), `connect` (link the repository), `sync`
(upload every recorded match and trigger a cloud run) and `status`. Each teammate needs their own
`bruin cloud login --global`; the MotherDuck token belongs to whoever set it up.

Any asset you add must work in both modes: never read a local file outside the `source == "local"`
branch.

### Coach Bruin, BAND and Runware

- **Coach Bruin** (`telemetry/cloud.py coach`): the team's Bruin Cloud agent (connection set
  `last-light` gives it the MotherDuck tables) reads `flight.robot_failure_modes` and returns
  structured notes: robot, phase, move to try, move to drop, advice. They are saved to
  `user://bruin-coach.json`. The game loads them at launch (live sessions only), calls
  `set_bruin_coach` after the draft (a `coach_note` event per robot), and `plan()` gives the tried
  move +`COACH_LIFT` (0.04) and the dropped one -0.04. The notes go in the match header
  (`bruin_coach`), and the replay tool applies them at the same point.
- **BAND** (`telemetry/band.py`): a bridge that reads the live match log and posts robot `talk`,
  `lesson`, `coach_note` and vote events into a BAND room as the speaking robot, @mentioning the
  listeners, and answers people who @mention a robot. Keys in `telemetry/local/band.json`.
- **Runware** (`telemetry/panels.py`): after each match's `final` event, one FLUX.1 [schnell]
  picture of the match's big moment, saved to `user://panels/<run>.png` with a caption. The final
  screen polls for it for 30 s. Key in `telemetry/local/runware.key`.
- `telemetry/dashboard.py` starts the BAND bridge and the panel maker when their config files exist.
  None of the three is ever called from inside the game loop.

### Where a running game saves things

`user://` is `~/Library/Application Support/Godot/app_userdata/This Side Up/` on a Mac,
`~/.local/share/Godot/app_userdata/This Side Up/` on Linux, and
`%APPDATA%\Godot\app_userdata\This Side Up\` on Windows.

| File | What it is |
| --- | --- |
| `flights/*.jsonl` | Every live match, replayable |
| `court-captures/*.jsonl` | Matches from tests, playtests and captures |
| `last-light-policy.json` | **The robots' memory**: learned estimates and relationships, saved after each live match |
| `verified-responses.json` | Extra verified learning examples loaded at launch |
| `audio.cfg` | Sound and music switches |

---

## 4. Code map

### `game/`: the game

| File | Lines | Role |
| --- | --- | --- |
| `star_match.gd` | ~2,100 | **The authoritative court.** A 60 Hz simulation of players, star physics, passes, shots, dashes and steals; the robots' brains (`plan`, `aim`, `brain`, `settle`); the verifiers; Free Agents promises, walkouts and the union. Headless, with no rendering. |
| `star_agent.gd` | ~260 | One robot: its policy, scouting notebook, reputation and ledger with each pilot, robbed memory and lessons, and the Gemini playbook it holds |
| `last_light.gd` | ~2,000 | The scene: input, camera, drawing the players and star, sounds and voices, match flow (title, story, menus, match, end), recording headers and footers, and saving robot memory |
| `star_ui.gd` | ~530 | In-match HUD: button bars, scoreboard, Tab notebooks, promises panel, pause menu |
| `start_screens.gd` | ~730 | Title, How to play, mode cards |
| `front_end.gd` | ~220 | Menu plumbing (buttons, focus, shades) |
| `comics.gd` | ~550 | Comic pages, sound words and speech balloons |
| `easy_controls.gd` | ~95 | The two-button scheme: what GO and SHARE mean right now |
| `gemini_coach.gd` | ~190 | One asynchronous HTTP channel per robot to the host; checks replies |
| `radio_host.gd` | ~60 | Finds or starts the local Gemini host |
| `harbor_world.gd` | ~1,500 | Sky, Saturn, mirror sea, simulated whales, lighthouse, crowd |
| `sky_carnival.gd` | ~1,000 | Floating islands, waterfalls, jellyfish, airships, sailboats, big wheel |
| `room_art.gd`, `court_lights.gd`, `crew_visual.gd`, `dock_life.gd`, `hud.gd` | | Stage, lights and cast visuals |
| `flight*.gd`, `cargo_body.gd`, `contracts.gd`, `radio.gd` | | The original *This Side Up* nursery game (`game/flight.tscn`); `flight_recorder.gd` is the shared JSONL writer |

### `learning/`: learners, training and evaluations

| File | Role |
| --- | --- |
| `response_policy.gd` | Base learner: an estimates table `context/move -> [tries, full passes, points]`, exploration and checkpoint loading |
| `star_policy.gd` | Ball-play policy: `choose` (top move), `choose_sampled` (version 12, samples moves), `choose_v2` (old recordings), and `observe`, which updates the long-term estimates and fast recent evidence |
| `star_train.gd` | Trains `star_checkpoint.json` from 120 simulated matches against four scripted human styles and writes `star_eval.json`. `star_checkpoint_court9.json` is the earlier checkpoint, kept for comparisons. |
| `captains.gd` | Scripted Free Agents captains: honest, liar, first half only, favourite robot, coin flip |
| `social_train.gd`, `social_eval.gd` | Practice and held-out test for the robots' social choices; `social_checkpoint.json` and `social_eval.json` hold the results |
| `steal_eval.gd` | Do robots stop handing the star to pilots who keep robbing them? Four kinds of robot on the same seeds. Results are in `steal_eval.json`. |
| `train.gd`, `checkpoint.json`, `evaluation.json` | The original nursery game's learner |

### Other folders

| Path | Role |
| --- | --- |
| `tools/replay_court.gd` | Re-simulates a recording and checks every event; maps `court_version` to court flags |
| `tools/court_rules_v5.gd` | Frozen version 5 court for the oldest recordings |
| `tests/star_match_test.gd` | Court rules, robots, pace, pressure, lessons, determinism |
| `tests/free_agents_test.gd` | Promises, walkouts, the union vote, social learning, two-button controls |
| `tests/gemini_court.gd`, `tests/radio_host_test.py` | Gemini turns and host, with no network |
| `tests/court_playtest.gd` | Plays both keyboard seats through the real scene: menus, pause, goals |
| `tasks/` | Harbor-format tasks (`ring-window`, `catch-window`, `broken-promise`), each with `instruction.md`, `task.toml`, `solution/solve.sh` and `tests/test.sh`. Graders are in `tasks/*.gd`, and `tasks/check-local.sh` runs them in Docker with no network. |
| `host/radio.py` | The Gemini playbook service. Standard library only; it alone holds the key. |
| `telemetry/` | Bruin pipeline: `watch.py`, `pipeline.yml`, and the tables and checks in `assets/flight/*.sql`. The report's tables are `robot_decisions`, `task_scores`, `robot_failure_modes`, `robot_talk` and `dashboard_feed`. |
| `telemetry/dashboard.py`, `dashboard.html` | The live robot report: a local server and one self-contained page |
| `art/source/` | Offline scripts that built models, textures, music, sound effects and voices |
| `assets/` | Models (glb), audio, fonts, textures |
| `docs/` | Screenshots, videos, and recorded matches (`match-87.jsonl` is the replay fixture) |
| `scripts/check.sh`, `Dockerfile`, `docker-compose.yml` | One-command checks and Docker |

---

## 5. How the simulation works (`game/star_match.gd`)

- **One tick is `step(commands, packets)`**, called 60 times a second.
  - `commands` holds one dictionary per seat: `move` (a Vector2) plus button flags (`shoot`, `pass`,
    `dash`, `invite`, `ally_pass`).
  - `packets` are Gemini replies, applied only at tick boundaries.
- **Coordinates.**
  - Rings at x = ±11 m (22 m apart).
  - Players move in a `Vector2(x, y)` inside bounds (±10.35, ±4.65).
  - The star is a `Vector3(x, height, z)`.
  - Shooting range is 3.55 m.
  - Gravity is 10.8.
- **Possession.**
  - `owner` is a seat, or -1 while the star is in flight or loose.
  - A dashing rival within reach steals the star (0.68 m, Pip 0.77 m), but only after `safe_until`.
  - Passes lead a running receiver, and anyone can intercept along the path.
- **Events.** `emit(kind, seat, fields)` appends `{seq, tick, kind, seat, ...}`. `last_light.gd`
  writes them to JSONL with a header (seed, court version, flags, starting policy and relationships)
  and a footer.
- **Determinism.** Same seed, same inputs and same Gemini packets give the same events, every time.
  - All chance comes from `rng` (the match's) or each robot's `draw`, both seeded from the match seed.
  - Draws must happen in a fixed order.
  - `tools/replay_court.gd` proves it on every recording.

### Court versions

Any change to how the simulation behaves gets a new court version, so old recordings still replay
exactly.

| Version | What changed | How older recordings replay |
| --- | --- | --- |
| 5 | Original court | `tools/court_rules_v5.gd` |
| 6 to 8 | Powers, Free Agents | `old_court()` (the smaller court) |
| 9 | Court a quarter longer and wider (22 m) | `enlarged` |
| 10 | Every mode is a 4-minute match; most goals wins | `long_match = false` |
| 11 | A star stuck behind a ring rolls back into play | `fair_deck = false` |
| 12 | Robots look up before passing and passes fly slower; robots are pressure-aware, can evade, sample their moves, treat Gemini as advice, and remember who robbed them | `steady_pace = false`, `wary_robots = false` |
| 13 | New outcome checks for defending, chasing a loose star and supporting, graded against where the target is now; those situations end in `/t` | `team_outcomes = false` |
| 14 | Fair play for people: robots wind up before dashing at a person, and people keep the star longer. Robots on a crew talk to each other. In live play robots ease off while they lead (`mercy`, read from the header). | `fair_play = false`, `team_talk = false` |

**To add a version:**

1. Add a flag that defaults to `true`.
2. Turn it off in `old_court()` if it applies there.
3. Turn it off in `tools/replay_court.gd` for older versions.
4. Bump `"game"` and `"court_version"` in `last_light.gd` and in `tests/gemini_court.gd`.
5. Replay old recordings to prove they still match.

---

## 6. How the robots think and learn

Every robot (seats 2 to 4) runs the same loop, each with its **own separate memory**.

1. **When it decides.** A robot makes a new decision when it has none pending:
   - its window ends (35 ticks before version 12; a random 28 to 46 ticks since);
   - possession changes;
   - it reaches shooting range;
   - since version 12, danger closes in while it carries the star.
2. **What it sees: the context.** The default context is
   `star2/<seat>/<phase>/<reads>/<in range>/<lane>`:
   - phase: carry, support, defend or loose;
   - reads: what it has seen the attacking pilot do (pass, shoot, fresh, or a call for the star);
   - lane: which side that pilot runs.

   Since version 12, a carrier that a rival can nearly reach decides in a context of its own:
   `star2/<seat>/carry/<hot|warm>/<rival>`. **Hot** means inside the rival's steal reach plus the
   distance their ready dash covers. **Warm** means within 1.3 m of that. The reach grows by 0.3 m for
   every time that rival has robbed this robot.

   Since version 13, defend, support and loose contexts end in `/t`, because their outcome checks
   changed and old grades must not mix with new ones.
3. **Legal moves.**

   | Phase | Moves |
   | --- | --- |
   | Carry | drive, flank, pass (when a teammate is more than 1.1 m away), finish (in range), evade (version 12, under pressure only) |
   | Support | outlet, advance |
   | Defend | screen, cut, press (only the nearest defender) |
   | Loose | recover, lead |

4. **Choosing.**
   - Each move's value blends three things:
     - its long-term record in this context (weight up to 6);
     - recent evidence from this match (decays ×0.73 per new result);
     - a common prior.
   - The written rule (the starting preference) gets +0.075. For example, Zip prefers flank.
   - Live play explores at random 8% of the time.
   - Since version 12 the robot samples in proportion to value (Gumbel noise, warmth 0.042) instead of
     always taking the top move. A Gemini proposal gets +0.06; it is advice, not an order.
5. **Moving.** `aim()` turns the move into a spot to run to every tick. Since version 12 each decision
   adds a small random offset, so routes differ. A robot holds the star 0.4 to 0.85 s before passing.
   An evading robot sidesteps a dash it reads in time (about 3 in 5).
6. **Grading.** `settle()` grades the decision with five code checks (see section 7). The grade goes
   into that robot's record at once (`observe`), so its next choice in the same context shifts.
7. **Remembering.** At the end of a live match, every robot's estimates and relationships are saved to
   `user://last-light-policy.json` and loaded at the next launch. Relationships are reputation, last
   deal, the ledger of promises kept and broken, and steals by each player. A match's steals count in
   full in the next match and half as much after that.
8. **Telling you.** The Tab notebook shows each robot's goal, tactic, reason, the basis of the
   decision, graded decisions, who robbed it and its lessons. When a move that got a robot robbed now
   weighs less than the one it picks instead, the robot says so once in a balloon, for example *"Rafi
   robbed me going wide. I pass early now."*

### Robots talking to each other (version 14)

All of it happens inside the simulation, so it replays exactly. Every message is a `talk` event with
a `topic`, the seats it was `to`, and the `line` shown on screen.

| Topic | When | What the listeners do with it |
| --- | --- | --- |
| `warn` | A robot has been robbed twice (and again at four times) by the same player | Each crewmate gives that player 0.15 m more room (`heard_warnings` in `star_agent.gd`) |
| `tip` | A robot has just said a lesson | Each crewmate keeps the tip for that situation (`tips`): the tipped move gets +0.06 in its weighing and the dropped move −0.06 |
| `heed` | A crewmate picks the tipped move in that situation for the first time | Nothing; it tells the robot that gave the tip that it was used |

The three memories stay separate: a robot never reads a crewmate's record, it only keeps what it was
told. Warnings and tips last for the match.

### Fair play for people (version 14)

- A robot winds up for 20 to 36 ticks inside its reach before it dashes at a person with the star.
- A person who gets the star is safe for 84 ticks (102 after catching a pass).
- `mercy` (live play only): `easing()` is a quarter for each goal the robots lead the people by, up to
  1. It slows the robots by up to 22% and adds up to 32 ticks to the wind-up. `-- --full-strength`
  turns it off. Training and evaluations always run without it.

### Gemini's part (`gemini_coach.gd`, `host/radio.py`)

- Every 8 s each robot can send its observation to the host:
  - position, nearby players, score, holder;
  - what it has seen the pilots do, trust;
  - its last four plays, and how often Nell and Rafi have robbed it.
- The host asks `gemini-3.1-flash-lite` for one move per phase with a public reason and validates the
  reply. The game drops replies that are illegal, stale (over 12 s old) or meant for an old team.
- Movement and sound never wait for Gemini. A timeout or error leaves the robots playing.
- **A robot only calls when it is struggling.** It gets one playbook at kickoff, then asks again
  once it has been robbed twice or after ten decisions in a row that failed a check
  (`wants_advice` in `star_agent.gd`), and never more than once in 8 s. That is about 30 calls a
  match against dash-steal pilots, where asking every 8 s made 90.
- **Before version 12** a playbook move was applied unless the robot's recent record was strongly
  against it. In live play about 62% of robot decisions came from Gemini, and it kept sending Zip wide
  past the pilots, where 37 of 42 steals happened. That is why version 12 made it advice.

### Social learning (Free Agents)

Each robot also learns five kinds of social choice:

- which captain to sign with;
- what to do about a broken promise (let it go, stop work, leave);
- whether to take a rival captain's offer;
- whether to sign again with a captain who wronged it;
- how to vote.

Each choice is graded by the next promise made to that robot: kept is 100, broken is 0, and no further
promise is 50. A robot leaves its written rule only when its record says, beyond luck, that another
choice did better. The contexts start with `soc8/`. `--written-rules` turns this off.

---

## 7. The RL environment, in tasks and verifiers

This is how Dhiren frames RL, and how his other RL environments (CAD, coding, Blender, GUI and games)
are built:

- **Tasks.**
- **Deterministic code verifiers**, with intermediate verifiers whose weights sum to a score of 1.
- Code checks are preferred over model judges.
- An oracle should score 1 and a do-nothing agent 0.

For this game he asked for these things, in his words:

- Agents should "do better in the further actions", reacting to the world, the humans and the other
  agents.
- "Training should happen during the gameplay."
- "The agents goal in RL is to win."
- Agents should be "random", so "we should not be able to predict" them.

**The answer to "what is the RL here":** each robot is an agent. Every decision, about every 0.6 s, is
a small task. A code verifier scores it from 0 to 1, and the score immediately changes that robot's
next choice in the same situation. Across matches, the saved memory carries the learning forward.

### Verifiers

| Verifier | What it checks (weights sum to 1) | Status |
| --- | --- | --- |
| **Robot decision** (`settle`, event `action_grade` with type `response`) | Saw the situation 0.10; the move was legal 0.10; approached correctly 0.20; carried the move out 0.25; it worked 0.35. A full pass needs all five. What "it worked" means depends on the task (below). | Live; **this is what trains the robots** |
| **Every pass and shot** (`grade_throw`, type `court_throw`) | Released 0.10; eligible 0.10; flew 0.20; a teammate touched it 0.25; delivered 0.35 | Live; logged only |
| **Social choice** (`grade_social`) | Kept 100, broken 0, none 50, graded when the next promise settles | Live in Free Agents |
| **Harbor tasks** (`tasks/`) | `reward.json` from separate no-network verifier containers | Built earlier; not re-run since version 12 |
| **Bruin checks** (`telemetry/assets/flight/*.sql`) | Unique sequence ids; scores bounded 0 to 100; exactly one learning example per decision; an applied Gemini move equals its proposal; robot attribution for beacon events | Not re-run on version 12 |

### What "it worked" means, by task

The dashboard groups every decision into one of seven tasks.

| Task | It worked if |
| --- | --- |
| Win the star back (defend) | The crew wins the star, or the carrier is held up: under 70% of the ground a free run at our ring would make (version 13) |
| Reach a loose star first | The crew gets the star, or this robot is the nearest player to it (version 13) |
| Get open for a teammate (support) | This robot gets the star, or ends a pass away with nobody in the lane or marking it (version 13) |
| Keep the star under pressure | Still holding the star, and not robbed on the way |
| Carry the star forward | Closer to the ring, still holding the star |
| Complete a pass | The pass reached a teammate |
| Finish at the ring | The shot scored |

Before version 13 the first three asked for the star to be won within the decision's 0.6 seconds, or
for the robot to reach a spot that had since moved. They failed about 96% of the time whatever the
robot chose, so they taught it nothing. Bruin's failure tables are what showed this.

### Evaluations: does learning help?

| Evaluation | Result | Reading |
| --- | --- | --- |
| `learning/star_eval.json` (ball play; 120 training and 32 held-out matches, retrained on court 13) | Trained robots scored 946 goals against 810 untrained; fully verified 29.2% against 28.3%. On court 9 the same test showed no gain (79 against 84 goals). | Training now helps against the scripted styles it trained on. One run; spread not measured. |
| `learning/social_eval.json` (60 held-out series, hidden-truth verifier) | Random 0.557, written rules 0.649, trained 0.655 | Training matched the written rules but did not beat them |
| `learning/steal_eval.json` (16 series of 3 matches against pilots who repeat the dash-steal) | Steals in match 3: court 14 learning 10.0, court 14 frozen 8.8, court 12 10.6, court 11 13.0. Goals level for all four (robots about 17, pilots 18 to 19). | The retrained robots are harder to rob from the first match. Learning during the three matches adds nothing measurable on top, and they still do not win more against this style. |

### Honest limits

- The decision verifier looks only about 0.6 s ahead. A steal that costs a goal is graded like one that
  does not.
- Defending is still the weakest task: against dash-steal pilots the outcome check passes 7% to 19%
  of the time.
- The defenders' outcome is shared by the crew, so one robot's good choice and another's bad one get
  the same result.
- The steal test has no oracle or do-nothing calibration (a frozen robot scores 0.25, not 0).
- The social checkpoint was trained on an older court and has not been retrained. The ball-play
  checkpoint was trained on court 13, not 14.
- No evaluation yet compares trained robots with random ones, so "the robots learn" rests on the
  results above and no more.

---

## 8. Rules that keep it working

1. **Keep the 60 Hz simulation, deterministic replay, three separate robot memories, the asynchronous
   Gemini host and Bruin telemetry working.** These were the original handoff conditions.
2. **Every behaviour change to the court is a new court version** (see section 5). Replay old
   recordings with `tools/replay_court.gd` and make sure they still pass.
3. **All chance goes through seeded generators** (`rng`, or a robot's `draw`), drawn in a fixed order.
   Never use `randf()` or wall-clock time inside the simulation.
4. **Never commit, print or paste a key.**
   - Do not read the key file under `~/Library/Application Support/Last Light Host/`.
   - Never ask anyone to paste a key into a chat.
   - `.env` is gitignored, but keep keys in your shell or the host's key file.
5. **Keep the game local.** Ask Dhiren before deploying a shared service, or before sending match data
   to any outside service.
6. **Run `scripts/check.sh` before every push**, and `--full` if you touched the scene, menus or match
   flow.
7. **Keep the Bruin invariants.**
   - Robot decision contexts start with `star2/` (`flight.agent_decisions` filters on it).
   - `flight.robot_decisions` reads the phase from the third part of the context and pressure from
     the fourth. If you rename contexts, update it.
   - When a verifier check changes meaning, give the affected contexts a new suffix and raise the
     `verifier` generation in `robot_decisions.sql`, so old and new grades are never compared.
   - A decision marked `applied` must use exactly the Gemini proposal.
   - Every `response_intent` gets exactly one `action_grade`.
8. **Test and capture scripts must not touch the player's data.**
   - Any script that instantiates `game/last_light.tscn` must set `game.test_session = true` before
     adding it to the tree.
   - Otherwise it runs as a live session: it calls Gemini, writes into `user://flights`, and
     overwrites the robots' memory on exit.
9. **Keep the two-button scheme.** New actions go into what GO and SHARE mean in context, not onto new
   keys.
10. **Look and feel**, as Dhiren has asked for it:
    - bright scenes (never dark bands over the 3D view);
    - a busy, fantastical background, never plain primitive shapes;
    - motion that is natural, not robotic: no identical copies or shared timing;
    - comic panels for story beats;
    - sound for everything;
    - no lag.

    Show stills when a look changes.
11. **Big files.** GitHub refuses files over 100 MB. The largest today is a 46 MB video in `docs/`.

---

## 9. Where it is heading

### Built

- Three modes.
- Robots that warn and tip each other, and act on what they hear.
- Fair play for people, with robots easing off while they lead.
- A four-minute demo script: [docs/DEMO.md](docs/DEMO.md).
- A live Bruin report of where each robot is failing, task by task and check by check.
- Outcome checks that separate good decisions from bad ones in all seven tasks.
- Robots that only call Gemini when they are struggling.
- Robots that learn live from verified grades and remember across matches.
- Gemini playbooks as advice.
- Promises, walkouts and the union.
- The beacon world event.
- Bruin telemetry.
- Deterministic replays.
- Harbor tasks.
- Docker.
- The carnival harbor, comics, voices and sound.

### Asked for or discussed, not built

- **Richer robot talk.** Robots now warn and tip each other. They do not yet plan a play together,
  negotiate, or call for the star. Dhiren wants them to "keep discussing with each other".
- **Agents that use their powers deliberately** and plan to win the match, not just the next 0.6 s:
  credit for the decision that led to a goal, or to losing one.
- **Light VLM checks** alongside the code checks (for example on spoken lines). These are not used yet.
- **BAND or other outside services for match data.** This needs Dhiren's go-ahead and his own
  account.
- **Hindsight drills.** Replay a recorded match to a failed decision, try every other legal move
  from that exact moment, and feed the verifier's scores back. Deterministic replay makes this
  possible; it is not built.
- **Credit for one defender.** The defenders' outcome is shared by the crew today.
- **Retraining** the social checkpoint on court 13, and re-running the Harbor tasks on it.
- A fresh packaged app (`exports/` is stale) and a frame-time benchmark on version 12.

### Open questions for the team

- Should every mode end as humans against robots? Today only a union in Free Agents does that.
- Which matters more for the demo: stronger evidence that the robots learn (a calibrated verifier,
  goal-level credit), or more spectacle (robot banter, bigger world events)?
- How strong should the robots be? Before version 12 they won 16–0 and 14–2 against Dhiren. In
  version 12 tests against scripted pilots, scores are close.

### Known issues

- In Free Agents with one honest captain and one dishonest one, the honest crew can win by 30 goals:
  every robot ends up with the honest captain, and no union forms. The rules allow it, but it is
  lopsided.

---

## 10. Working together

- `main` is the shared branch. Make a branch for each change and open a pull request.
- Write commit messages as one plain sentence that describes the change for the player or the
  developer.
- Update `README.md` and this file when behaviour changes.
- Never commit `.godot/`, `exports/`, `telemetry/local/`, anything from `user://`, or secrets.
- If you change scripts that the Harbor image copies (see `tasks/Dockerfile`), rebuild it with
  `docker build -t last-light-harbor:4.7.2 -f tasks/Dockerfile .` and run
  `tasks/check-local.sh ring-window`.
