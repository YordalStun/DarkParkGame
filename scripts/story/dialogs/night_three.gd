extends RefCounted
## Night three (Sunday 15th October 1989): the regulars, each with their own conversation at the side
## window (dialog format: ../dialog.gd). No ward call tonight. Kevin Platt is on the printed list now,
## and Mick Doyle finally turns up, in the wrong car.
##
## NPC knowledge for the boots: Michael has a guitar in his (a gig after his shift), Dr Marsh's husband's
## camera bag is in hers. The hacking clue: Kevin's dog is called Biscuit (the hospital password).
##
## About six cars a night, from a rotating pool (docs/design/night-three-lore.md): Kevin always comes
## (the Biscuit clue), Doris comes after the ward rings to add her (the printed newsletter), and four
## more are drawn from POOL. Tom Baxter (Medical Records, the "dealer") is held back: he only turns
## up once the player has found the dealer note on the alarm car.

## The printed list (night two's, plus Kevin).
const LIST := [
	{"name": "ADEYEMI, Michael", "staff_no": "40388", "dept": "Porter", "reg": "C771 PFM"},
	{"name": "BAXTER, Tom", "staff_no": "40562", "dept": "Medical Records (Admin)", "reg": "A456 GNB"},
	{"name": "DOYLE, Mick", "staff_no": "40391", "dept": "Porter", "reg": "D501 NKA"},
	{"name": "LOWE, Janet", "staff_no": "40115", "dept": "Pharmacy", "reg": "D310 YXE"},
	{"name": "MARSH, Dr Helen", "staff_no": "31105", "dept": "Registrar - A&E", "reg": "F23 HLM"},
	{"name": "PIKE, Sandra", "staff_no": "40217", "dept": "Staff Nurse - Ward 7", "reg": "E412 KTV"},
	{"name": "PLATT, Kevin", "staff_no": "40612", "dept": "Porter", "reg": "B908 RWD"},
]

## Mick Doyle: on the list, but not in the car on it. Turn him away.
const MICK := {"name": "Mick Doyle", "role": "Porter", "dept": "Portering Services", "staff_no": "40391", "expires": "02 / 1991",
	"reg": "F882 LCV", "paint": Color(0.3, 0.32, 0.2), "style": "4x4", "skin": Color(0.86, 0.68, 0.56), "hair": Color(0.35, 0.22, 0.12),
	"shirt": Color(0.6, 0.6, 0.62), "moustache": true, "admit": false, "delay": 30.0,
	"greet": ["Evening. Mick Doyle. Back from the dead."],
	"ok": "Champion.", "drive": "Ta, pal.", "refused": "You're joking. It's my brother's! ...Fine. I'll walk.",
	"why": "His car (F882 LCV) wasn't the one on the list (D501 NKA). A different car doesn't come in."}


const POOL := ["Sandra Pike", "Michael Adeyemi", "Dr Helen Marsh", "Janet Lowe", "Mick Doyle"]
const FROM_POOL := 4


static func arrivals(night_one: Array) -> Array:
	var pool := POOL.duplicate()
	pool.shuffle()
	var tonight: Array = pool.slice(0, FROM_POOL) + ["Kevin Platt", "R. Kessler"]
	var out := []
	for p in night_one:
		var d: Dictionary = p.duplicate(true)
		if not tonight.has(d.name):
			continue
		match d.name:
			"Sandra Pike":
				d.admit = true
				d.convo = sandra()
			"Michael Adeyemi":
				d.admit = true
				d.convo = michael()
			"Kevin Platt":
				d.admit = true
				d.erase("why")
				d.convo = kevin()
			"Dr Helen Marsh":
				d.admit = true
				d.convo = helen()
			"Janet Lowe":
				d.admit = true
				d.convo = janet()
		out.append(d)
	if tonight.has("Mick Doyle"):
		var m: Dictionary = MICK.duplicate(true)
		m.convo = mick()
		out.insert(out.size() - 1, m)   # before the 3am car
	return out


## Tom Baxter, the dealer: Medical Records (non-clinical admin), and clearly unwell. He comes in later
## in the night, once the dealer note has been found. Card in date, right car.
static func baxter(night_one: Array) -> Dictionary:
	for p in night_one:
		if p.name == "Tom Baxter":
			var d: Dictionary = p.duplicate(true)
			d.admit = true
			d.expires = "09 / 1990"
			d.erase("why")
			d.skin = Color(0.86, 0.8, 0.72)   # grey and sweaty
			d.greet = ["...Evening.", "Don't mind me. Bit under the weather."]
			d.ok = "Ta."
			d.drive = "...Yeah. Night."
			d.refused = "Fine. Fine. I'm not well anyway."
			d.convo = tom()
			d.baxter = true
			return d
	return {}


## The ward rings (night three on) to add Doris Fenn to tonight's list.
const ADDED := {"name": "FENN, Doris", "staff_no": "40021", "dept": "Ward Clerk - Ward 7", "reg": "B377 OWF"}


