extends Node
## Voice — placeholder gibberish voice from the July 4 session. To be replaced by speech with
## LLM-based impersonated narration (author, 2026-10-23; beads persistint-game-zkk).
## Builds a short PCM16 wav at runtime from the text's letters: each letter maps to
## a pitched blip; per-character base pitch gives each caste/NPC its own voice.
## No models, no assets — pure synthesis, works in HTML5 export.

const RATE := 22050
const MAX_LETTERS := 12
const BLIP_SECONDS := 0.055
const GAP_SECONDS := 0.018

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)


func speak(text: String, base_pitch := 1.0) -> void:
	var data := _synthesize(text, base_pitch)
	if data.is_empty():
		return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_player.stream = wav
	_player.play()


func _synthesize(text: String, base_pitch: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	var letters := 0
	for ch: String in text.to_lower():
		if letters >= MAX_LETTERS:
			break
		var c := ch.unicode_at(0)
		if c < 97 or c > 122:
			continue
		letters += 1
		# Letter → frequency; cute register lives in the 300–900 Hz band.
		var freq := (330.0 + float(c - 97) * 21.0) * base_pitch * randf_range(0.96, 1.04)
		_append_blip(bytes, freq)
		_append_silence(bytes, GAP_SECONDS)
	return bytes


func _append_blip(bytes: PackedByteArray, freq: float) -> void:
	var n := int(BLIP_SECONDS * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := 1.0 - float(i) / float(n)
		# Fundamental + a touch of octave, softly clipped for a chirpy timbre.
		var s := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t)
		s = clampf(s * 1.4, -1.0, 1.0) * env * 0.32
		_append_sample(bytes, s)


func _append_silence(bytes: PackedByteArray, seconds: float) -> void:
	for i in int(seconds * RATE):
		_append_sample(bytes, 0.0)


func _append_sample(bytes: PackedByteArray, s: float) -> void:
	var v := int(s * 32767.0)
	bytes.append(v & 0xFF)
	bytes.append((v >> 8) & 0xFF)
