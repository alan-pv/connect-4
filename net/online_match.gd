class_name OnlineMatch
extends Node

## The Connect 4 half of the network: one match, refereed by the host and
## replayed identically by the other player.
##
## Above it, game.gd only ever sees Players emitting picked(), so the turn loop
## is the same code offline and online. Below it, Rooms only ever sees opaque
## dictionaries, so the relay never learns what a board is.
##
## The whole networked state of a match is the ordered list of confirmed move
## codes. Whose turn it is, what the score is and who opens the next round,
## every client works out for itself from (config, moves): both are transmitted
## explicitly and nobody decides anything on their own.
##
## That a Pop Out turn is two different kinds of move changes nothing here. A
## move is one int either way — see Move — so this file never learns that
## popping exists.


## Something worth putting on the HUD for a moment.
signal message(text: String)

## The match cannot go on: the referee left, or the connection died.
signal aborted(reason: String)

## Host -> everyone, from the lobby: the match being put together. A preview,
## resent whenever it changes, so nobody sits down blind.
const T_SETUP := "setup"
## Host -> everyone, from the lobby: the config of this match.
const T_START := "start"
## Referee -> everyone, while waiting: "are you in the game scene yet?"
const T_PING := "ping"
## Everyone -> referee: "I am, and I am listening."
const T_READY := "ready"
## The owner of a seat -> referee: "I would like to play this move."
const T_MOVE := "move"
## Referee -> everyone: "that move is played." The only message that moves a game.
const T_CONFIRM := "confirm"

## A guest that never answers a ping is a tab that was closed during the fade.
const READY_TIMEOUT := 20.0
const PING_SECONDS := 0.4

var config: GameConfig
var state: GameState

var is_referee: bool = false
var local_peer_id: int = 0
var referee_peer_id: int = 0

## Confirmed and not played yet. At most one: the referee refuses a second
## request for a turn it has already ruled on, so a player clicking twice
## quickly does not get two moves.
var confirmed_moves: Array[int] = []

## Which turn this client is playing. It is the same number on every client at
## the same point in the stream, so it is what a confirm is tagged with.
var turn_number: int = 0

## Confirms for a turn this client has not reached yet. A slow client can still
## be animating one move while the referee has already confirmed the next, and
## a pop takes noticeably longer to animate than a drop.
var _ahead: Array[Dictionary] = []

var _players: Array[NetPlayer] = []
var _waiting: NetPlayer = null
var _arrived: Array[int] = []
var _abandoned: Array[int] = []
var _finished: bool = false


func _ready() -> void:
	Net.payload_received.connect(_on_payload)
	Rooms.updated.connect(_on_room_updated)
	Rooms.left.connect(_on_room_left)


## Before the players exist: from here on the match knows who it is talking as.
func prepare(p_config: GameConfig) -> void:
	config = p_config
	local_peer_id = Net.my_peer_id
	referee_peer_id = _host_peer_id()
	is_referee = referee_peer_id != 0 and referee_peer_id == local_peer_id
	if referee_peer_id == 0:
		push_warning("Online match with no room behind it: nobody will referee.")


## After the state exists. Both seats are a NetPlayer on both clients; what
## changes is only who is allowed to ask for a move.
func bind_state(p_state: GameState, p_players: Array[Player]) -> void:
	state = p_state
	_players.clear()
	for player in p_players:
		if player is NetPlayer:
			_players.append(player as NetPlayer)
	if _players.size() != GameConfig.PLAYER_COUNT:
		push_error("An online match needs every seat to be a NetPlayer.")


func owns_seat(index: int) -> bool:
	return config.owner_of(index) == local_peer_id


## A seat a bot has taken over runs on the referee and nowhere else: it asks for
## its turn down the same path a person does, so it adds nothing to the protocol.
func referees_seat(index: int) -> bool:
	return is_referee and _abandoned.has(index)


## Nobody plays until every client is in the game scene and listening. The
## referee keeps asking instead of waiting for one announcement, because a
## "ready" sent while the referee was still fading out of the lobby is a message
## nobody was there to hear.
func wait_for_everyone() -> void:
	if not is_referee:
		_send({"t": T_READY})
		return

	var expected := _remote_peers()
	if expected.is_empty():
		return

	var waited := 0.0
	while waited < READY_TIMEOUT:
		_send({"t": T_PING})
		await get_tree().create_timer(PING_SECONDS).timeout
		if not is_inside_tree():
			return
		waited += PING_SECONDS
		if _everyone_arrived(expected):
			return

	message.emit("Someone never made it to the table.")


## A seat asks to play a move. On the referee that is a local call; anywhere
## else it is one message across the relay. Either way nothing is played yet.
func request(code: int) -> void:
	if _finished:
		return
	if is_referee:
		_judge(local_peer_id, code, turn_number)
	else:
		_send({"t": T_MOVE, "i": code, "k": turn_number})


## The seat whose turn it is announces it is listening. Answers with a move that
## is already waiting, or -1 to mean "hold on until one arrives".
func claim(player: NetPlayer) -> int:
	if not confirmed_moves.is_empty():
		return confirmed_moves.pop_front()
	_waiting = player
	return -1


## Closes the turn and opens the next one. Anything still queued belonged to the
## turn that just ended; anything tagged for the turn about to start was waiting
## for exactly this moment.
func end_turn() -> void:
	_waiting = null
	confirmed_moves.clear()
	turn_number += 1

	var still_ahead: Array[Dictionary] = []
	for entry in _ahead:
		if int(entry.get("k", -1)) == turn_number:
			confirmed_moves.append(int(entry.get("i", -1)))
		elif int(entry.get("k", -1)) > turn_number:
			still_ahead.append(entry)
	_ahead = still_ahead


