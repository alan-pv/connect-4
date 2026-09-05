@tool
extends RichTextEffect
class_name RTEJump
## RichTextLabel effect: every letter bounces on its own cycle, offset from
## the one before it, so the word reads as a wave rather than as one hop. Each
## letter picks up an accent colour at the top of its arc.
##
## Add an instance of this script to the label's "Custom Effects", turn
## bbcode_enabled on, and write [jump]TIC TAC TOE[/jump]. Every parameter below
## can be overridden in the tag:
##
##     [jump amp=16 speed=3 stagger=0.18 pause=0.35 glow=1 1 0.4 glow_strength=0.6]

var bbcode := "jump"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amp: float = char_fx.env.get("amp", 14.0)
	var speed: float = char_fx.env.get("speed", 1.0)
	var stagger: float = char_fx.env.get("stagger", 0.25)
	var pause_ratio: float = char_fx.env.get("pause", 0.35)
	var glow_color: Color = char_fx.env.get("glow", Color("b4a629ff"))
	## 0 leaves the letter its own colour, 1 paints it fully at the top of the arc.
	var glow_strength: float = char_fx.env.get("glow_strength", 0.6)

	var idx := float(char_fx.range.x)
	var t := char_fx.elapsed_time * speed - idx * stagger
	var phase := fposmod(t, 1.0)

	var active_end := 1.0 - pause_ratio
	var arc := 0.0
	if phase < active_end and active_end > 0.0:
		var active_phase := phase / active_end
		# A parabola: on the ground at both ends of the hop, fully up in the middle.
		arc = 4.0 * active_phase * (1.0 - active_phase)

	char_fx.offset.y -= arc * amp

	# The base colour is whatever already arrived — a wrapping [color=...], or
	# white — mixed towards the glow by how high the letter is.
	var base_color := char_fx.color
	char_fx.color = base_color.lerp(glow_color, arc * glow_strength)

	return true
