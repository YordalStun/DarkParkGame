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

## Web and story hints

- [ ] Web: news article about a hacker earning millions from stolen data (a little hint of the hacking side hustle). Show it on night 2/3 only, on the Ashford Gazette site, and add it to the site search index

## Ideas (not committed)

- [ ] (add ideas here)

## Done

- [x] Location build v0.1: booth, car park, weather, lightning, radio, desk and CRT terminal
