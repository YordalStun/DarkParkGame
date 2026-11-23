# Night three: moving about and leaving the hut

Status: design log (draft, agreed parts marked). Co-op is enabled from night three, so
every rule here must work with 1-4 players. See docs/design/coop-notes.md for the co-op rules.

## What exists now (to build from)

- The booth is first person. Walking (WASD, mouse look) only works inside the booth,
  and only at the end of the shift (`scripts/player/desk_camera.gd`, `walk_bounds`).
- Leaving the booth is only wired at clock-out (`shift.gd` `_leave_booth`).
- Night two's unlock says: "From night three you'll be leaving the hut: boot checks,
  patrols and more. A second guard can join you for those nights."
- The patrol route is already written in the PC's My Documents (`PATROL.TXT`):
  - 00:00 Gate, then Row A (left to right)
  - 00:20 Row B, check the van with the flat tyre
  - 00:40 Payphone, make sure the handset is back on its hook
  - 01:00 Row C (do this one quickly)
  - 01:15 Back to booth, sign the logbook
- Dale's mail says: patrol at midnight and 03:00, take the torch.
- Dialog already covers "out on patrol": a stranger in the lot, with options that
  change once the player knows the dog's name (`scripts/story/dialogs/samples.gd`).

## Proposed design (for agreement)

### Leaving the hut
- From night three the guard can walk out of the booth through the door at any time.
- Outside, the guard walks the lot in first person, on the same WASD and mouse
  controls as the booth. The lot is a new walkable area (gate, Row A-C, payphone).
- Dave can leave whenever he likes. While he is out, cars at the window wait and
  sound their horn, and each waiting car adds risk.

### Patrols
- Patrols are scheduled checkpoints from PATROL.TXT. Each checkpoint has a time window
  and a place. Missing a checkpoint, or doing it late, adds risk and logs it in the
  logbook.
- The patrol is the guard's job, so the hospital side hustle (the PC) is limited while
  on patrol: the PC can't be used until the guard is back in the booth.

### Boot checks
- A boot check is a short scene at the barrier: a random car stops, the guard walks
  round it and looks in the boot, then ticks the form. Finds are rare. What a find
  means is not decided yet.

### Second guard (co-op)
- Night three allows a second guard to join. Both guards can be in the lot at the
  same time. The booth can be empty, so cars need someone at the window.
- Dialog for patrols uses the same format; whoever walked up to the NPC answers
  (coop-notes.md, decision "Who answers").

## Decisions (answered)

1. Leaving the booth: any time, but cars wait. Dave can walk out whenever he likes.
   Cars at the window honk and wait, and each waiting car adds risk.
2. Boot checks: some cars at the barrier. A random car stops, Dave walks round,
   looks in the boot and ticks the form. Finds are rare (a small risk and reward).
3. Co-op: both guards can patrol the lot at the same time. The booth can be empty,
   so cars need someone at the window.
4. Missed patrol checkpoint: a logbook entry, and Dale rings.

## Open questions

- What a boot-check find is (contraband, a sign the visitor is not who the card says).
- How much risk a waiting car adds, and how long a car waits before it leaves.