## The match is over. The referee is the only one that tells the relay, and from
## that moment the room is a lobby again for everybody in it.
func finish() -> void:
	_finished = true
	end_turn()
	GameSettings.last_online_setup = config.to_dict()
	if is_referee:
		Rooms.end_match()


## True when this peer is allowed to play this move right now.
##
## The only guard on the whole match: the other client trusts whatever comes out
## of here, and every request off the network was written by a client that may
## have been modified to ask for anything at all. Popping a column that is not
## yours is exactly the kind of thing it stops, and `state.can_play()` already
## knows the rule — this only has to ask it.
func may_play(from_peer: int, code: int) -> bool:
	if state == null or state.is_match_over():
		return false
	# One move per turn. `state` only advances when the referee's own loop plays
	# the move, after the animation, so two quick clicks look identical to it:
	# what tells them apart is that the first is already confirmed and waiting.
	if not confirmed_moves.is_empty():
		return false

	var seat := state.current_player
	if config.owner_of(seat) != from_peer:
		return false
	return state.can_play(code)


## The referee's verdict on a request.
func _judge(from_peer: int, code: int, turn: int) -> void:
	if not is_referee or state == null:
		return
	# A request tagged with a turn that is over is a click that took the long
	# way round. Honouring it would play a move on a board its sender never saw.
	if turn != turn_number:
		return
	if not may_play(from_peer, code):
		return
	_send({"t": T_CONFIRM, "i": code, "k": turn_number})
	_accept(code, turn_number)


## A confirmed move, from the referee or from ourselves. It goes to the seat
## waiting for it, or into the queue until that seat asks — and if it is for a
## turn this client has not reached, it waits for that turn instead.
func _accept(code: int, turn: int) -> void:
	if state == null or not Move.is_code(code):
		return
	if turn > turn_number:
		_ahead.append({"k": turn, "i": code})
		return
	if turn < turn_number:
		push_warning("Dropped a confirm for turn %d while playing turn %d." % [turn, turn_number])
		return

	confirmed_moves.append(code)
	if _waiting == null:
		return
	var player := _waiting
	_waiting = null
	player.deliver(confirmed_moves.pop_front())


func _on_payload(from_id: int, payload: Dictionary) -> void:
	match str(payload.get("t", "")):
		T_PING:
			if not is_referee and from_id == referee_peer_id:
				_send({"t": T_READY})
		T_READY:
			if is_referee and not _arrived.has(from_id):
				_arrived.append(from_id)
		T_MOVE:
			_judge(from_id, int(payload.get("i", -1)), int(payload.get("k", -1)))
		T_CONFIRM:
			# Only the referee gets to move the game on. Anyone else claiming to
			# have confirmed something is a client that has been tampered with.
			if not is_referee and from_id == referee_peer_id:
				_accept(int(payload.get("i", -1)), int(payload.get("k", turn_number)))


## The relay resends the whole room whenever it changes, so a member who is no
## longer in the list is a player who left or dropped.
func _on_room_updated(_room: Dictionary) -> void:
	if state == null or _finished:
		return
	var present := Rooms.member_ids()
	for i in GameConfig.PLAYER_COUNT:
		var owner_id := config.owner_of(i)
		if owner_id == 0 or owner_id == local_peer_id or _abandoned.has(i):
			continue
		if not present.has(owner_id):
			_abandon(i)


## The seat stays, a bot moves into it. Only the referee changes anything: it
## takes ownership of the seat and grows a brain for it, and from then on that
## brain asks for moves down the very same path the person did. The other client
## keeps replaying confirms and never notices the difference.
func _abandon(seat: int) -> void:
	_abandoned.append(seat)
	message.emit("%s left. A bot takes over." % config.player_names[seat])
	if not is_referee:
		return
	config.peer_ids[seat] = local_peer_id
	if seat < _players.size():
		_players[seat].take_over()


## The room is gone. Without the referee there is no rules engine, so the match
## stops here rather than limping on out of sync.
func _on_room_left(reason: String) -> void:
	if _finished:
		return
	_finished = true
	aborted.emit(reason)


## Host, from the lobby. The config travels whole: a client that built its own
## from the preview would be playing a different match.
static func broadcast_start(match_config: GameConfig) -> void:
	Rooms.send({"t": T_START, "config": match_config.to_dict()})
	GameSettings.start_online_game(match_config)


## Guest, from the lobby. Returns false when the payload is not a usable start,
## so the lobby can stay put instead of loading a broken match.
static func accept_start(payload: Dictionary) -> bool:
	if str(payload.get("t", "")) != T_START:
		return false
	var raw: Variant = payload.get("config", {})
	if not (raw is Dictionary):
		return false
	var match_config := GameConfig.from_dict(raw as Dictionary)
	if not match_config.is_valid():
		push_error("The host sent a match this build cannot play: %s"
			% match_config.validation_error())
		return false
	GameSettings.start_online_game(match_config)
	return true


func _send(payload: Dictionary) -> void:
	Rooms.send(payload)


func _host_peer_id() -> int:
	for member in Rooms.current.get("members", []):
		if member.get("host", false):
			return int(member.get("id", 0))
	return 0


## Everyone we are waiting for: one entry per device other than this one.
func _remote_peers() -> Array[int]:
	var peers: Array[int] = []
	for peer_id in config.peer_ids:
		if peer_id == 0 or peer_id == local_peer_id or peers.has(peer_id):
			continue
		peers.append(peer_id)
	return peers


func _everyone_arrived(expected: Array[int]) -> bool:
	for peer in expected:
		if not _arrived.has(peer):
			return false
	return true
