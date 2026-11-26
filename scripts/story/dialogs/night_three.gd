extends RefCounted
## Night three (Sunday 15th October 1989): the regulars, each with their own conversation at the side
## window (dialog format: ../dialog.gd). No ward call tonight. Kevin Platt is on the printed list now,
## and Mick Doyle finally turns up, in the wrong car.
##
## NPC knowledge for the boots: Tom has a guitar in his (a gig after his shift), Dr Marsh's husband's
## camera bag is in hers. The hacking clue: Kevin's dog is called Biscuit (the hospital password).

## The printed list (night two's, plus Kevin).
const LIST := [
	{"name": "ADEYEMI, Michael", "staff_no": "40388", "dept": "Porter", "reg": "C771 PFM"},
	{"name": "BAXTER, Tom", "staff_no": "40562", "dept": "Theatre Technician", "reg": "A456 GNB"},
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


static func arrivals(night_one: Array) -> Array:
	var out := []
	for p in night_one:
		var d: Dictionary = p.duplicate(true)
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
			"Tom Baxter":
				d.admit = true
				d.expires = "09 / 1990"
				d.convo = tom()
			"Janet Lowe":
				d.admit = true
				d.convo = janet()
		out.append(d)
	var m: Dictionary = MICK.duplicate(true)
	m.convo = mick()
	out.insert(out.size() - 1, m)   # before the 3am car
	return out


static func dale_call() -> Array:
	return [
		["Dale", "Dave. Sunday. Same drill: name on the list, card in date, plate matches."],
		["Dale", "Kevin Platt's on the list proper now. And Mick Doyle's back, supposedly."],
		["Dale", "You can get up and walk the lot tonight if you want. G to get up. Take the torch."],
		["Dale", "And somebody's been going through people's boots. If I find out who, they're done."],
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
			{"text": "Anything worth nicking in yours?", "next": "d", "effects": [{"risk": 3}]}]},
		"b": {"speaker": "Michael", "text": "Here. Same face, same car.", "next": ""},
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


static func tom() -> Dictionary:
	return {"id": "n3_tom", "start": "a", "nodes": {
		"a": {"speaker": "Tom", "text": "New card, in date, right car. Gold star for me.", "options": [
			{"text": "Gold star. Card, please.", "next": "b", "safe": true},
			{"text": "Big night?", "next": "c"},
			{"text": "You look happy for a Sunday.", "next": "c"}]},
		"b": {"speaker": "Tom", "text": "There you go.", "next": ""},
		"c": {"speaker": "Tom", "text": "Gig after my shift! Guitar's in the boot. Seven o'clock, the Red Lion. Come along.",
			"next": "", "effects": [{"note": "Tom Baxter: guitar in his boot (gig at 7am)"}]}}}


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
