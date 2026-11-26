# Core loop: staying alive

Status: design log. Agreed with the owner. Add decisions here as they're made, so a build
session can work from this file alone.

## The core idea

The player is trying to stay alive. The job pays the bills (rent, food, heat) if you play
it straight, but it gets harder over time. Hacking and stealing bring in most of the money
but risk getting caught. The player chooses how far to go on each side.

## Survival meters

- Three bills: **heat, food, rent**. More bills may be added later (the player has to fund
  them to do other things). For now, these three.
- Each has a daily cost. Heat, food and rent all need paying.
- Bank: Dave starts with **8 coins**, which covers everything for the first two days.
- After day two the money runs low and the player must earn it. The lore decides how far
  the story goes before the cost bites harder.

## Legal income

- A legal night pays the bills at a slow rate. An honest player can survive, but not
  comfortably.
- The legal side gets easier with skill and experience (the player gets faster and better
  at the job).
- It can still fail if the player makes mistakes, so an honest run is not guaranteed.

## Reports (customers and Dale)

- A customer who is wronged (e.g. a car boot opened for no reason) reports it to Dale.
- Reporting thresholds (starting point):
  - **5 reports:** Dave is suspicious. Dale mentions it and asks the player to keep an eye out.
  - **7 reports:** Dale thinks it's Dave. Dale makes it very clear it has to stop.
  - **10 reports:** Dave is fired. **Game over.**
- Dale says he has footage, which is the warning before the firing.
- **Forgiveness:** one report is forgiven every two days.
- A player can avoid reports (exact methods still to design).

## Hacking and stealing: the risk meter

- Hacking and stealing raise a **risk meter**. At **100%** Dave is caught by the police:
  **game over**.
- Each action adds to the meter. Some actions have their own values (a big hack adds more
  than a small one).
- The meter goes down over time: about **20% a day** while Dave is not doing anything
  risky.
- **Protection** reduces the risk of big hacks and can stop a big hack from instantly
  getting Dave caught:
  - **Small hacks:** a VPN helps.
  - **Big hacks:** a separate PC is needed.
  - Other ideas to consider: IP hiding, fake names, or a contact who covers for Dave.
- **Big hacks** can catch Dave instantly if he isn't protected.

## Caught by police

- Police walk through the lot. If they catch Dave red-handed, it's **game over**.
- A caught player restarts the night, but **suspicion is kept**: the reports and the
  risk from before still count.

## Suspicion

- Suspicion (the reports above) is what Dale uses to decide whether Dave is the one doing
  it. Suspicion carries from one night to the next. It takes time to reduce.

## Income and quota (multiplayer)

- In multiplayer the money is shared across the guards.
- Starting figure: **4 coins a day** needed for the team. It gets harder every **3 days**.
- Co-op shows the quota. The exact effect of missing it is to be decided.

## Big hits and missions

- Hacking and stealing can bring in big hits and missions, which are how the player makes
  big money.
- The player can learn about NPCs (who has a guitar in their boot, for example). That lets
  them target things instead of stealing from everyone, which lowers risk.

## Open questions

- Exact daily cost of heat, food and rent, and how they're shown.
- How the lore sets the pace of the money getting harder.
- What happens when the team misses the co-op quota.
- Exact risk value for each small and big action, and how big hacks are told apart.
- How the player finds out about NPCs (dialog, the PC, or both).
