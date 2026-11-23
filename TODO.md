# Dark Park TODO

Running list for the game. Tick items off as they are done, and add new ones at the bottom of a section.

## Now

- [ ] Missions: define the first night shift mission and what the player does
- [ ] Story: outline the main story beats for the night shift
- [ ] Hook the story events into the existing `Weather`, `NightClock`, booth and lot hooks (see README "Hooks ready for the story")

## Desktop and in-game PC

- [ ] Decide which files and emails the story needs on the PC (SHIFT NOTES, Inbox, Recycle Bin)
- [ ] Check the in-game browser and mailbox work with the story content

## Polish

- [ ] Sound pass on the radio, weather and ambience
- [ ] Check the phone-width / small-window layout of the desktop UI
- [ ] Review the lighting and rain performance on lower-end machines

## Builds

- [ ] Mac port: export a macOS build (Godot export preset, signing and notarising, and check the Chromium web browser runs on Mac)

- [ ] Confirm the Windows export still runs (`DarkPark.exe` plus the Chromium files)
- [ ] Update the README "Status" section when a milestone is reached

## Side hustle: hack the hospital (PC)

- [x] Night 3: selectable dialog. Lines show 2-4 numbered options under the speaker (click or keys 1-4). System built; night three's real conversations still to write (docs/design/coop-notes.md)
- [ ] Find the hospital's IP in a leaked file or web page, then connect to it from the PC
- [ ] Hospital login needs a password. Clues come from the NPCs (e.g. a pet's name), learned as they arrive in the car park
- [ ] Once in, see the data of the people letting in (visitor details)
- [ ] Bribe visitors, or use the stolen data some other way (payoff details still to decide)
- [ ] Overnight file transfers that run while the shift goes on, finishing before 07:00
- [ ] Risk of getting caught grows with each action (what happens when caught is still to decide)
- [ ] Decide what happens when caught (fired, game over, or a fine)
- [ ] Decide the exact payoff: coins from bribes, story info, or both

## Co-op (from night three; design log in docs/design/coop-notes.md)

- [ ] Build co-op: host + join by code/IP, host runs the story, up to 4 guards (player models exist)
- [ ] Settle the open questions at the bottom of docs/design/coop-notes.md before building it
- [ ] Every new night-three feature goes through one function that takes a player id (see the rules in coop-notes.md)

## Bugs

- [ ] Bug: the radio's aerial goes through the window sill. The radio sits against the front window (`scripts/world/desk_props.gd` `_build_radio`, position z -0.93), and the aerial passes through the sill board at about y 0.95. Fix by moving the radio back from the sill or leaning the aerial back

## Web and story hints

- [ ] Web: news article about a hacker earning millions from stolen data (a little hint of the hacking side hustle). Show it on night 2/3 only, on the Ashford Gazette site, and add it to the site search index

## Ideas (not committed)

- [ ] Night 2 ambience: leaving the side window open lets rain in. The sill and the floor by the window get wet, the puddle grows the longer it stays open, and it dries after the window is shut. Dale can notice it.
- [ ] Night 2 ambience: rain-soaked paperwork (ID cards or the list) is smudged and harder to read, as a small hint the player can use or ignore.
- [ ] Night 2 ambience: the coffee on the desk goes cold over the night, with a visible change in the steam.
- [ ] Night 2 ambience: the radio crackles more in heavy rain, and the station fades in and out, as a small hint the rain is heavy.
- [ ] Night 2 ambience: a previous operator's doodles and notes in the logbook margins, including a mention of the car in row C that hasn't left.
- [ ] Night 2 ambience: the wall clock ticks a little louder at 02:00.
- [ ] Desk prop: a hole in the mug on the desk (coffee leaks out or the mug is cracked). Applies all night, not just night two.

## Done

- [x] Location build v0.1: booth, car park, weather, lightning, radio, desk and CRT terminal
