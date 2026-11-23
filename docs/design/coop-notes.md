# Co-op design log

Status: co-op is built (see "What's built" at the bottom). Started as the design log written before it existed. **Everything from night three onwards must be built
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

## More decisions (agreed 23 Nov 2026, co-op open-questions pass)

- **Two players at the window:** anyone can act (inspect the ID card and plate, press the barrier
  buttons, log plates). Only the **talker** (whoever opened the window / took the ID first) picks dialog
  options.
- **Talker disconnects mid-conversation:** the **safe option is chosen automatically, then the
  conversation is free**: the next player to interact with that visitor becomes the talker.
- **Splitting up:** on night three the guards are **free to split up**: anyone can leave the hut and walk
  the lot, others can stay on the PC. Dialog works wherever the talker is.
- **The one PC:** one user at a time. **Whoever started using it first owns it until they free it up**
  (sit back / shut down); every other player can see the screen (on the CRT / a spectator view) but not
  type. Applies to GateLog, the browser and the hospital hacking side hustle.
- **Phone:** everyone hears it; **the first player to click it answers** and owns the replies in that call.
- **End of night:** **everyone sees the same report; only the host** presses NEXT NIGHT and buys upgrades.
- **Saves:** the **host's save only** holds the night, coins and upgrades; friends keep nothing.
- **A player leaves mid-night:** their **guard disappears**; anything they owned (the PC, a conversation,
  the phone) is freed.
- **Difficulty:** **scales with player count**: more arrivals and a faster-rising risk meter, so four
  players are still busy.
- **Subtitles and voices:** **everyone sees the subtitles; the voice babble fades with distance** from the
  speaker. Each player has their own voice volume.

## More decisions (agreed 23 Nov 2026, build pass)

- **Unlock:** co-op unlocks when night two is finished (the "CO-OP UNLOCKED" pop-up); night three is the
  first co-op night.
- **MULTIPLAYER on the main menu** for everyone. A player who hasn't unlocked it can still HOST: that
  starts a **new save at night three** in a slot they pick (their other saves are left alone). Joining a
  friend needs nothing unlocked.
- **Joining:** type the host's **IP address and port** (default 24680, UDP). No relay server, so over the
  internet the host forwards the port (or uses Hamachi / ZeroTier).
- **Late joiners:** **lobby only.** Once the host presses START, new connections are refused.
- **Host migration:** none. If the host leaves, everyone goes back to the title screen.

## Still open

- Exactly how many more arrivals per extra player (the risk meter already rises 25% faster per extra
  guard; numbers to be tuned).
- What the "spectator" view of the PC looks like for players who are not using it (a second screen
  texture on the CRT, or the player is shown the screen when they look at it). For now they can't lean
  in and are told who is using it.

## What's built

- `scripts/autoload/net.gd` (`Net`): ENet host/join/leave, the lobby (player id -> guard 0-3, so P1-P4
  and their colours), lobby-only joining, version check, `send` (host -> everyone), `send_to`,
  `request` (client -> host), head positions (`send_pose`), and who has finished loading (`ready_ids`).
- `scripts/ui/title_screen.gd`: MULTIPLAYER -> HOST (from an unlocked save, or a new game at night
  three) / JOIN (IP + port, remembered in settings) -> LOBBY (IP and port to give friends, the guards,
  START for the host).
- `scripts/net/coop.gd` (added by `main.gd` in a co-op game): every guard's spot in the booth (P1 in the
  chair, the others standing round it), the other guards' models moving with their heads, and the
  host's once-a-second sync (clock, weather, cars, risk, coins, who is on the PC). Relays HUD messages.
- `scripts/story/shift.gd`: the host runs the night as before; every action another guard takes comes
  in through `remote_action(from, what, args)` (phone, window, barrier, ID card and the decision,
  dialog choice, GateLog plate, PC, hospital gateway). A guest's story doesn't run its own night: it
  shows what the host sends (`guest_event`). Personal messages go to one player (`_tell`,
  `hud.notify_local`). At 07:00 the host clocks out for the team; everyone sees the same report, and
  only the host presses NEXT NIGHT (the guests' report is view-only), after which everyone loads the next
  night together.
- `scripts/story/hack.gd`: on a guest, `remote = true`: actions go to the host's gateway, the state
  comes back, and finished downloads are saved on everyone's PC.
- Testing: `--autoplay=coop_host --host=2` and `--autoplay --join=127.0.0.1` (`scripts/net/coop_bot.gd`)
  play a whole night where the guest does all the work; both print a RESULT line.
