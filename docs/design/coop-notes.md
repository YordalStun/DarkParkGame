# Co-op design log

Status: design log, written before co-op exists. **Everything from night three onwards must be built
so it can work with co-op (up to 4 players).** Add decisions here as they are agreed, with the date,
so the multiplayer build session can work from this file without the original chat.

## Rules for building night three onwards

1. **The host runs the story.** One player hosts; the host's game owns the truth (story flags, the
   shared coins, who is in which conversation, the clock). Everyone else sends what they *do* to the host
   and shows what the host says happened.
2. **State is plain data.** Conversations, effects, flags and results are dictionaries/arrays of strings
   and numbers (no Callables or node references in anything that must be sent or saved).
3. **One entry point per action.** An action a player can take (answer a dialog option, open the window,
   take an ID, answer the phone...) goes through one function that takes the player's id
   (`submit_choice(index, from_player)`, `_on_phone(from_player)`, `_claim_talker(car, player_id)`).
   Locally the id is `story.local_player_id` (1, the host). In co-op a client's input becomes an RPC to
   the host, which calls the same function with that client's id and checks they are allowed.
4. **Shared outcome.** One team pot of coins and one end-of-night report (see decisions).
5. **Same view for everyone.** Dialog options, objectives and the report are the same for all players.
6. **Solo must keep working.** With one player (id 1) nothing changes.

## Decisions (agreed 23 Nov 2026)

### Selectable dialog (night three on)
- Lines show 2-4 numbered options under the speaker; click or keys 1-4.
- **Who answers:** whoever is talking. For a window visitor that is **whoever opened the window / took the
  ID first**; for a phone call, whoever answered it; on patrol, the player who walked up to the NPC. The
  others see the options and who is choosing ("P2 is choosing a reply...") but can't pick.
- **Timer on every choice:** 20 seconds by default (a node can set its own, 0 = none). When it runs out the
  **safe option is picked for them, and it is shown clearly** ("No answer - the safe option was chosen for
  you"). Every option list has exactly one `"safe": true` option, which is always available.
- **Same options for everyone.** Options can be hidden behind a shared flag (`requires`), e.g. a clue that
  any player learned; they never depend on which player is looking.
- **Shared result.** Coins, risk and clues from conversations go to the team, not to one player.
- **Where:** the side window, the desk phone and out on patrol all use the same conversation format.

### Connecting
- **Host plus join by code or IP** (Godot's built-in multiplayer). Not Steam for now.

## How the dialog system maps onto co-op (already built)

- `scripts/story/dialog.gd` (host only) plays a conversation and emits `options_ready`, `tick`, `chosen`,
  `finished`. For clients, forward these as RPCs and show them with the same HUD calls
  (`hud.show_choices`, `hud.update_choice_time`, `hud.hide_choices`, `hud.say`, `hud.say_player`).
- A client's click/key calls `hud.choice_picked` -> RPC to host -> `dialog.submit_choice(index, player_id)`.
  Answers from anyone but `talker`, outside a question, or with a bad index are ignored (tested).
- Effects (`flag`, `coins`, `risk`, `note`) are applied once, on the host, by `story._apply_effect`.
  Clients get the new `flags`/`dialog_coins`/`risk` from the host.
- `story.player_ids` and `story.local_player_id` exist; the `TODO(coop)` comments in `shift.gd` mark the
  places that need the real player id.
- `tools/dialog_test.gd` checks the rules; `--dialog=window|phone|patrol` plays a sample in the booth.

## Open questions to settle before building co-op

- Two players at the window at once: can the second player also click the car / ID card, or only watch?
- If the talker disconnects mid-conversation, who takes over (host, or the safe option)?
- Do all four players share one booth, or can they split up on night three's patrols? (Dialog already
  handles both, but the camera, the CCTV and the PC would need deciding.)
- One PC: who uses it when two players want it (the hospital hacking side hustle, GateLog)?
- Who hears the phone and answers it? (Everyone hears it; the first to click answers.)
- How is the end report shown: the same screen for everyone, who clicks NEXT NIGHT (host only?)
- Save slots: the host's save only, with clients joining a night in progress?
- Voices/babble and subtitles: each player hears their own mix; subtitles for everyone.
- What happens if a player leaves mid-night (their guard walks off, or stays as an NPC)?
- Difficulty: do arrivals or the risk meter scale with the number of players?
