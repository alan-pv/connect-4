@tool
extends RichTextEffect
class_name RTEWaveRainbow

var bbcode := "wr"  ## Usage: [wr]text[/wr]

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amp: float = char_fx.env.get("amp", 5.0)
	var speed: float = char_fx.env.get("speed", 3.0)
	var freq: float = char_fx.env.get("freq", 0.3)
	var rspeed: float = char_fx.env.get("rspeed", 1.0)

	var t := char_fx.elapsed_time
	var idx := float(char_fx.range.x)

	# Wave: each letter is a little further along the same sine.
	char_fx.offset.y = sin(t * speed + idx * freq) * amp

	# Rainbow: the same offset again, this time around the hue circle.
	var hue := fmod(t * rspeed + idx * 0.08, 1.0)
	char_fx.color = Color.from_hsv(hue, 0.75, 1.0)

	return true
