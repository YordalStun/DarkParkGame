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
  speaker (click, or keys 1-4).

## Open questions

- What happens when Dave is caught.
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
