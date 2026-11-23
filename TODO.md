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

## Night 2

- [x] Wet sill from an open window: leaving the side window open lets rain in. The sill and the floor by the window get wet, the puddle grows the longer it stays open, and it dries after the window is shut. Dale can notice it.

## Cars

- [x] Cars: the car interiors need to make sense. Some cars clip through the models of the people pulling up (the drivers), so check each car's seats and interior against where the driver sits.

## Desk

- [x] Mug: the inside of the mug is not modelled yet. Model the hollow inside so the mug looks right when looked into.

## Side hustle: hack the hospital (PC)

- [x] Night 3: selectable dialog. Lines show 2-4 numbered options under the speaker (click or keys 1-4). System built; night three's real conversations still to write (docs/design/coop-notes.md)
- [x] Find the hospital's IP in a leaked file or web page, then connect to it from the PC
- [x] Hospital login needs a password. Clues come from the NPCs (e.g. a pet's name), learned as they arrive in the car park
- [ ] Once in, see the data of the people letting in (visitor details)
- [ ] Bribe visitors, or use the stolen data some other way (payoff details still to decide)
- [ ] Overnight file transfers that run while the shift goes on, finishing before 07:00 (basic downloads exist: three files, 25-110 s each, saved to C:\DOWNLOADS; the overnight/background version is still to do)
- [ ] Risk of getting caught grows with each action (what happens when caught is still to decide)
- [ ] Decide what happens when caught (fired, game over, or a fine)
- [ ] Decide the exact payoff: coins from bribes, story info, or both

## Co-op (from night three; design log in docs/design/coop-notes.md)

- [ ] Build co-op: host + join by code/IP, host runs the story, up to 4 guards (player models exist)
- [ ] Settle the open questions at the bottom of docs/design/coop-notes.md before building it
- [ ] Every new night-three feature goes through one function that takes a player id (see the rules in coop-notes.md)

## Night 3 people and dialog

- [ ] Write night three's people, each with their own dialog (side window, desk phone and out on patrol), using the dialog format in `scripts/story/dialogs/`.
- [ ] Dialog options for every night three conversation, with the safe option and the 2-4 numbered choices.
- [ ] Hacking clue: one night three person has a dog. Their dog's name is the password clue (ties in with the hospital login).
- [ ] Hacking clue: the printed paper with the hospital's IP is handed to the guard by an old, friendly staff member (ties in with the IP plot point).

## UI

- [ ] Bug: the NightLink UI overlaps other UI. Fix the layout so it does not overlap.

## Night 3

- [ ] Walkable area: take screenshots of the lot from player eye height and check it looks right from every angle.
- [ ] Walkable area: make sure the player cannot leave the lot (walls, fence and tree line block walking out).
- [ ] Order a boot wedge from the PC. It is delivered the next day.
- [ ] Be able to open the boot of any car in the lot.
- [ ] Opening a boot for no reason: the car's owner gets angry and reports it to Dale.
- [ ] Dale's reaction to a report: first tells the player to keep an eye out for people, then gets suspicious of the player if it keeps happening.

- [ ] Steal items from car boots and sell them to a weird guy who turns up (a buyer for stolen goods; ties in with the dark web contact idea). Decide the buyer, when he shows up, what he pays, and the risk.

## Bugs

- [x] Bug: the radio's aerial goes through the window sill. The radio sits against the front window (`scripts/world/desk_props.gd` `_build_radio`, position z -0.93), and the aerial passes through the sill board at about y 0.95. Fix by moving the radio back from the sill or leaning the aerial back

## Web and story hints

- [x] Web: news article about a hacker earning millions from stolen data (a little hint of the hacking side hustle). Show it on night 2/3 only, on the Ashford Gazette site, and add it to the site search index

## Ideas (not committed)

- [x] Night 2 ambience: rain-soaked paperwork (ID cards or the list) is smudged and harder to read, as a small hint the player can use or ignore.
- [x] Night 2 ambience: the coffee on the desk goes cold over the night, with a visible change in the steam.
- [x] Night 2 ambience: the radio crackles more in heavy rain, and the station fades in and out, as a small hint the rain is heavy.
- [x] Night 2 ambience: a previous operator's doodles and notes in the logbook margins, including a mention of the car in row C that hasn't left.
- [x] Night 2 ambience: the wall clock ticks a little louder at 02:00.

## Done

- [x] Location build v0.1: booth, car park, weather, lightning, radio, desk and CRT terminal
