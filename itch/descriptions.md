# itch.io — Connect 4: Pop Out

## Short description (the one-liner under the title)

Four in a row, with the twist that lets you pull a disc back out from the
bottom and drop the whole column.

### Alternates, if the above runs long

- Four in a row, plus the move that takes a disc back out and collapses the column.
- Connect 4 with Pop Out: drop discs in, or pull your own out from underneath.

---

## Long description (paste as HTML into the itch editor)

```html
<h2>Connect 4 &mdash; Pop Out</h2>
<p><em>Four in a row, and the move that takes one back out.</em></p>
<p>The classic game only ever adds discs. Pop Out lets a turn be spent the other way: instead of dropping one in, you pull one of <strong>your own</strong> discs out of the bottom row, and everything stacked above it falls a slot. One column collapsing settles up to six slots at once, so a single pop can finish several lines of four &mdash; and they are not always yours. Pull a disc out from under your opponent's three and you hand them the round. If the same move completes a four for both colours, nobody takes it. A full board stops being the end of anything, because there are still discs to pull out from underneath. Pop Out is a toggle: turn it off and this is the game everybody already knows.</p>
<hr>
<h4>Against the bot</h4>
<p>It searches with alpha-beta minimax over both kinds of move, so it will pop a column open when that is the strongest thing on the board rather than only stacking. Its skill is a value between 0 and 1 rather than a label: on <strong>Easy</strong> it plays most moves at random, on <strong>Normal</strong> it thinks about most of them, and on <strong>Hard</strong> it searches every line it can reach and does not blunder. A harder setting means an opponent that looks further ahead, not a bigger board.</p>
<h4>On one device</h4>
<p>Two players taking turns at the same screen, first to as many rounds as you agree on, alternating who opens so nobody keeps the first-move advantage. The buttons above the board drop a disc in; the ones below pull one out, and they only light up over a column whose bottom disc is yours. Hovering a drop button shows you where the disc would land.</p>
<h4>Online</h4>
<p>Pick the name the others will see, look through the open rooms, and join one or create your own with a password if you want it closed. The host sets the mode and the length of the match, and starts once everybody is ready. Rooms run on a small relay that never learns what a board is &mdash; one player in each room referees, and every move is checked there before it happens on anybody's screen. There is a chat in the corner of the room, of the match and of the results, and if your opponent walks off a bot takes their seat so the game carries on.<br></p>
```
