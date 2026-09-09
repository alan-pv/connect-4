# Connect 4 — Pop Out

Four in a row, with the twist that lets you take a disc back out.

Built in Godot 4.7. Two players on one device, against a bot, or against
somebody else over the internet.

## The twist

The classic game only ever adds discs. Pop Out lets a turn be spent the other
way: instead of dropping one in, you pull one of **your own** discs out of the
bottom row, and everything stacked above it falls a slot.

That single extra move changes the shape of the whole game.

- A column collapsing settles up to six slots at once. One pop can complete
  several lines of four.
- The lines it completes are not always yours. Pop a disc out from under your
  opponent's three and you hand them the round.
- If the same move completes a four for both colours, nobody takes it.
- A full board is no longer the end of anything: there are still discs to pull
  out from underneath.

Pop Out is a toggle. Turn it off and this is the game everybody already knows.

## Playing

The buttons above the board drop a disc in. The buttons below pull one out —
they only light up over a column whose bottom disc is yours. Hovering a drop
button shows you where the disc would land.

Whoever wins enough rounds takes the match. Players take turns opening, so
nobody keeps the first-move advantage.

## Online

Rooms are hosted on a small relay that never learns what a board is: every
game-specific message rides inside an opaque payload. One player in each room
referees — they hold the only copy of the rules that counts, and every move is
checked there before it happens on anybody's screen.

If somebody leaves mid-match a bot takes their seat and the match carries on.
There is a chat in the corner of the lobby, the match and the results screen,
and it remembers what was said while you walk between them.

## Running it

Open the folder in Godot 4.7 and press F5.

The core has tests, and they need no plugin:

```
godot --headless --script res://tests/run_tests.gd
```

or open `tests/tests.tscn` in the editor and press F6.

## Against the bot

The bot searches with alpha-beta minimax over both kinds of move, so it will
pop a column open when that is the strongest thing on the board. Its `skill` is
a value between 0 and 1 rather than a label: at the low end it plays most moves
at random, at the high end it searches every line it can reach.

## Credits

- **Music** — PizzaDoggy
- **Sound effects** — *(pending: author to be credited)*
- **Fonts** — [Chewy](https://fonts.google.com/specimen/Chewy) and
  [Fredoka](https://fonts.google.com/specimen/Fredoka), SIL Open Font License
- **Engine** — [Godot](https://godotengine.org) 4.7

## License

The code is MIT, see `LICENSE`. The audio and fonts are the property of their
respective authors and are covered by their own terms, not by the MIT licence.
