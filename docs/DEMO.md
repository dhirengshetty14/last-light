# Last Light: the four-minute demo

What to show, in what order, what the audience will see, and what to say. Everything here happens in
the real game; nothing is scripted or faked.

## Before you start

1. Start the game and the live robot report side by side.

   ```sh
   python3 telemetry/dashboard.py --open      # the report, http://127.0.0.1:8960/
   godot --path .                             # the game (on a Mac: the Godot 4.7.2 app's executable)
   ```

   On a Mac, `Play Last Light.command` starts both.
2. Put the game on the left and the report on the right, or on a second screen.
3. Two people take the keyboard: Nell on WASD, Space and F; Rafi on the arrows, Enter and Slash.
4. Play one warm-up match beforehand. The robots remember who robbed them, so the second match shows
   more.

## The story in one line

Two people and three robots play a four-minute match. Every decision a robot makes is checked by code
and scored. The robots change what they do from those scores, tell each other what they learned, and
Bruin shows where they are still failing while the match is being played.

## Scene 1: the game (30 seconds)

- Skip the comic with Escape, open **Choose your game**, pick **Rivals**.
- Say: "Two of us against Pip, Morrow and Zip. Two buttons each. The bars at the bottom always say
  what a button will do right now."
- Score once if you can. The carnival flashes in your colour.

## Scene 2: a robot gets robbed and warns its crew (60 seconds)

- Do this: wait until a robot carries the star, run at it and press **GO** to dash into it. Do it to
  the same robot twice.
- On screen:
  - **YOINK!** on each steal.
  - After the second steal, that robot's balloon: *"Rafi has robbed me twice. Give that dash more
    room."* The harbor radio shows who it was said to: *"To Pip and Morrow: …"*
- Say: "That was one robot talking to the other two. They now keep further from my dash, although I
  never robbed them."
- On the report: **Robots robbed** goes up, and the message appears under **Robots talking to each
  other**.

## Scene 3: a robot learns, and the lesson spreads (60 seconds)

- Do this: keep robbing a robot while it carries the star the same way.
- On screen:
  - **LEARNED!** and a balloon such as *"Rafi robbed me going wide. I pass early now."*
  - **TIP!** as it tells the crew: *"Crew: near Rafi, pass early. Going wide got me robbed."*
  - Later, **GOT IT!** when another robot uses it: *"Zip said: near Rafi, pass early. Doing that."*
- Press **Tab** to open the robot notebooks: each robot's goal, its reason for the current move, who
  has robbed it, its lessons, and what it has heard from the crew.
- Say: "The first balloon is a robot learning from its own graded decisions. The second is it
  telling the others. The third is another robot acting on what it was told."

A lesson needs the robot to be robbed in the same kind of moment more than once, so it can take
three or four steals. If it has not happened after a minute, move on; the report shows lessons from
earlier matches.

## Scene 4: alliances, betrayal and a world event (60 to 90 seconds)

- Go back to the menu (Escape, then choose a game) and pick **Free Agents**. Nell and Rafi are now
  rival captains.
- Each robot signs with a captain for a promise shown on screen: Pip wants the next shot, Zip wants
  two passes, Morrow wants the next shot to come off a pass.
- Do this: keep one promise (press **SHARE** to pay the robot you owe). Then break one: shoot when
  you owe a robot the shot.
- On screen: **PAID!** when you keep your word. **CHEAT!** when you break it, and the robot walks out
  to the other captain or goes on strike.
- If both captains break a promise, a robot calls a vote on the radio. If two of three vote yes, the
  robots form their own crew, **the harbor goes dark**, and it becomes people against robots.
- Say: "The robots chose their captain, traded for a promise, and left when it was broken. The
  walkout is their decision alone. Nobody scripted it."

## Scene 5: the live report, built with Bruin (45 seconds)

Point at the report.

- **Tasks.** "Every robot decision belongs to one of seven tasks. A red Failing tag means under a
  quarter of those decisions passed all five checks."
- **Where it breaks.** "This is the move that costs the most score, and the check it misses."
- **Model calls.** "A robot only calls Gemini when it is struggling, not every few seconds."
- **Bruin.** "Bruin loads every match log, runs 19 quality checks and rebuilds this in under a
  second. The page reads one file, so refreshing it costs no query."
- The honest finding: "Bruin showed us that three tasks failed about 96% of the time whatever the
  robot did. The fault was our own checks, not the robots. We fixed the checks and retrained."

## What to claim, and what not to

Say:

- Every robot decision is graded by five code checks, and the grade changes that robot's next
  choice during the match.
- Robots tell each other warnings and tips, and the listener's behaviour changes.
- Every match replays exactly from its recording.
- Against the scripted opponents they train on, trained robots scored 946 goals to 810 untrained.

Do not say:

- "The robots learn to win." Against players who repeat the dash-steal, they are robbed less than
  they were but do not win more.
- "The robots plan ahead." Each decision is graded on the next half second or so.

## If something goes wrong

| Problem | What to do |
| --- | --- |
| The report says Idle or stops updating | Check `telemetry/local/live.log`. A log that fails a Bruin check stops the pipeline until it is moved out of the matches folder. |
| No Gemini | Nothing to do. The robots play on their own record, and the report shows zero model calls. |
| The robots are too strong | They ease off while they lead: for each goal of lead, up to four, they run slower and take longer to dash at you. Launch with `-- --full-strength` to turn that off. |
| The robots are too weak | Launch with `-- --full-strength`. |