static func ward_call() -> Array:
	return [
		["Ward 7", "Hello? Is that the car park? Ward Seven here, Sister Okafor."],
		["Ward 7", "Can you add one to your list for tonight? FENN, Doris. Our ward clerk. She's coming in to cover."],
		["Ward 7", "Staff number four-oh-oh-two-one. Little blue Metro, B377 OWF."],
		["Ward 7", "She's a love. Don't keep her out in the rain. Thank you, bye now."],
	]


static func dale_call() -> Array:
	return [
		["Dale", "Dave. Sunday. Same drill: name on the list, card in date, plate matches."],
		["Dale", "Kevin Platt's on the list proper now. And Mick Doyle's back, supposedly."],
		["Dale", "You can get up and walk the lot tonight if you want. G to get up. Take the torch."],
		["Dale", "Bad news: payroll's frozen this week. Head office cock-up. No wages tonight, I'm sorry."],
		["Dale", "Ward Seven might ring with a change to the list. Write it down."],
		["Dale", "And the police are doing walk-rounds. There's been break-ins this side of town."],
		["Dale", "Right. Bed."],
	]


static func sandra() -> Dictionary:
	return {"id": "n3_sandra", "start": "a", "nodes": {
		"a": {"speaker": "Sandra", "text": "Sunday night on Ward 7. Nobody wants it, Dave. Nobody.", "options": [
			{"text": "Card, please, Sandra.", "next": "b", "safe": true},
			{"text": "Busy one, then?", "next": "c"},
			{"text": "Seen anything odd in the car park this week?", "next": "d"}]},
		"b": {"speaker": "Sandra", "text": "Here you go, love.", "next": ""},
		"c": {"speaker": "Sandra", "text": "Two off sick and a full moon. I'll be lucky to sit down before six.", "next": ""},
		"d": {"speaker": "Sandra", "text": "That car in Row C. Grey thing. It's there every night and nobody ever gets out of it.",
			"next": "", "effects": [{"note": "Sandra: grey car in Row C every night, nobody gets out"}]}}}


static func michael() -> Dictionary:
	return {"id": "n3_michael", "start": "a", "nodes": {
		"a": {"speaker": "Michael", "text": "Alright Dave. Somebody's been going through boots in here, you know. Heard it at break.", "options": [
			{"text": "Card, please.", "next": "b", "safe": true},
			{"text": "Not on my watch.", "next": "c"},
			{"text": "Anything worth nicking in yours?", "next": "d", "effects": [{"risk": 3}]},
			{"text": "You're cheerful for a Sunday.", "next": "e"}]},
		"b": {"speaker": "Michael", "text": "Here. Same face, same car.", "next": ""},
		"e": {"speaker": "Michael", "text": "Gig after my shift! Guitar's in the boot. Seven o'clock, the Red Lion. Come along.",
			"next": "", "effects": [{"note": "Michael Adeyemi: guitar in his boot (gig at 7am)"}]},
		"c": {"speaker": "Michael", "text": "Good man. I'd lock it if the lock worked.", "next": ""},
		"d": {"speaker": "Michael", "text": "...Funny. Very funny. Card, is it?", "next": ""}}}


static func kevin() -> Dictionary:
	return {"id": "n3_kevin", "start": "a", "nodes": {
		"a": {"speaker": "Kevin", "text": "On the list proper this time, am I? Took them long enough.", "options": [
			{"text": "You are. Card, please.", "next": "b", "safe": true},
			{"text": "You look done in.", "next": "c"},
			{"text": "Covering for Mick again?", "next": "d"}]},
		"b": {"speaker": "Kevin", "text": "Here. Sorry, long day.", "next": ""},
		"c": {"speaker": "Kevin", "text": "Dog had me up at five. Biscuit. Spaniel. Daft as a brush.",
			"next": "c2", "effects": [{"flag": "clue_pet_biscuit"}, {"note": "Kevin Platt: dog = Biscuit"}]},
		"c2": {"speaker": "Kevin", "text": "", "options": [
			{"text": "Biscuit. Good name.", "next": "e", "safe": true},
			{"text": "Bet he's the password to everything.", "next": "f", "effects": [{"risk": 4}]}]},
		"d": {"speaker": "Kevin", "text": "Mick's back tonight, apparently. We'll see.", "next": ""},
		"e": {"speaker": "Kevin", "text": "He's a good lad. Card's there.", "next": ""},
		"f": {"speaker": "Kevin", "text": "...Ha. Yeah. Course he is. Anyway.", "next": ""}}}


