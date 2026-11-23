extends RefCounted
## Example conversations in the dialog format (see ../dialog.gd). They show each place a
## conversation can happen (side window, desk phone, out on patrol), conditional options, effects,
## and the safe option. Night three's real conversations follow the same shape.
## The pet-name clue is the kind of thing the hospital-password side hustle will use.


## At the side window.
static func window() -> Dictionary:
	return {"id": "sample_window", "start": "a", "nodes": {
		"a": {"speaker": "Kevin", "text": "Evening. Is it always this quiet?", "options": [
			{"text": "Card, please.", "next": "b", "safe": true},
			{"text": "Quiet's how I like it. You got a dog or something?", "next": "c"},
			{"text": "Depends who's asking.", "next": "d", "effects": [{"risk": 2}]}]},
		"b": {"speaker": "Kevin", "text": "Here you go. Sorry, long day.", "next": ""},
		"c": {"speaker": "Kevin", "text": "Biscuit. Spaniel. He's the reason I'm up at all hours.",
			"next": "c2", "effects": [{"flag": "clue_pet_biscuit"}, {"note": "Kevin Platt: dog = Biscuit"}]},
		"c2": {"speaker": "Kevin", "text": "Anyway. Card.", "next": ""},
		"d": {"speaker": "Kevin", "text": "Nobody. Nobody at all.", "next": ""}}}


## On the desk phone (the player who answered gets to reply).
static func phone() -> Dictionary:
	return {"id": "sample_phone", "start": "a", "nodes": {
		"a": {"speaker": "Dale", "text": "Dave. Quick one. Facilities want to know if you've noticed anything odd with the PC.", "options": [
			{"text": "Nothing. All quiet.", "next": "b", "safe": true},
			{"text": "It's been slow. Why?", "next": "c"},
			{"text": "Define odd.", "next": "c", "effects": [{"risk": 3}]}]},
		"b": {"speaker": "Dale", "text": "Good. Keep it that way. Night.", "next": ""},
		"c": {"speaker": "Dale", "text": "No reason. Forget I asked.", "next": ""}}}


## Out on patrol (someone met in the lot). The second option only appears once you know the dog's name.
static func patrol() -> Dictionary:
	return {"id": "sample_patrol", "start": "a", "nodes": {
		"a": {"speaker": "Stranger", "text": "You the night guard? Didn't think anyone was out here.", "options": [
			{"text": "Just doing my rounds.", "next": "b", "safe": true},
			{"text": "Mind your own business.", "next": "c", "effects": [{"risk": 4}]},
			{"text": "Biscuit says hello.", "requires": "clue_pet_biscuit", "next": "d", "effects": [{"coins": 2}, {"flag": "stranger_knows_dog"}]}]},
		"b": {"speaker": "Stranger", "text": "Right. Well. Mind how you go.", "next": ""},
		"c": {"speaker": "Stranger", "text": "Touchy. I'll leave you to it.", "next": ""},
		"d": {"speaker": "Stranger", "text": "...How do you know about the dog? Fine. Here. Say nothing.", "next": ""}}}
