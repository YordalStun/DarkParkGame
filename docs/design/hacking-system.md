# Hacking system (side hustle on the PC)

Status: design log. Add to it as plot points are agreed. Each entry should be
detailed enough for a build session to work from without this chat.

## Agreed so far

- Set on night three. Dave can break into the hospital's network from the PC.
- Entry path: find the hospital's IP address in a leaked file or a web page,
  then connect to it from the PC.
- The hospital login needs a password. Clues come from the NPCs: as each
  arrival drives in, the player learns something about them (for example a
  pet's name) and can guess the password from it.
- Once logged in, the player can see the data of the people letting in
  (visitor details).
- The player can bribe visitors, or use the stolen data some other way.
- Overnight file transfers run while the shift goes on and must finish before 07:00.
- Each action raises the risk of getting caught.
- Night three has selectable dialog: lines show 2-4 numbered options under the
  speaker (click, or keys 1-4). BUILT (scripts/story/dialog.gd): 20 second timer on every choice, the
  safe option is picked and clearly announced if it runs out, same options for all players, shared
  results. See docs/design/coop-notes.md.

## Decisions (from questions)

- Overnight PC: the PC can stay on overnight. The shift still ends at 07:00 and
  Dave clocks out as normal. Downloads keep running in the background.
- Download time: a download only moves forward while the PC is on. Leaving the
  PC off stalls it.
- First warning sign: a call from Dale asking about the PC.
- Data buyer: a specific character (now decided: unnamed dark web contact).

- Data buyer: an unnamed dark web contact. Late-night, anonymous, fits the
  NightNet board world.
- Hospital program: called MediCare (working name).
- Detection risk: each file has a sensitivity level. Risk goes up with:
  (a) how sensitive the file is, (b) how many files the player has reached,
  (c) how often the player logs in each night. Going straight for passwords
  and then logging into other systems is the highest risk.
- If caught mid-download: the connection is cut and the hospital calls the
  player shortly after.

## Built so far (23 Nov 2026)

- **The leak:** `C:\WINDOWS\TEMP\ITMEMO.TXT` (night three on) holds the gateway address `10.113.7.20`, the
  user id format (first initial, dot, surname) and a line saying staff passwords are "something personal".
  The Gazette hacker article (nights 2 and 3) mentions a memo "left lying around in a temp folder".
- **Connect:** the NightLink desktop icon / Start menu entry (night three on) opens NightLink Remote Connect:
  dial the IP, log in, list files, download, hang up. A wrong IP gets "No answer".
- **Password:** user `K.PLATT`, password `BISCUIT` (Kevin Platt's dog). The clue comes from Kevin's window
  conversation (a placeholder: `scripts/story/dialogs/samples.gd`, attached on night three), which sets the
  flag `clue_pet_biscuit` and writes a line in the player's notepad. Three wrong tries lock the account
  for 60 s. Not case sensitive.
- **Files:** `ROTA.TXT` (25 s), `VISITORS.DAT` (45 s, built from tonight's real arrivals) and `PATIENTS.DB`
  (110 s). Saved to `C:\DOWNLOADS`. One transfer at a time.
- **Risk:** a meter in the app (0-100): +2 per dial, +3 per login, +6 per wrong password, +4/+8/+15 per
  download. At 100 the session is cut and the gateway stays shut for the night (the proper consequence is
  still to decide).
- **Co-op:** runs on the host; every action takes a player id; only the PC's owner (first to use it, until
  they sit back or shut down) can act. `tools/hack_test.gd` checks it; the autoplay bot plays it on night 3.

## Open questions

- What happens when Dave is caught.
- The dark web contact's name, and what they want from Dave: UNKNOWN for now (the user doesn't know yet). Keep the contact anonymous until this is decided.
- The download's name and where it is found on the internet.
- Punishment choices: which detection ideas to use and the suspicion thresholds.
- Shift rule when a download is still running at 07:00 (confirm: shift ends, download continues).
- The exact payoff: coins from bribes, story info, or both.

## Plot points

### PP1: getting the hospital's IP

Problem: the player needs the hospital's IP address before anything else.

Idea: a staff member hands the security guard a printed document. The
printer's network address is in the page header or footer, so Dave can read it
off the paper.

Proposed details (for the build session; the exact choices are still open):

- Which document: a printed sheet that a staff member gives Dave at the window
  (for example a visitor pass request, a ward handover sheet, or a shift
  rota). It arrives in the normal flow of the arrivals on night three, so it
  feels like an ordinary errand and not a hack.
- Where the IP shows: small grey footer text such as
  `Printed from WARD7-PRN  10.44.2.17  13/10/89 22:41`. Other pages in the
  game show other printers, so the player has to pick the right one.
- How the player finds it: the printed sheet is an item in the booth. Clicking
  it opens a paper view with the footer readable. Once it has been read, the
  IP is saved to the PC's notes/log so the player can use it later.
- Red herring: one or two other IPs on other sheets (a pharmacy printer, a
  car park barrier) so the player has to choose the right one.
- Risk: none for reading the sheet. Connecting from the PC later is where the
  risk starts.

Open: which staff member gives the sheet, and whether the sheet is the ward
handover or something else.

### PP2: connecting and getting in

Who gives the IP: an elderly staff member who is just being friendly. They
don't know what the sheet reveals. The player is not told this is a hack.

Step 1, connect. The player opens a terminal on the PC and types
`connect 10.44.2.17`. The hospital login screen shows a username. The username
belongs to one of the people who drive through the car park that night (an
NPC who is on tonight's arrivals or is about to arrive).

Step 2, find the password. The player asks that NPC about their pet (in the
normal dialog as they come through the window). The pet's name is the password.
Entering it at the login prompt logs the player in.

Step 3, the blocker. Once in, the hospital shows a message that a specific
program is needed to finish the job (name TBD). The player can't finish
without it.

Step 4, get the program. The player searches the internet (existing browser
and search engine in the game) and finds a download for the program.

Step 5, download over time. The download takes a whole night, or longer.
- The player has to leave the PC on overnight so the download can finish.
- The download finishes the following day. Some downloads take days.
- Requirement (from the owner): allow the player to keep the PC on overnight.
  This needs a rule for what happens to the shift end and the clock-out (see
  open questions).

Step 6, install and connect. The player installs the program, connects again,
and is now inside the hospital system. From here the player is committing a
crime.

### PP3: what the player can do inside

Uses of the access:
- Sell data (high reward, high risk).
- Bribe (lower reward, lower risk), e.g. get a visitor through without the
  ID check.

Downloads and other long tasks take real in-game time, some taking days.

### PP4: detection and punishment (to design)

Requirements from the owner:
- Random punishment for doing the crime.
- The hospital should work out what is going on and show signs of it
  (in-game warnings the player can notice and react to).

Ideas to choose from (not decided):
- Hospital IT notices the new login and sends a message or call to Dale.
- Logs in the PC show "unrecognised connection from the car park."
- Dale asks about the PC, or a second auditor visits.
- Random checks: the terminal asks a question the player must answer or it
  logs them out.
- Escalation: each detection raises a suspicion level; at a threshold the
  hospital cuts the link or reports the car park.
