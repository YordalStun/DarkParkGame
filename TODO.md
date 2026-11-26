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

- [x] Build co-op: host + join by IP and port, host runs the story, up to 4 guards (scripts/autoload/net.gd, scripts/net/coop.gd)
- [x] MULTIPLAYER on the main menu. Co-op unlocks after night 2; players who haven't got there can host a new game that skips to night 3
- [x] Lobby: host shows IP + port and the guards (P1-P4); only the host presses START; joining is lobby only
- [ ] Every new night-three feature goes through one function that takes a player id (see the rules in coop-notes.md)
- [ ] Co-op: spectator view of the PC for the guards who aren't using it (for now they are told who is on it)
- [ ] Co-op: more arrivals per extra guard (the risk meter already rises faster; numbers still to tune)
- [ ] Co-op: guests' notepads are their own (dialog "note" effects only reach the host's)
- [ ] Co-op: test over a real LAN / the internet (so far tested with two copies on one machine)

## Core loop: staying alive (see docs/design/core-loop.md)

- [x] Survival meters: heat, food and rent. Each has a daily cost. Show them on screen. (Rent 2, food 1, heat 1 a day; each meter is 3 nights, refilled by paying, -1 when skipped, 0 = game over. Single player only. HUD line under the coins, pips on the end screen.)
- [x] Bank: Dave starts with 8 coins, enough for the first two days.
- [ ] Legal income: a legal night pays the bills at a slow rate. An honest run can survive but not comfortably.
- [x] Reports: 5 reports = suspicious, 7 = Dale makes it clear it must stop, 10 = fired (game over). Dale says he has footage before the firing. (Saved per slot; Dale reacts in the next night's call; 10 = FIRED on the end screen.)
- [x] Forgiveness: one report is forgiven every two days.
- [ ] Risk meter for hacking and stealing: 100% = caught by the police (game over). Each action adds to it; it drops about 20% a day.
- [ ] Protection: a VPN helps with small hacks; a separate PC is needed for big hacks. Big hacks can catch Dave instantly without protection. Other ideas to consider: IP hiding, fake names, a contact.
- [ ] Police: they walk through the lot and catch Dave red-handed (game over).
- [x] Restart after being caught: the night restarts, but suspicion carries over. (Risk 100 at the end of the night = CAUGHT: the same night restarts, reports kept, risk set to 50.)
- [ ] Suspicion carries from night to night and takes time to reduce.
- [ ] Multiplayer quota: 4 coins a day shared across the guards, getting harder every 3 days. If the team misses it, the whole team loses.
- [ ] NPC knowledge: the player learns about NPCs (e.g. who has a guitar in their boot) so they can target items instead of stealing from everyone.

## Co-op: second hut (multiplayer only)

- [ ] Build a second hut for co-op only. It is super basic and has to be broken into. The only thing inside is a second PC.
- [ ] Second PC starts with no internet and no connection to the main hut. Once connected, it can download files, surf the web and log things. Nothing else in the new hut.
- [ ] Hut access: walk to the second hut across the lot. Breaking in needs a tool or a lock to pick (exact method still to decide).
- [ ] Link between the huts: radio link. It is weaker in heavy rain, so the link can get worse in storms.
- [ ] Link parts: two radios and an aerial each (one set for each hut). Too expensive for Dave to buy new, so there are two ways to get them without stealing:
  - Buy them from the weird guy who buys stolen goods (he also has a shop). Ties in with the stolen-goods buyer.
  - Buy second-hand from an online shop on the PC (a fallback for players who don't want the shop option). Cheaper than new, but it still costs coins and takes a day to deliver, like the boot wedge.
  - Stealing them from a car is still possible as a riskier option.
- [ ] Installing the link: look up at the right point on each hut and click it. The prompt says "Install radio mast". The screen fades to black and comes back with the radio mast installed on the side of the hut. Do this for both huts.
- [ ] After both radios are installed, the PC gets new software. The player uses it to connect the two PCs.
- [ ] Setup takes a few minutes in game.
- [ ] Visibility: the main hut's PC logs each connection and file transfer, so the main player can see what the second hut is doing.
- [ ] Second PC uses: download, browse, log, and transfer files from PC to PC between the two huts. The transfer is much faster than the internet but still slow.
- [ ] Once connected, share the main hut's internet with the second hut. The link can be turned on and off from the main hut.
- [ ] Shared internet is much slower, so the two huts can do two things at once, but each gets a slower connection.
- [ ] Downloads are much slower than now. A download runs for the whole shift, or until the PC is left on to the next shift.

## Night 3 people and dialog

- [ ] Write night three's people, each with their own dialog (side window, desk phone and out on patrol), using the dialog format in `scripts/story/dialogs/`.
- [ ] Dialog options for every night three conversation, with the safe option and the 2-4 numbered choices.
- [ ] Hacking clue: one night three person has a dog. Their dog's name is the password clue (ties in with the hospital login).
- [x] Hacking clue: the printed paper with the hospital's IP is handed to the guard by an old, friendly staff member: Doris Fenn (64, Ward 7 clerk), a new night-three arrival, hands over the staff newsletter (scripts/story/dialogs/doris.gd).
- [x] Printed sheet from the elderly staff member: the printer footer carries the hospital address (10.113.7.20, the same one the leaked memo gives, so either route works) and the newsletter gives the staff noticeboard, www.ashfordgeneral.org/staff (a new intranet page with the MediCare Remote download link, not linked from anywhere else).

## UI

- [x] Show which night it is: "NIGHT 3" beside the coins all night, and a "NIGHT THREE" title as each night starts

- [x] Bug: clicking a car's plate to check it fills too much of the screen. The plate view (`inspect.show_plate` in `scripts/ui/inspect.gd`) should be smaller. Also stop it opening when the player doesn't want to check the plate (only open it on a deliberate click on the plate).
- [x] Bug: NightLink shows up on the desktop and Start menu from night three with no download. It should only appear after the MediCare download is finished and installed (see docs/design/hacking-system.md). The icon is added in `scripts/desktop/os.gd` when `SaveGame.night() >= 3`.
- [x] Bug: the NightLink UI overlaps other UI. Fix the layout so it does not overlap.

## Night 3

- [x] Leave the hut (night 3 on, solo and co-op): GET UP / G, walk the booth, the back door takes you out into the car park and back (scripts/player/roam.gd). Torch outside. Clocking out still works (come back in first)
- [x] One desk chair: only one guard sits at a time; standing guards can still use the phone, window, barrier, logbook and PC
- [x] The chair moves with the player: rolls back when you get up, back in when you sit, swivels with your view, and rolls over when you lean to the side window or in to the screen
- [ ] Walkable area: take screenshots of the lot from player eye height and check it looks right from every angle (a few checked: towards the lamp, back at the booth)
- [x] Walkable area: make sure the player cannot leave the lot (the fence, the tree line, the shop and the end of the access road stop you; cars, the booth, lamp island, payphone and bin are in the way)
- [ ] Walkable area: the end of the access road behind the booth is an invisible stop; put something there (a gate, bollards or a "NO ENTRY" sign)
- [ ] Cars don't see you: a car driving in pushes you aside instead of stopping
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
