extends RefCounted
## Night two (Saturday 14th October 1989). Two new things to check:
##   * Tonight's list now gives each person's car. The plate they arrive in must match it.
##   * The ward rings part-way through with changes to the list: write them down.
## Built on night one's people (shift.gd ARRIVALS), with tonight's changes laid over them.

const DATE_TEXT := "Saturday 14th October 1989  -  23:00 to 07:00"
const DATE_SHORT := "SAT 14 OCT 1989"

## The printed list: now with each person's registered car.
const LIST := [
	{"name": "ADEYEMI, Michael", "staff_no": "40388", "dept": "Porter", "reg": "C771 PFM"},
	{"name": "BAXTER, Tom", "staff_no": "40562", "dept": "Medical Records (Admin)", "reg": "A456 GNB"},
	{"name": "DOYLE, Mick", "staff_no": "40391", "dept": "Porter", "reg": "D501 NKA"},
	{"name": "LOWE, Janet", "staff_no": "40115", "dept": "Pharmacy", "reg": "D310 YXE"},
	{"name": "MARSH, Dr Helen", "staff_no": "31105", "dept": "Registrar - A&E", "reg": "F23 HLM"},
	{"name": "PIKE, Sandra", "staff_no": "40217", "dept": "Staff Nurse - Ward 7", "reg": "E412 KTV"},
]

## Added by the ward's phone call (for logging; the printed list doesn't change).
const ADDED := {"name": "PLATT, Kevin", "staff_no": "40612", "dept": "Porter (phoned in)", "reg": "B908 RWD"}

## Changes to night one's people: name -> fields to replace.
const CHANGES := {
	"Michael Adeyemi": {"admit": true,
		"greet": ["Alright Dave? Night five of the swimming pool.", "Same car as always. Check it if you like."]},
	"Sandra Pike": {"admit": true,
		"greet": ["Evening, Dave. Still flooded over our side.", "They've got me on nights all week. Somebody kill me."]},
	"Dr Helen Marsh": {"admit": false, "reg": "G614 TRM", "style": "estate", "paint": Color(0.55, 0.56, 0.6),
		"greet": ["Hello again. Marsh, A&E.", "I'm in my husband's car tonight. Mine's in the garage."],
		"refused": "Oh, for heaven's sake. Fine. I'll walk in from the main road.",
		"why": "Her car (G614 TRM) wasn't the one on the list (F23 HLM). A different car doesn't come in."},
	"Tom Baxter": {"admit": true, "expires": "09 / 1990",
		"greet": ["Evening, Dave. Got my new card. Happy now?"], "ok": "Told you."},
	"Janet Lowe": {"admit": false, "after_call": true,
		"greet": ["Hiya Dave. Only me.", "Quiet one tonight, I hope."],
		"refused": "Shut? Nobody told me! I've driven all the way in... Fine. Fine.",
		"why": "The ward rang: the pharmacy was shut tonight, so Janet Lowe was taken off the list."},
	"Kevin Platt": {"admit": true, "after_call": true,
		"greet": ["Evening. Covering for Mick again.", "They've rung you this time, haven't they? Tell me they've rung you."],
		"ok": "Thank God for that.", "refused": "Unbelievable. They SAID they'd ring.",
		"why": "The ward rang to add Kevin Platt (porter, B908 RWD) to the list."},
	"R. Kessler": {"greet": ["...", "You let them all in last night, Dave.", "Let me in too. It's so cold out here."]},
}


static func arrivals(night_one: Array) -> Array:
	var out := []
	for p in night_one:
		var d: Dictionary = p.duplicate(true)
		if CHANGES.has(d.name):
			for k in CHANGES[d.name]:
				d[k] = CHANGES[d.name][k]
		out.append(d)
	return out


static func dale_call() -> Array:
	return [
		["Dale", "Dave. Dale. Night two, then. A couple of changes."],
		["Dale", "Tonight's list has everyone's car on it now. The reg on the list has to match the car they turn up in."],
		["Dale", "Different car, they don't come in. I don't care if it's their mum's. Insurance."],
		["Dale", "Click their car at the window to read the plate, and check it against the list when you look at their card."],
		["Dale", "And the wards might ring with changes. When they do, write it down. There's a notepad on the desk, or press N."],
		["Dale", "Right. Bed."],
	]


static func ward_call() -> Array:
	return [
		["Sister Okafor", "Hello? Is that the car park gatehouse? Sister Okafor, night manager at the General."],
		["Sister Okafor", "Two changes to tonight's list, love. Janet Lowe is off. The pharmacy's shut tonight, so she shouldn't be coming in."],
		["Sister Okafor", "And we've a porter covering for Mick Doyle: Kevin Platt, staff number 40612."],
		["Sister Okafor", "He's in a white van. B908 RWD. B-nine-oh-eight, R-W-D."],
		["Sister Okafor", "Have you got all that? Lovely. Thank you."],
	]
