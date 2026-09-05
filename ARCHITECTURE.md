# Architecture

## The layers

Dependencies only ever point downwards.

```
  5. SCREENS    scenes/     what you see and click
  4. ACTORS     players/    who makes decisions
  3. NETWORK    net/        one match across two devices
  2. CORE       core/       pure logic, ZERO nodes, testable
  1. SERVICES   autoloads/  things that survive a scene change
```

The rules that hold it together:

- **The core cannot mention a single node type.** Not `Node`, not `Control`, not
  a scene name. That is why `tests/` can run headless with no plugin.
- **One coordinator.** `scenes/game/game.gd` knows all the others; nobody else
  knows more than its immediate neighbours.
- **Call downwards, emit upwards.** A child never reaches for its parent; it
  emits a signal and whoever cares listens.
- **Single source of truth.** The disc drawn in a slot is a copy of what
  `BoardState` holds, never a second place it is decided.
- **Base contract plus implementations.** `Player` → `HumanPlayer` /
  `BotPlayer` / `NetPlayer`. There is not one `if is_bot:` in the project.

## The folders

```
autoloads/    audio_manager   scene_switcher   ui_intro   ui_sounds   game_settings
core/         disc  move  board_state  game_rules  move_result  game_state
              game_config  difficulty_preset
players/      player  human_player  bot_player  net_player
net/          net_protocol  net_client  room_client  room_chat  net_settings
              online_match
scenes/       main_menu  setup  game  results  online_menu  room_lobby
              common (chat_panel, chat_dock, audio_settings)  background
resources/    themes  audio (bus layout)  difficulties (.tres)
assets/       audio  fonts  shaders (iris, RichTextEffects)  sprites
tests/        mini_test (~40 lines) + one suite per core file
```

## A move is one int

This is the decision the rest of the project is built on.

Pop Out has two kinds of turn, but `Move` flattens both into a single number:

```
  0..6    drop a disc into that column
  7..13   pop your disc out of the bottom of column (code - 7)
```

Everything above `core/` passes moves around as that int. A `Player` answers
`picked(code)`. The relay carries `code` and nothing else. The result is that
`players/`, `net/` and the entire online layer never learn this game has two
kinds of move — the only place they are told apart is one `if` in `game.gd`
choosing which animation to watch, and the rules themselves.

## The board's coordinates

Row 0 is the **top** row, so a slot's index is its place in the grid on screen,
left to right and top to bottom:

```
   0  1  2  3  4  5  6      <- discs come in here
   7  8  9 10 11 12 13
  14 15 16 17 18 19 20
  21 22 23 24 25 26 27
  28 29 30 31 32 33 34
  35 36 37 38 39 40 41      <- and Pop Out takes them out here
```

The one invariant everything leans on: **a column is always packed against the
bottom.** There is never a hole under a disc. Both moves preserve it, which is
why `height_of()` can simply count.

## One turn, end to end

```
  game.gd     board.show_moves(state)          only the legal buttons light up
              player.request_pick(state)       deferred, or the await would miss it
  player      picked(code)                     a click, a bot, or a confirm
  game.gd     state.play(code) -> MoveResult   the only place rules are applied
              board.drop(result)               awaited
              or board.pop(result)             awaited
              result.ends_round()?             win / own goal / shared / draw
              hud.set_turn(...)                and round again
```

Online it is the identical loop. A `NetPlayer` answers `picked()` with a move
the referee confirmed instead of one it chose, and nothing else changes.

## How a round can end

Four ways, and two of them only exist because of Pop Out.

| `MoveResult` says | What happened |
|---|---|
| `is_win()` | The mover completed a four. The ordinary way. |
| `is_own_goal()` | The mover popped a column and the four that landed was the **other** player's. The round goes to them. |
| `is_shared_win()` | One pop completed a four for both colours. Nobody scores. |
| `is_draw` | The next player has no legal move at all. Not the same as a full board. |

## The network

```
  scenes/room_lobby  ->  OnlineMatch.broadcast_start(config)
  Rooms.send(payload)    ->  Net.relay.rpc_id(1, payload)   ->  the relay
                                                            ->  everyone else
```

`net_protocol.gd` is the wire contract, shared verbatim with the relay and with
the other games on it. `net_client.gd` owns the socket, `room_client.gd` owns
the lobby, and neither has heard of a board. `net_settings.gd` carries
`game_id = "connect4"`, which is the entire difference between this game's room
list and any other game's on the same server.

`online_match.gd` is the only file in `net/` that belongs to this game, and even
it only ever handles move codes.

## Tests

`tests/mini_test.gd` is about forty lines and needs no plugin. Add a suite by
extending it, writing methods that start with `test_`, and listing the file in
`tests/test_runner.gd`.

538 checks at the time of writing, including a genuine drawn board (searched
for, not guessed at) and a round-trip over every one of the fourteen move codes.

## The missions

`players/bot_player.gd` is the file left to write. The rest of the project is
finished and wired around it: the turn loop asks the bot for a move exactly as
it asks a person, and the file currently answers at random, so the game is
playable from the first run.

| # | Function | What it unlocks |
|---|---|---|
| 1 | `choose_move()` | The bot picks a move on purpose. Wire it to `_search()` and it stops being random. |
| 2 | `_search()` | Alpha-beta minimax. Watch out: a pop can be undone by popping the same column back, so only `depth` stops the search walking in a circle. |
| 3 | `_evaluate()` | Judging a position with no depth left. Lines still open to one side, and whether they are resting on discs the opponent could pop out from under. |
| 4 | `_ordered_moves()` | Middle columns first, so alpha-beta has something good to prune against. Pure speed — the bot plays the same, just deeper. |

Each one is documented in the file itself: the steps in prose, the trap left
unsolved, and the Godot vocabulary to go and look up.

After mission 1 the bot beats a careless human. After mission 3 it stops walking
into fours. After mission 4 it can afford the depth to see a pop coming.

## Reused verbatim from Tic Tac Toe

Copied without a line changing, which is what the shared working method is for:

`audio_manager.gd`, `scene_switcher.gd`, `ui_intro.gd`, `ui_sounds.gd`,
`net_protocol.gd`, `net_client.gd`, `room_client.gd`, `room_chat.gd`,
`chat_panel.gd`, `chat_dock.gd`, `audio_settings.gd`, `mini_test.gd`,
`difficulty_preset.gd`, the theme, the fonts, the sounds, the iris shader and
the `RichTextEffect` scripts.
