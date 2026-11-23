extends RefCounted
## Night three: Doris Fenn, Ward 7's clerk. Sixty-four, forty-one years at the General, retiring at
## Christmas. Chatty and kind. She hands the guard a copy of the staff newsletter because she printed two
## by mistake. She has no idea what's on it: the ward printer adds the hospital gateway's address to the
## footer, and the newsletter gives the address of the staff noticeboard (an intranet page with the
## MediCare Remote download). See docs/design/hacking-system.md (PP1).
##
## The hospital address is the same one the leaked I.T. memo gives (C:\WINDOWS\TEMP\ITMEMO.TXT), so a
## player who misses one route still has the other.

const GATEWAY := "10.113.7.20"   ## keep in step with Hack.GATEWAY_IP and the memo
const STAFF_SITE := "www.ashfordgeneral.org/staff"

## Her entry in tonight's arrivals (night three on). She's on the list, card in date, right car.
const ARRIVAL := {"name": "Doris Fenn", "role": "Ward Clerk", "dept": "Ward 7", "staff_no": "40021", "expires": "04 / 1991",
	"reg": "B377 OWF", "paint": Color(0.55, 0.68, 0.78), "style": "supermini", "skin": Color(0.93, 0.8, 0.72),
	"hair": Color(0.82, 0.8, 0.78), "hair_style": "long", "glasses": true, "shirt": Color(0.6, 0.45, 0.62),
	"admit": true, "delay": 30.0, "hands": "newsletter",
	"greet": ["Evening, love! Ooh, isn't it wild out there?"],
	"ok": "Thank you, pet.", "drive": "Night night, love. Don't work too hard.",
	"refused": "Oh! Oh dear. Well... I'll ring Sister from the payphone, shall I? Don't you worry about me."}

## Her line on tonight's printed list (and in GateLog).
const LIST := {"name": "FENN, Doris", "staff_no": "40021", "dept": "Ward Clerk - Ward 7", "reg": "B377 OWF"}


## At the side window. However it goes, she hands over the newsletter at the end (the story does that).
static func window() -> Dictionary:
	return {"id": "doris_window", "start": "a", "nodes": {
		"a": {"speaker": "Doris", "text": "You're the new lad, aren't you? Dave? I'm Doris. Ward Seven. Forty-one years, and I've never seen rain like it.", "options": [
			{"text": "Evening, Doris. Card, please.", "next": "b", "safe": true},
			{"text": "Forty-one years? You must know everyone.", "next": "c"},
			{"text": "Bit late for you, isn't it?", "next": "d"}]},
		"b": {"speaker": "Doris", "text": "Course, love. Oh, and here, take this. I printed two of the newsletter by mistake. Something to read on a long night.", "next": ""},
		"c": {"speaker": "Doris", "text": "Everyone and their dog, love. Speaking of which, here: I printed two of the newsletter by mistake. You have one.", "next": "c2"},
		"c2": {"speaker": "Doris", "text": "", "options": [
			{"text": "Thanks, Doris.", "next": "e", "safe": true},
			{"text": "Anything good in it?", "next": "f"}]},
		"d": {"speaker": "Doris", "text": "Christmas, I'm finished. Then it's me, the garden and the cat. Here, have this, I printed two by mistake.", "next": "c2"},
		"e": {"speaker": "Doris", "text": "Ta-ra, pet.", "next": ""},
		"f": {"speaker": "Doris", "text": "There's a new thing so we can get on the hospital computer from home. Don't ask me how it works! It's all on the noticeboard, it says.",
			"next": "", "effects": [{"flag": "doris_mentioned_remote"}]}}}


## The newsletter itself: (title, body BBCode, the printer's footer).
static func newsletter() -> Array:
	var body := """[b]LOT C: THANK YOU, NIGHT STAFF[/b]
While the staff car park is under water, night staff are parking in Lot C. Thank you for your patience, and please be kind to the new gatehouse man. He has a lot to remember.

[b]WORK FROM HOME - NEW![/b]
Out-of-hours staff can now dial in to the hospital computer from home with MediCare Remote. Everything you need is on the staff noticeboard:
       [b]%s[/b]
Keith in I.T. (ext. 3318) says choose a password you won't forget.

[b]BAKE SALE[/b]
The Children's Ward bake sale raised [b]£84.20[/b]. Well done Sister Okafor's lemon drizzle.

[b]RETIREMENTS[/b]
Doris Fenn, Ward 7's clerk, retires at Christmas after 41 years. Collection in the Ward 7 office. Shh!

[b]LOST[/b]
A grey cardigan, Ward 7 staff room. And whoever keeps parking in Row C: please move your car.""" % STAFF_SITE
	var footer := "Printed via ASHGEN-GW %s (WARD7-PRN)  15/10/89 22:41" % GATEWAY
	return ["ASHFORD GENERAL STAFF NEWS  -  OCTOBER 1989", body, footer]
