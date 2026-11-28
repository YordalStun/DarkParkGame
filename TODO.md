# Dark Park TODO

Running list for the game. Tick items off as they are done, and add new ones at the bottom of a section.

## Next up (in order)

- [x] 1. Plate view: smaller, only opens on a deliberate click (v0.8.1).
- [x] 2. Survival meters: heat, food and rent (rent 2, food 1, heat 1 a day), bank starts at 8 coins (v0.8.1).
- [x] 3. Boot opening and reports: Dale's reactions at 5, 7 and 10 reports (v0.8.1).
- [x] 4. Night three's people and dialog, the dog and printed-IP clues (v0.8.1 - v0.8.3).
- [x] Decisions: daily bill costs, and risk values for boots (5-25 each) and hacking.
- [ ] 5. Play test with a friend (co-op over the internet) using the checklist below, and write down what happened.
- [ ] 6. Nights four and on: their own arrivals, calls and story beats (at the moment they reuse night three's).

### Play-test checklist (v0.8.4)

Watch for these, and note anything that was confusing, boring or broken:
- [ ] Joining over the internet (not the same machine): does the guest connect, does the night start for both, any lag?
- [ ] Does the second guard always have something to do while the other is at the window?
- [ ] Do you both understand the objectives in the top right without being told?
- [ ] Do you notice the car alarm and go out? Do you find the note?
- [ ] Does Baxter turn up after the note, and does the window option / payphone deal make sense?
- [ ] Can the guest see Baxter and sell to him? Does the crate stay the same for both of you?
- [ ] The police walk-round: does it feel tense? Did you talk to him?
- [ ] The Nite Stop pick lock and the second hut: can you find both? Does breaking in the next night work?
- [ ] The quota: is missing it on night three fair, or just annoying?
- [ ] How long does a night feel? Where is it slow?
- [ ] Any crashes, stuck moments, or things that don't match between your two screens?

Story (in progress, see docs/design/night-three-lore.md):
- [x] Night three's beats: Doris's newsletter, Kevin's dog, the alarm car, Baxter, the police.
- [ ] Missions: the first big hit (what the hacking and the stealing are building towards)
- [ ] Story: outline the main beats after night three (Baxter's arc, Kessler and the car in Row C)
- [ ] Hook the story events into the existing `Weather`, `NightClock`, booth and lot hooks (see README "Hooks ready for the story")

## Ideas to make it better (from v0.8.4; not committed)

- [ ] A job for the second guard: they can watch the CCTV, keep a lookout and radio in when the police or the supervisor are coming, or work in the second hut, so they aren't waiting while the other is at the window.
- [ ] Proximity voice chat (co-op). About a day for a first version:
  - Push-to-talk (V): your voice comes from your guard in the world, fading with distance and muffled through the hut walls (the Interior/Outside buses).
  - Lo-fi 8 kHz audio (about 64 kbps a player): fits 1989 and the bandwidth. Godot has no voice compression built in; a community add-on could compress it properly later.
  - A small buffer so the voice doesn't stutter over the internet.
  - A mic picker and a voice volume slider on the pause screen. Recommend headphones (Godot has no echo cancellation).
  - Later: the walkie-talkie below on its own key for long distance.
- [ ] Radios for co-op: a push-to-talk walkie-talkie between the booth and the lot (crackly, cuts out in heavy rain).
- [ ] Tension cues: a heartbeat or a sting when the police get close to an open boot, the torch beam sweeping across the hut's window, and a warning if you're standing at an open boot when a car pulls in.
- [ ] Owners come back: a car's owner sometimes walks back to their car mid-shift (for something they forgot) and finds the open boot.
- [ ] Consequences you can see: the next night's Ashford Gazette on the desk reports last night's thefts, and Dale's call mentions what happened.
- [ ] Haggling with Baxter, and Baxter's own arc (why he's ill, who he sells for).
- [ ] Spread night three's new things out: a lot happens at once (tasks, the alarm, the police, Baxter, the shop). Maybe move some to night four.
- [ ] Kessler and the car in Row C: a payoff for the creepy thread from nights one and two.
- [ ] Quality of life: save and quit mid-night, mouse sensitivity and key rebinding, a list of the controls on the pause screen.

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

- [ ] Cars: cut out the car body where the NPC sits inside, so drivers and passengers don't clip through the roof, seats or doors. Check each car style (see `scripts/world/car_model.gd`).
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
- [x] Risk of getting caught grows with each action (what happens when caught is still to decide)
- [x] Decide what happens when caught (fired, game over, or a fine)
- [ ] Decide the exact payoff: coins from bribes, story info, or both

## Co-op (from night three; design log in docs/design/coop-notes.md)

- [x] Build co-op: host + join by IP and port, host runs the story, up to 4 guards (scripts/autoload/net.gd, scripts/net/coop.gd)
- [x] MULTIPLAYER on the main menu. Co-op unlocks after night 2; players who haven't got there can host a new game that skips to night 3
- [x] Lobby: host shows IP + port and the guards (P1-P4); only the host presses START; joining is lobby only
- [ ] Every new night-three feature goes through one function that takes a player id (see the rules in coop-notes.md)
- [x] Co-op: everyone sees the PC's screen. Whoever is using a PC sends a small picture of it a few times a second (scripts/net/screen_share.gd); works for the booth's PC and the second hut's.
- [ ] Co-op: more arrivals per extra guard (the risk meter already rises faster; numbers still to tune)
- [ ] Co-op: guests' notepads are their own (dialog "note" effects only reach the host's)
- [ ] Co-op: test over a real LAN / the internet (so far tested with two copies on one machine)

