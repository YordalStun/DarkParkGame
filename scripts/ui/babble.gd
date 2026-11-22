extends RefCounted
## Simlish-style speech: nobody's lines are voiced, so each subtitle line is turned into a burst of
## synthesised babble instead. One syllable per ~3 letters, a vowel from two formant filters, an
## optional hiss or pop in front, a pitch that drifts, pauses at commas and full stops, and a
## rising end on questions. The same speaker always gets the same voice pitch.

const RATE := 11025
const VOWELS := [
	Vector2(730, 1090), Vector2(270, 2290), Vector2(300, 870), Vector2(530, 1840),
	Vector2(660, 1720), Vector2(400, 1000), Vector2(570, 840), Vector2(440, 1020),
]
static var _cache := {}


static func make(text: String, speaker: String) -> AudioStreamWAV:
	var key := speaker + "|" + text
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var base := 100.0 + float(absi(hash(speaker)) % 1000) / 1000.0 * 115.0
	var question := text.strip_edges().ends_with("?")

	# 1. Plan the syllables and pauses.
	var segs: Array = []   # {pause} or {dur, f0a, f0b, vowel, cons, amp}
	var drift := 0.0
	var words := text.split(" ", false)
	for wi in words.size():
		var w: String = words[wi]
		var core := w
		for p in [",", ".", "?", "!", "-", "'", "\"", "(", ")", ";", ":"]:
			core = core.replace(p, "")
		var n := maxi(1, int(ceil(core.length() / 3.0)))
		for si in n:
			drift = clampf(drift + rng.randf_range(-0.1, 0.1), -0.25, 0.25)
			var f := base * (1.0 + drift)
			segs.append({"dur": rng.randf_range(0.1, 0.17), "f0a": f * rng.randf_range(0.95, 1.1), "f0b": f * rng.randf_range(0.85, 1.05),
				"vowel": rng.randi() % VOWELS.size(), "cons": rng.randi() % 3, "amp": rng.randf_range(0.65, 1.0)})
		var last: String = w.substr(w.length() - 1)
		if last == "," or last == ";" or last == ":":
			segs.append({"pause": 0.16})
		elif last == "." or last == "!" or last == "?":
			segs.append({"pause": 0.3})
		else:
			segs.append({"pause": rng.randf_range(0.02, 0.06)})
	if question and not segs.is_empty():
		for i in range(segs.size() - 1, -1, -1):
			if segs[i].has("dur"):
				segs[i].f0b = segs[i].f0a * 1.45
				break

	# 2. Render.
	var total := 0.0
	for s in segs:
		total += s.get("dur", s.get("pause", 0.0))
	var count := int(total * RATE) + 1
	var voiced := PackedFloat32Array()
	voiced.resize(count)
	var hiss := PackedFloat32Array()
	hiss.resize(count)
	var pos := 0
	var phase := 0.0
	var prev_n := 0.0
	for s in segs:
		if s.has("pause"):
			pos += int(s.pause * RATE)
			continue
		var len_s := int(s.dur * RATE)
		var vw: Vector2 = VOWELS[s.vowel]
		var f1 := vw.x * rng.randf_range(0.95, 1.05)
		var f2 := vw.y * rng.randf_range(0.95, 1.05)
		var r1 := exp(-PI * 90.0 / RATE)
		var r2 := exp(-PI * 140.0 / RATE)
		var a1 := 2.0 * r1 * cos(TAU * f1 / RATE)
		var a2 := 2.0 * r2 * cos(TAU * f2 / RATE)
		var y1a := 0.0
		var y1b := 0.0
		var y2a := 0.0
		var y2b := 0.0
		var cons_len := int((0.05 if s.cons == 1 else 0.025) * RATE) if s.cons > 0 else 0
		for i in len_s:
			var t := float(i) / len_s
			var env: float = minf(1.0, t * 9.0) * minf(1.0, (1.0 - t) * 5.0) * s.amp
			phase += lerpf(s.f0a, s.f0b, t) / RATE
			phase -= floorf(phase)
			var src := phase * 2.0 - 1.0
			var o1 := (1.0 - r1) * src + a1 * y1a - r1 * r1 * y1b
			y1b = y1a
			y1a = o1
			var o2 := (1.0 - r2) * src + a2 * y2a - r2 * r2 * y2b
			y2b = y2a
			y2a = o2
			var idx := pos + i
			if idx >= count:
				break
			voiced[idx] = (o1 + 0.6 * o2) * env
			if i < cons_len:
				var nz := rng.randf_range(-1.0, 1.0)
				hiss[idx] = (nz - prev_n) * (1.0 - float(i) / cons_len) * (0.6 if s.cons == 1 else 1.0) * s.amp
				prev_n = nz
		pos += len_s

	# 3. Mix, normalise, to 16-bit.
	var peak := 0.0001
	for v in voiced:
		peak = maxf(peak, absf(v))
	var hpeak := 0.0001
	for v in hiss:
		hpeak = maxf(hpeak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var v := voiced[i] / peak * 0.55 + hiss[i] / hpeak * 0.2
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	_cache[key] = wav
	return wav