static func helen() -> Dictionary:
	return {"id": "n3_helen", "start": "a", "nodes": {
		"a": {"speaker": "Dr Marsh", "text": "My own car tonight, you'll be pleased to hear.", "options": [
			{"text": "Thank you, Doctor. Card, please.", "next": "b", "safe": true},
			{"text": "Garage sort it out?", "next": "c"}]},
		"b": {"speaker": "Dr Marsh", "text": "Here.", "next": ""},
		"c": {"speaker": "Dr Marsh", "text": "Eventually. And my husband's left his camera bag in the boot again. He'll be lost without it.",
			"next": "", "effects": [{"note": "Dr Marsh: husband's camera bag in her boot"}]}}}


## Baxter at the window. If the player has the dealer note they can bring it up: he's scared, and
## tells them to meet him by the payphone (the next talk is out there).
static func tom() -> Dictionary:
	return {"id": "n3_baxter", "start": "a", "nodes": {
		"a": {"speaker": "Baxter", "text": "Tom Baxter. Medical Records. Card's... here somewhere. Sorry. Hands are shaking.", "options": [
			{"text": "Take your time. Card, please.", "next": "b", "safe": true},
			{"text": "You look terrible, Tom.", "next": "c"},
			{"text": "I found a note on that car with the alarm. It says 'dealer'. And your name.", "next": "d", "requires": "dealer_note"}]},
		"b": {"speaker": "Baxter", "text": "There. Don't look at me like that.", "next": ""},
		"c": {"speaker": "Baxter", "text": "Haven't slept. Haven't eaten. It's fine. It's... fine.", "next": ""},
		"d": {"speaker": "Baxter", "text": "Keep your voice down! Where did you... Who else has seen it?", "options": [
			{"text": "Nobody. Yet.", "next": "e", "safe": true},
			{"text": "Depends what it's worth to you.", "next": "e", "effects": [{"risk": 2}]}]},
		"e": {"speaker": "Baxter", "text": "Not here. Not at the window. Back of the lot, by the fence, in a bit. Come on your own.",
			"next": "", "effects": [{"flag": "baxter_scared"}, {"note": "Baxter: meet him at the back of the lot, by the fence"}]}}}


## Baxter by the payphone (the next talk): he's calmer, and you can offer him something to sell.
static func baxter_payphone(has_stuff: bool) -> Dictionary:
	return {"id": "baxter_payphone", "start": "a", "nodes": {
		"a": {"speaker": "Baxter", "text": "Right. You've got me. I move things. Bits and bobs. Nobody gets hurt.", "options": [
			{"text": "Forget I asked.", "next": "b", "safe": true},
			{"text": "I might have things to sell.", "next": "c" if has_stuff else "d"}]},
		"b": {"speaker": "Baxter", "text": "Good. Forget my face while you're at it.", "next": ""},
		"c": {"speaker": "Baxter", "text": "Go on, then. Let's see what's in that crate of yours.", "next": "", "effects": [{"flag": "baxter_sell"}]},
		"d": {"speaker": "Baxter", "text": "Have you? Your crate's empty, pal. Come back when you've got something. I'm about most nights.",
			"next": "", "effects": [{"flag": "baxter_deal"}]}}}


## The police doing a walk-round (night three on). Early on they find nothing.
static func police() -> Dictionary:
	return {"id": "police", "start": "a", "nodes": {
		"a": {"speaker": "Officer", "text": "Evening. Don't mind me, just a walk round. There's been a few cars broken into this side of town.", "options": [
			{"text": "Evening, officer.", "next": "b", "safe": true},
			{"text": "Anything I should look out for?", "next": "c"},
			{"text": "Fancy a cuppa?", "next": "d"}]},
		"b": {"speaker": "Officer", "text": "Keep your eyes open. Night.", "next": ""},
		"c": {"speaker": "Officer", "text": "Lads trying boots. Anybody hanging round the cars, ring it in.", "next": ""},
		"d": {"speaker": "Officer", "text": "Can't stop. Ta, though.", "next": ""}}}


static func janet() -> Dictionary:
	return {"id": "n3_janet", "start": "a", "nodes": {
		"a": {"speaker": "Janet", "text": "Pharmacy's back open. I'm allowed in tonight, am I?", "options": [
			{"text": "You're on the list. Card, please.", "next": "b", "safe": true},
			{"text": "Sorry about last night.", "next": "c"}]},
		"b": {"speaker": "Janet", "text": "Here you are, love.", "next": ""},
		"c": {"speaker": "Janet", "text": "Not your fault, love. Nobody tells anybody anything round here.", "next": ""}}}


static func mick() -> Dictionary:
	return {"id": "n3_mick", "start": "a", "nodes": {
		"a": {"speaker": "Mick", "text": "Mick Doyle. I'm on there. Don't look at the car, it's my brother's.", "options": [
			{"text": "Card, please.", "next": "b", "safe": true},
			{"text": "Rules are rules, Mick. It has to be your car.", "next": "c"}]},
		"b": {"speaker": "Mick", "text": "There. Look, it's one night.", "next": ""},
		"c": {"speaker": "Mick", "text": "Come on. Who's going to know?", "next": ""}}}