## Night 3 objectives and set pieces (see docs/design/night-three-lore.md)

- [x] Players who aren't in a conversation get small subtitles under the objectives showing what's going on, including the options being chosen (co-op).
- [x] From night 3 the top right objectives are required tasks that stay until done (saved; they come back each night until ticked): inspect IDs and plates (3 cars), take the call that adds someone to the list, get the printed sheet, find out why the car alarm went off, buy a pick lock, and in co-op look round the second hut.
- [x] Police walk through the lot with a torch after the second or third car. They only walk through. Walk up to them to talk.
- [x] From night 4: if the police pass a car with its boot open, they come to the hut and look inside. A hidden crate (or no stolen goods) and no PC download running is safe. Otherwise the night is lost and starts again.
- [x] Alarm car: a random parked car goes off (hazards, wig-wagging headlamps, horn). Checking it finds nothing, but a note by the driver's door says "DEALER" and names Baxter.
- [ ] Alarm car: the alarm and flashing lights aren't good enough. Make the flashing brighter and the sound better (the sound is odd right now).
- [ ] Police walk-through: the police officer walks straight through everything (cars, the booth, objects). Make them walk around solid things and obey collisions.
- [x] Baxter (Tom Baxter, Medical Records, clearly unwell) comes in later, about the fifth car, once the note's been found. At the window you can bring the note up: he's scared and says meet him at the payphone. Out there you can offer to sell him things (the stolen-goods menu). From then on he's the buyer at the payphone on later nights. (The anonymous "man by the payphone" is gone.)
- [x] Night 3 is about six cars from a rotating pool: Kevin always (Biscuit), Doris after the ward rings to add her, and four of Sandra, Michael, Dr Marsh, Janet and Mick.
- [x] Night 3 earns no money (payroll's frozen). Co-op: the team has a nightly quota (4 coins, +2 every 3 nights) from what the night brought in, so night 3 is lost unless they sell stolen goods. Missing it replays the night.
- [x] Pick lock: 2 coins at the Nite Stop door, in the car park. It can break (30% each try). In co-op one purchase is the team's.
- [x] Co-op: the old second hut at the back of the lot from night 3, padlocked. With a pick lock bought on an earlier night you can break in (inside: a dusty desk and an old PC, not working yet).
- [x] Night 3 reports: opening a boot doesn't report you on night 3; Dale rings and asks you to keep an eye out for stolen goods. The area supervisor's spot checks start on night 4.
- [x] No ending. The game keeps going after night 3.
- [x] Baxter in co-op: every guard sees him at the payphone and can walk up, talk and sell. The storage crate is the team's (kept in the host's save; anyone can put things in, hide it or sell from it).
- [x] The second hut's PC: a second NightWin 95 computer that works on its own (its own windows, files and user; scripts/world/pc_station.gd). Walk in once the hut's open. No story use yet (see "Co-op: second hut" for the radio link plan).
- [x] Testing menu works in co-op: a guest's buttons run on the host so everyone gets the same result. New NIGHT THREE ON buttons: unlock the second hut and its PC, car alarm, police, Baxter, fill the crate, free pick lock, and jump to night 4.
- [ ] Police: guests can talk to them, but the trip to the hut is decided on the host only. Check it in a real co-op game.
- [ ] Tune: the quota and the pick lock's break chance.
- [x] Fix: nothing night three put in the car park could be used from outside (boots, boot items, Baxter, the police, the alarm car, the note, the Nite Stop, the hut door and PC). They now work out there (v0.8.6).
- [x] Baxter waits at the back of the lot, by the fence near the old hut, smoking (a glowing cigarette so you can spot him), in a shabby mac rather than a porter's hi-vis.
- [ ] Baxter smoking (the character is Baxter in the code; "Dexter" here is taken to mean him): the cigarette is floating beside his head with his hands down, not in his mouth. Fix it so he holds the cigarette to his lips with one hand, with a proper arm pose. Check it in `scripts/story/night_events.gd` (the cigarette is a fixed box at a set point).
- [ ] Bug: cars park in the same spot. Each visitor should get a free bay (see `_bays` and `_bay_pos` in `scripts/story/shift.gd`). Check for bays being reused or not freed when a car leaves.
- [ ] Van: the van's boot doesn't work right. A van has no boot lid, it has two rear doors that open. Make the van open its two back doors (both swing out) instead of a boot lid, and let the player take items from inside. Check `scripts/world/car_model.gd` and `scripts/world/car_builder.gd` for how the boot is built.
- [ ] Bug: Baxter says there's nothing to sell even though the crate has stolen goods in it. Cause: the crate-hidden flag (`world.booth.crate_hidden`, meant for the police check) also blocks the sale in `scripts/story/shift.gd` `sell_from_crate` and the payphone line in `scripts/story/night_events.gd` `baxter_talk`. Fix: only the police check should use the hidden flag; Baxter should see the crate's goods whether it's covered or not.
- [ ] Baxter at the fence: the player can ask him for his ID card (the same ID check as at the window, shown on the inspect card).
- [ ] Baxter smoking: add a flicking ember (the glow pulses as he draws on it) and rising smoke puffs, so it reads as smoking from the booth.
- [x] Co-op: no rent, food or heat. The end screen shows the team quota (a target: keep every coin) and things to buy.
- [x] Co-op: the other guard's walk animation follows how fast they're really moving (it barely moved before).
- [x] Co-op: what the team has bought (boot wedge, pick lock...) is everyone's.
- [x] Testing menu: Boot wedge (free).
- [ ] Co-op: a guest opening a boot only opens it on their own screen (the others don't see the lid up), and its risk is only counted there.

## Core loop: staying alive (see docs/design/core-loop.md)

- [x] Survival meters: heat, food and rent. Each has a daily cost. Show them on screen. (Rent 2, food 1, heat 1 a day; each meter is 3 nights, refilled by paying, -1 when skipped, 0 = game over. Single player only. HUD line under the coins, pips on the end screen.)
- [x] Bank: Dave starts with 8 coins, enough for the first two days.
- [ ] Legal income: a legal night pays the bills at a slow rate. An honest run can survive but not comfortably.
- [x] Reports: 5 reports = suspicious, 7 = Dale makes it clear it must stop, 10 = fired (game over). Dale says he has footage before the firing. (Saved per slot; Dale reacts in the next night's call; 10 = FIRED on the end screen.)
- [x] Forgiveness: one report is forgiven every two days.
- [x] Risk meter for hacking and stealing: 100% = caught by the police (game over). Each action adds to it; it drops about 20% a day. (Saved per slot. Boot items add 5-25; hacking's own values unchanged.)
- [ ] Protection: a VPN helps with small hacks; a separate PC is needed for big hacks. Big hacks can catch Dave instantly without protection. Other ideas to consider: IP hiding, fake names, a contact.
- [ ] Police: they walk through the lot and catch Dave red-handed (game over).
- [x] Restart after being caught: the night restarts, but suspicion carries over. (Risk 100 at the end of the night = CAUGHT: the same night restarts, reports kept, risk set to 50.)
- [x] Suspicion carries from night to night and takes time to reduce.
- [ ] Multiplayer quota: 4 coins a day shared across the guards, getting harder every 3 days. If the team misses it, the whole team loses.
- [x] NPC knowledge: the player learns about NPCs (e.g. who has a guitar in their boot) so they can target items instead of stealing from everyone. (Night three: Tom's guitar, Dr Marsh's camera bag; notes go in the notepad. More people to come.)

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

- [x] Write night three's people, each with their own side-window dialog (scripts/story/dialogs/night_three.gd): Sandra, Michael, Kevin, Dr Marsh, Tom, Janet, Doris, and Mick Doyle (wrong car: turn away). Dale's own night-three call. (Desk phone and patrol conversations still to write.)
- [x] Dialog options for every night three conversation, with the safe option and the 2-4 numbered choices.
- [x] Hacking clue: Kevin Platt's dog Biscuit (the hospital password), from his night-three window chat. NPC knowledge for boots: Tom's guitar, Dr Marsh's husband's camera bag.
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
- [x] Boot wedge: bought on the end-of-shift screen (2 coins), there from the next night. (Ordering it on the PC is still an option for later.)
- [x] Be able to open the boot of any car in the lot (night three on, outside, with the wedge). The lid swings up; each car has 0-5 items.
- [x] Opening a boot for no reason: the car's owner gets angry and reports it to Dale (+1 report each boot).
- [ ] Be able to close a car boot after opening it (not only open it).
- [ ] Dale's call after looting is too fast. Nobody has had time to report it yet. Give the owner time to notice and report before Dale rings (timing still to set).
- [x] Dale's reaction to a report: first tells the player to keep an eye out for people, then gets suspicious of the player if it keeps happening.

- [x] Boots are real: every car has a boot well and a hinged lid with a boot light; 0-5 items (20 kinds, scripts/world/boot_items.gd) lie in it without overlapping. Click one to take it: adds its own risk and takes 1-2 of 3 carry slots. Drop them in the storage crate in the hut. Tom's and Dr Marsh's boots hold what they mentioned.
- [x] Storage crate in the hut (10 slots, kept between nights, holds story items too, can be hidden under the desk).
- [x] The man by the payphone turns up in person some time in the night; talk to him and pick what to sell from the crate.
- [x] Area supervisor spot checks: a van warning, then if the crate is out (or you're carrying stolen goods) he takes it all, reports you twice and adds risk.
- [ ] Buyer (Baxter): haggling over the price (for now he pays a fixed price for each item).
- [ ] Buyer: sell radio parts for the second hut's link (see "Co-op: second hut").
- [ ] Buyer: give him his own lines and a name, and have him come back on later nights with different moods.
- [x] Co-op: the guards share one crate (the host's).
- [ ] Co-op: supervisor spot checks are single player only for now; decide how they work with several guards.
- [ ] Spot checks (night 4 on): let the player stop him at the door with a dialog (stall him while someone hides the crate).
- [ ] Play-test: walk out to the buyer and sell to him, and watch the crate slide under the desk (both panels and the spot check were tested with test switches, not played through).

## Bugs

- [ ] Bug: players can click through the booth to open the door when they are on the wrong side of it. The door should only be usable from the correct side (the booth's door interaction in `scripts/world/booth.gd`, and the leave-booth flow in `scripts/story/shift.gd`).
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
