extends RefCounted
## The in-game "internet": a handful of fake 1990s sites. Pages are plain HTML shown by
## the same renderer that draws real pages. Placeholders: {{TIME}} {{DATE}} {{WEATHER}} {{VISITORS}}.

const HtmlView := preload("res://scripts/desktop/html_view.gd")

const HOME := "http://www.winnight.net/"

## [title, url] shown in the Favorites menu.
const FAVORITES := [
	["NightNet Start Page", "http://www.winnight.net/"],
	["FindIt Search", "http://www.findit.com/"],
	["The Ashford Gazette", "http://www.ashfordgazette.com/"],
	["Nightwatch Security Systems", "http://www.nightwatch-security.com/"],
	["Ashford Parking Authority", "http://www.ashfordparking.gov/"],
	["Doug's Place", "http://home.freeweb.net/~dougk/"],
	["Night Owls Message Board", "http://bbs.nightowls.net/"],
	["CityWeather", "http://www.cityweather.net/"],
]

# [url, title, description, keywords]
const INDEX := [
	["http://www.ashfordgazette.com/lotc.html", "Lot C to close early, says Parking Authority", "Ashford's Lot C will close at 23:00 from the 20th. Attendants advised not to wait for vehicles.", "lot c car park closing parking ashford"],
	["http://www.ashfordgazette.com/missing87.html", "Still no sign of missing night attendant", "Police have found no trace of the night attendant who vanished from Lot C in 1987.", "missing attendant 1987 lot c police night"],
	["http://www.ashfordparking.gov/lotc.html", "Lot C - Ashford Parking Authority", "Opening hours, charges and rules for Lot C.", "lot c parking rules charges hours authority"],
	["http://www.nightwatch-security.com/operators.html", "Operator FAQ - Nightwatch Security Systems", "Frequently asked questions for booth operators.", "operator faq booth nightwatch security camera"],
	["http://home.freeweb.net/~dougk/night.html", "Doug's Place - My Night Shift Diary", "My diary from the night shift at Lot C.", "doug night shift diary lot c booth"],
	["http://bbs.nightowls.net/", "Night Owls Message Board", "A board for people who work nights. Security, cleaners, drivers.", "night shift bbs board security guards owls"],
	["http://www.cityweather.net/", "CityWeather - Ashford forecast", "Today's forecast for Ashford and the valley.", "weather forecast ashford rain storm"],
	["http://www.nightwatch-security.com/", "Nightwatch Security Systems", "Somebody is always watching the lot.", "nightwatch security systems cctv gate barrier"],
	["http://www.ashfordgazette.com/", "The Ashford Gazette Online", "Local news for Ashford County.", "ashford gazette news local"],
	["http://home.freeweb.net/~dougk/", "Doug's Place", "Welcome to my homepage. Under construction.", "doug homepage freeweb trains cats"],
]

const CANON := ["winnight.net", "findit.com", "nightwatch-security.com", "ashfordgazette.com", "ashfordparking.gov", "home.freeweb.net", "bbs.nightowls.net", "cityweather.net"]


static func canon_host(h: String) -> String:
	return h.substr(4) if h.begins_with("www.") else h


static func has_host(host: String) -> bool:
	return canon_host(host) in CANON


## Returns the page's HTML (404 page if the host is ours but the path isn't).
static func get_page(url: String, vars: Dictionary) -> String:
	var u := HtmlView.split_url(url)
	var host := canon_host(u.host)
	var path: String = u.path.to_lower()
	if path.ends_with("/index.html") or path.ends_with("/index.htm"):
		path = path.substr(0, path.rfind("/") + 1)
	var html := ""
	if host == "findit.com" and path == "/search":
		html = _search_page(u.query)
	else:
		html = _SITES.get(host + path, "")
	if html == "":
		html = NOT_FOUND.replace("{{URL}}", url)
	for k in vars:
		html = html.replace("{{%s}}" % k, str(vars[k]))
	return html


static func _search_page(query: String) -> String:
	var q := ""
	for part in query.split("&"):
		if part.begins_with("q="):
			q = part.substr(2).uri_decode().replace("+", " ")
	var words := q.to_lower().split(" ", false)
	var hits: Array = []
	for e in INDEX:
		var hay: String = (e[1] + " " + e[2] + " " + e[3]).to_lower()
		var score := 0
		for w in words:
			if hay.contains(w):
				score += 1
		if score > 0:
			hits.append([score, e])
	hits.sort_custom(func(a, b): return a[0] > b[0])
	var h := "<html><head><title>FindIt: %s</title></head><body bgcolor=#ffffff>" % q.xml_escape()
	h += "<table width=100%% border=0><tr><td width=120><font size=6 color=#cc0000><b>FindIt!</b></font></td><td><font size=2>Searched the NightNet for: <b>%s</b></font></td></tr></table><hr>" % q.xml_escape()
	if hits.is_empty():
		h += "<p><b>No documents matched your query.</b></p><ul><li>Check your spelling.<li>Try fewer words.<li>Try the other places listed on the <a href='http://www.winnight.net/'>Start Page</a>.</ul>"
	else:
		h += "<p>Found <b>%d</b> document(s):</p><ol>" % hits.size()
		for hit in hits:
			var e: Array = hit[1]
			h += "<li><a href='%s'><b>%s</b></a><br>%s<br><font size=2 color=#008000>%s</font><br><br>" % [e[0], e[1], e[2], e[0]]
		h += "</ol>"
	h += "<hr><p><font size=2>Not what you wanted? <a href='http://frogfind.org/?q=%s'>Search the real Internet with FrogFind</a>.</font></p></body></html>" % q.uri_encode()
	return h


const NOT_FOUND := """<html><head><title>404 Not Found</title></head><body>
<h2>Not Found</h2>
<p>The requested URL {{URL}} was not found on this server.</p>
<hr><address>NightNet httpd/1.0 at port 80</address>
</body></html>"""

const _SITES := {
# ------------------------------------------------------------------ portal
"winnight.net/": """<html><head><title>NightNet Start Page</title></head>
<body bgcolor=#ffffff text=#000000 link=#0000cc vlink=#551a8b>
<center>
<table width=95% border=1 cellpadding=4><tr><td align=center bgcolor=#000080>
<font size=7 color=#ffffff><b>NightNet</b></font><br><font color=#ffff80>Your window on the World Wide Web</font>
</td></tr></table>
<img src="rainbow.png">
</center>
<p>Welcome! It is <b>{{TIME}}</b> on <b>{{DATE}}</b>. Weather in Ashford: <b>{{WEATHER}}</b>.</p>
<h3>Search</h3>
<p>Type some words into the <b>Address</b> box above and press <b>Go</b>. FindIt will search the NightNet for you. Or visit <a href="http://www.findit.com/">FindIt</a> directly.</p>
<h3>Around Ashford</h3>
<ul>
<li><a href="http://www.ashfordgazette.com/">The Ashford Gazette</a> - local news and classifieds
<li><a href="http://www.ashfordparking.gov/">Ashford Parking Authority</a> - car parks, permits and fines
<li><a href="http://www.cityweather.net/">CityWeather</a> - up-to-the-hour forecast
</ul>
<h3>For the night shift</h3>
<ul>
<li><a href="http://www.nightwatch-security.com/">Nightwatch Security Systems</a> - your booth terminal vendor
<li><a href="http://bbs.nightowls.net/">Night Owls Message Board</a> - talk to other people awake at 3am
<li><a href="http://home.freeweb.net/~dougk/">Doug's Place</a> - a personal homepage
</ul>
<h3>Out on the real Internet</h3>
<p><font size=2>These pages are fetched live over the modem. Your phone line may be busy.</font></p>
<ul>
<li><a href="http://info.cern.ch/">info.cern.ch</a> - the very first web site
<li><a href="http://example.com/">example.com</a>
<li><a href="http://frogfind.org/">FrogFind</a> - a search engine for old computers
<li><a href="https://text.npr.org/">NPR text-only news</a>
<li><a href="http://textfiles.com/">textfiles.com</a> - old BBS files
</ul>
<hr>
<center><img src="btn_nightnet.png"> <img src="btn_800.png"> <img src="btn_ring.png"><br>
<font size=2>You are visitor number {{VISITORS}}. NightNet 1.0 - best viewed at 640x480.</font></center>
</body></html>""",

# ------------------------------------------------------------------ search
"findit.com/": """<html><head><title>FindIt!</title></head>
<body bgcolor=#ffffff>
<center><br><br>
<font size=7 color=#cc0000><b>FindIt!</b></font><br>
<font size=4 color=#336699>The Net's friendliest search</font><br><br>
<table border=1 cellpadding=10><tr><td bgcolor=#eeeeee align=center>
<b>[ ______________________ ] [ Search ]</b><br><br>
<font size=2>Type your words into the <b>Address box</b> at the top of this window and press Go.<br>
(Your browser has "smart search" built in.)</font></td></tr></table>
<br><font size=2>Try: <a href="http://www.findit.com/search?q=lot+c">lot c</a> | <a href="http://www.findit.com/search?q=night+shift">night shift</a> | <a href="http://www.findit.com/search?q=missing">missing</a> | <a href="http://www.findit.com/search?q=weather">weather</a></font><br><br>
<img src="rainbow.png"><br>
<font size=2>Indexing 4,203 pages. Last updated {{DATE}}.</font>
</center></body></html>""",

# ------------------------------------------------------------ Nightwatch
"nightwatch-security.com/": """<html><head><title>Nightwatch Security Systems</title></head>
<body bgcolor=#0a1428 text=#d8e4ff link=#ffdc5a vlink=#c8a040>
<center><img src="banner_nws.png"></center>
<table width=100% border=0><tr>
<td width=150 valign=top><p><b>Menu</b><br><a href="/">Home</a><br><a href="/products.html">Products</a><br><a href="/operators.html">Operator FAQ</a><br><a href="/careers.html">Careers</a></p></td>
<td valign=top>
<h2>Somebody is always watching the lot.</h2>
<p>Since 1981 Nightwatch Security Systems has supplied car parks, depots and shopping centres across the county with reliable <b>booth terminals</b>, <b>gate controllers</b> and <b>CCTV links</b>.</p>
<p><b>New:</b> CamLink v1.3 now supports up to four cameras per booth. Camera drivers (CAMDRV.SYS) are available from your supervisor.</p>
<h3>Our promise</h3>
<ul><li>Every vehicle logged.<li>Every gate monitored.<li>Every operator supported, day or night.</ul>
<p><font size=2>(c) Nightwatch Security Systems Ltd. All rights reserved. Registered in England.</font></p>
</td></tr></table></body></html>""",

"nightwatch-security.com/products.html": """<html><head><title>Products - Nightwatch Security Systems</title></head>
<body bgcolor=#0a1428 text=#d8e4ff link=#ffdc5a>
<h2>Products</h2>
<table border=1 cellpadding=5 width=95%>
<tr><th>Product</th><th>What it does</th><th>Price</th></tr>
<tr><td>NWS Booth Terminal</td><td>Green-screen operator terminal with event log, clock and weather feed.</td><td>on application</td></tr>
<tr><td>GateCtl 1.1</td><td>Remote barrier control from the booth desk.</td><td>on application</td></tr>
<tr><td>CamLink 1.3</td><td>Four-camera CCTV viewer. Needs CAMDRV.SYS.</td><td>on application</td></tr>
<tr><td>Night Radio</td><td>Transistor radio, for the operator's morale.</td><td>12.99</td></tr>
</table>
<p><a href="/">Back</a></p></body></html>""",

"nightwatch-security.com/operators.html": """<html><head><title>Operator FAQ - Nightwatch Security Systems</title></head>
<body bgcolor=#0a1428 text=#d8e4ff link=#ffdc5a>
<h2>Operator FAQ</h2>
<p><i>This page is for Nightwatch booth operators. If you found it by accident, please close it.</i></p>
<dl>
<dt>Q. CamLink says NO SIGNAL on all four cameras.</dt>
<dd>A. This is normal after heavy rain. Do not reboot the terminal during a shift.</dd>
<dt>Q. Camera 3 reports MOTION but the lot is empty.</dt>
<dd>A. This is a sensor fault. Please do not log it as an incident.</dd>
<dt>Q. The gate arm moved by itself.</dt>
<dd>A. Gate arms can cycle at night due to electrical interference. Please do not go and check.</dd>
<dt>Q. The phone in the booth rang and nobody was there.</dt>
<dd>A. Do not answer the payphone. The booth phone is fine to answer.</dd>
<dt>Q. There is a car in Row C after closing.</dt>
<dd>A. Write down the time. Leave it.</dd>
<dt>Q. I think someone else is using the terminal.</dt>
<dd>A. Please keep the radio on. Thank you for your service.</dd>
</dl>
<p><a href="/">Back</a></p></body></html>""",

"nightwatch-security.com/careers.html": """<html><head><title>Careers - Nightwatch Security Systems</title></head>
<body bgcolor=#0a1428 text=#d8e4ff link=#ffdc5a>
<h2>Careers</h2>
<p><b>Night Operator, Lot C (Ashford)</b> - <font color=#ff8080>URGENT</font></p>
<p>23:00 - 07:00. Quiet work for a calm person. Must be happy working alone. Must be able to ignore things. No previous experience necessary.</p>
<p>Previous post holder: <i>no longer with us</i>. Please apply to Dale Whitcombe, extension 214.</p>
<p><a href="/">Back</a></p></body></html>""",

# ------------------------------------------------------------------ Gazette
"ashfordgazette.com/": """<html><head><title>The Ashford Gazette Online</title></head>
<body bgcolor=#f4f0e4 text=#111111 link=#003366>
<center><img src="masthead.png"></center>
<p align=center><font size=2>{{DATE}} - Edition 2 - Weather: {{WEATHER}}</font></p>
<hr>
<table width=100% border=0 cellpadding=6><tr>
<td valign=top width=62%>
<h2><a href="/lotc.html">Lot C to close early, says Parking Authority</a></h2>
<p>Ashford's busiest night car park will close its barrier at 23:00 from the 20th. The Authority says the change is "for operational reasons" and refused to be drawn on rumours.</p>
<p><a href="/lotc.html">Read more...</a></p>
<h3><a href="/missing87.html">Still no sign of missing night attendant</a></h3>
<p>Police have confirmed that the case of the man who vanished from his booth in 1987 remains open.</p>
<h3>Council to repair Mill Road bridge</h3>
<p>Work is due to begin after the autumn rains. Delays are expected.</p>
</td>
<td valign=top>
<h3>In brief</h3>
<ul><li>Fete cancelled due to rain<li>Library fines frozen<li>Sheep escape from farm on A41<li>Tree falls on garage on Church Lane</ul>
<p><a href="/classifieds.html">Classifieds</a><br><a href="http://www.cityweather.net/">Weather</a></p>
</td></tr></table>
<hr><font size=2>(c) The Ashford Gazette. Reproduction without permission is prohibited.</font>
</body></html>""",

"ashfordgazette.com/lotc.html": """<html><head><title>Lot C to close early</title></head>
<body bgcolor=#f4f0e4 text=#111111 link=#003366>
<center><img src="masthead.png"></center><hr>
<h1>Lot C to close early, says Parking Authority</h1>
<p><i>By our local reporter</i></p>
<p>Ashford's Lot C, the 120-bay car park behind the old depot, will shut its barrier at 23:00 from the 20th instead of midnight, the Parking Authority announced yesterday.</p>
<p>The Authority gave no reason beyond "operational concerns". Staff at the booth, who work for private contractor Nightwatch Security Systems, were reported to be "relieved".</p>
<p>Residents of Mill Road have long complained of headlights in the lot at night "when nobody should be there". A spokesman for the Authority described the claims as "a drainage issue".</p>
<blockquote>"If a car is still there after closing, we just ask that nobody goes to look at it," the spokesman added, then asked that the remark not be printed.</blockquote>
<p>Lot C was opened in 1971. It occupies the site of the former Ashford Goods Yard.</p>
<hr><img src="lot_photo.png"><br><font size=2>Lot C, photographed last month. Picture: Gazette</font>
<p><a href="/">Back to front page</a></p></body></html>""",

"ashfordgazette.com/missing87.html": """<html><head><title>Still no sign of missing night attendant</title></head>
<body bgcolor=#f4f0e4 text=#111111 link=#003366>
<center><img src="masthead.png"></center><hr>
<h1>Still no sign of missing night attendant</h1>
<p>Police say they have no new leads in the case of Raymond Hale, 51, the night attendant who vanished from Lot C on the night of 13 October 1987.</p>
<p>His coat, his flask and his torch were found in the booth. The radio was still on. The barrier gate was raised. The logbook's last entry reads only: <i>"02:14 - car in row C"</i>.</p>
<p>Officers searched the lot and the surrounding fields for three weeks. "We found nothing," said a retired inspector. "That is the odd thing. We found absolutely nothing. Not even footprints in the mud. And it had been raining for days."</p>
<p>A spokesman for the Parking Authority said Lot C is "perfectly safe".</p>
<p><font size=2>Related: <a href="http://www.findit.com/search?q=lot+c">search for Lot C</a></font></p>
<p><a href="/">Back to front page</a></p></body></html>""",

"ashfordgazette.com/classifieds.html": """<html><head><title>Classifieds - The Ashford Gazette</title></head>
<body bgcolor=#f4f0e4 text=#111111>
<h2>Classifieds</h2>
<table border=1 cellpadding=4 width=95%>
<tr><th>For sale</th><th>Wanted</th></tr>
<tr><td valign=top>Ford Sierra, 1986, one careful owner, never parked in Lot C.<br><br>Pair of wellington boots, size 9.<br><br>Transistor radio, works but changes station by itself. 3.</td>
<td valign=top>Night attendant for Lot C. Apply Nightwatch Security. Good pay. Previous experience not required.<br><br>Someone to feed my cat on Tuesdays.<br><br>Information about a dark saloon car, no plates. Ring after dark. Not after 2am.</td></tr>
</table><p><a href="/">Back</a></p></body></html>""",

# ----------------------------------------------------------------- Parking
"ashfordparking.gov/": """<html><head><title>Ashford Parking Authority</title></head>
<body bgcolor=#ffffff text=#000000 link=#00339a>
<table width=100% border=0><tr><td bgcolor=#00339a><font color=#ffffff size=5><b>ASHFORD PARKING AUTHORITY</b></font></td></tr></table>
<p>Welcome to the official site of the Ashford Parking Authority.</p>
<ul>
<li><a href="/lotc.html">Lot C - opening hours and rules</a>
<li>Lot A (Station Road) - 6am to 10pm
<li>Lot B (Market Square) - 24 hours
<li>Permits and fines - ring 01632 960143
</ul>
<hr><font size=2>Last updated {{DATE}}. Best viewed in NightNet 1.0.</font></body></html>""",

"ashfordparking.gov/lotc.html": """<html><head><title>Lot C - Ashford Parking Authority</title></head>
<body bgcolor=#ffffff text=#000000 link=#00339a>
<table width=100% border=0><tr><td bgcolor=#00339a><font color=#ffffff size=5><b>LOT C</b></font></td></tr></table>
<h3>Opening hours</h3>
<p>Closes to the public at <b>23:00</b> (from the 20th). The barrier is attended 24 hours.</p>
<h3>Charges</h3>
<table border=1 cellpadding=3><tr><th>Stay</th><th>Charge</th></tr><tr><td>Up to 2 hours</td><td>0.50</td></tr><tr><td>Up to 8 hours</td><td>1.20</td></tr><tr><td>Overnight</td><td>2.00</td></tr></table>
<h3>Rules</h3>
<ol>
<li>Park within the bay lines.
<li>No vehicle may be left in Row C after closing.
<li>Do not approach any vehicle in Row C after closing.
<li>Operators must not leave the booth between 02:00 and 03:00 for any reason.
<li>The Authority accepts no liability for anything.
</ol>
<p><a href="/">Back</a></p></body></html>""",

# ------------------------------------------------------------------- Doug
"home.freeweb.net/~dougk/": """<html><head><title>Doug's Place</title></head>
<body bgcolor=#000066 text=#ffffff link=#ffff00 vlink=#ff99ff>
<center>
<img src="construction.png"><br>
<font size=7 color=#ffff00><b>~ Doug's Place ~</b></font><br>
<img src="rainbow.png"><br>
<font size=4>Welcome to my homepage!!!</font>
</center>
<p>Hi! I'm Doug. I work nights at a car park and I like <b>trains</b>, <b>cats</b> and <b>my computer</b>. This page is under construction, so please excuse the mess.</p>
<h3>Places on my site</h3>
<ul>
<li><a href="night.html">My Night Shift Diary</a> (NEW!)
<li><a href="guestbook.html">Sign my guestbook</a>
<li>My train pictures (coming soon)
<li>My cat Biscuit (coming soon)
</ul>
<center><img src="rainbow.png"><br>
You are visitor number <font face="courier" color=#00ff00><b>{{VISITORS}}</b></font><br>
<img src="btn_nightnet.png"> <img src="btn_ring.png"><br>
<a href="http://www.winnight.net/">Back to the Start Page</a></center>
</body></html>""",

"home.freeweb.net/~dougk/night.html": """<html><head><title>Doug's Night Shift Diary</title></head>
<body bgcolor=#000000 text=#33ff66 link=#ffff00>
<font face="courier">
<h2>My Night Shift Diary</h2>
<p><i>(Mostly so I have something to read back and know I'm not going mad.)</i></p>
<p><b>Mon.</b> Quiet. Rain. Fixed the clock in the booth. The new radio picks up one station perfectly, which is nice.</p>
<p><b>Tue.</b> Gate arm went up at ten past two. Nobody there. Cameras are down as usual so I couldn't check. Went out with the torch. Nothing. Gate came down by itself.</p>
<p><b>Wed.</b> I saw the car again. Row C. Dark saloon. Engine ticking over, windows steamed up inside. I watched it from the booth for twenty minutes. At 02:15 it was gone and I did not hear it leave.</p>
<p><b>Thu.</b> Dale says to stop writing it down. He says that's how it starts. How what starts?</p>
<p><b>Fri.</b> Somebody was using the terminal while I was on patrol. There was a Notepad open and it said <i>"are you watching?"</i> I don't remember typing it.</p>
<p><b>Sat.</b> I'm not doing a patrol tonight. I am going to sit in the booth with the light on and the radio on.</p>
<p>That's the last entry. I think I'll take down this page.</p>
</font>
<p><a href="/~dougk/">Back</a></p></body></html>""",

"home.freeweb.net/~dougk/guestbook.html": """<html><head><title>Doug's Guestbook</title></head>
<body bgcolor=#000066 text=#ffffff link=#ffff00>
<h2>Guestbook</h2>
<hr>
<p><b>Mike (Leeds)</b>, 2 Sept: Cool page! Love the trains.</p>
<p><b>Biscuit's Mum</b>, 11 Sept: Biscuit says hello.</p>
<p><b>R. Kessler</b>, 29 Sept: Doug, are you still on Booth 2? Ring me.</p>
<p><b>anonymous</b>, 7 Oct: Why did you take down the diary.</p>
<p><b>anonymous</b>, 12 Oct: Look behind you.</p>
<p><b>anonymous</b>, {{DATE}}: still here.</p>
<hr><p><a href="/~dougk/">Back</a></p></body></html>""",

# -------------------------------------------------------------------- BBS
"bbs.nightowls.net/": """<html><head><title>Night Owls Message Board</title></head>
<body bgcolor=#101010 text=#dddddd link=#66ccff vlink=#9999ff>
<center><font size=6 color=#ffcc33><b>Night Owls</b></font><br><font size=2>A board for people who work when you sleep</font></center><hr>
<table width=100% border=1 cellpadding=4>
<tr bgcolor=#303030><th align=left>Topic</th><th>Replies</th><th>Last post</th></tr>
<tr><td><a href="thread1.html">Anyone else get the radio thing?</a></td><td align=center>14</td><td>R.K.</td></tr>
<tr><td><a href="thread2.html">Booth phone ringing - ideas?</a></td><td align=center>9</td><td>nightbus_pat</td></tr>
<tr><td><a href="thread3.html">Lot C - is it just me?</a></td><td align=center>31</td><td>[deleted]</td></tr>
<tr><td>Best flask for a 12-hour shift</td><td align=center>6</td><td>dave_c</td></tr>
<tr><td>Cleaning crew - anyone paid for Sunday?</td><td align=center>2</td><td>mop_queen</td></tr>
</table>
<p><font size=2>Server time {{TIME}} | 3 users online (you are one of them)</font></p>
<p><a href="http://www.winnight.net/">NightNet Start</a></p></body></html>""",

"bbs.nightowls.net/thread1.html": """<html><head><title>Anyone else get the radio thing?</title></head>
<body bgcolor=#101010 text=#dddddd link=#66ccff>
<h3>Anyone else get the radio thing?</h3>
<hr>
<p><b>nightbus_pat</b>: My little transistor changes station by itself around 2am. Always lands on the same one. Slow jazz, very quiet, I can't find it on the dial the rest of the day.</p>
<p><b>dave_c</b>: Atmospheric interference.</p>
<p><b>nightbus_pat</b>: It's not interference, Dave, it's a song.</p>
<p><b>mop_queen</b>: Mine does it too. Leave it playing. Seriously.</p>
<p><b>R.K.</b>: Keep it on. When it goes quiet, that's when you worry. I wrote this on a floppy but nobody asked.</p>
<hr><a href="/">Back to the board</a></body></html>""",

"bbs.nightowls.net/thread2.html": """<html><head><title>Booth phone ringing - ideas?</title></head>
<body bgcolor=#101010 text=#dddddd link=#66ccff>
<h3>Booth phone ringing - ideas?</h3>
<hr>
<p><b>nightbus_pat</b>: The phone in my booth rings at 02:10 or so, only when it's raining. When I pick up there's rain on the line. Actual rain, a long way off.</p>
<p><b>dave_c</b>: Crossed wires. Ring the phone company.</p>
<p><b>nightbus_pat</b>: I did. They say the line has been disconnected since 1987.</p>
<p><b>[guest]</b>: Don't pick it up.</p>
<hr><a href="/">Back to the board</a></body></html>""",

"bbs.nightowls.net/thread3.html": """<html><head><title>Lot C - is it just me?</title></head>
<body bgcolor=#101010 text=#dddddd link=#66ccff>
<h3>Lot C - is it just me?</h3>
<hr>
<p><b>doug_k</b>: Is anyone else on Lot C seeing a car in Row C at about 02:14? Dark, no plates.</p>
<p><b>dave_c</b>: Lot C has a reputation. Ignore it, drink tea.</p>
<p><b>R.K.</b>: I've been watching it for a month. It isn't a car. It looks like a car from the booth. If you ever walk down there, it's the same height as a car but it doesn't have an engine, it has a breath.</p>
<p><b>doug_k</b>: You've been there? I thought you quit.</p>
<p><b>R.K.</b>: I never left the booth. Look at the picture.</p>
<center><img src="lot_photo2.png"><br><font size=2>"Row C, 02:14" - posted by R.K. (look by the fence)</font></center>
<p><b>[deleted]</b>: [this message has been removed by an administrator]</p>
<hr><a href="/">Back to the board</a></body></html>""",

# ----------------------------------------------------------------- Weather
"cityweather.net/": """<html><head><title>CityWeather - Ashford</title></head>
<body bgcolor=#e6f0ff text=#000033 link=#003399>
<table width=100% border=0><tr><td bgcolor=#003399><font size=6 color=#ffffff><b>CityWeather</b></font></td></tr></table>
<h2>Ashford and the Valley</h2>
<table border=1 cellpadding=6>
<tr><th>Now ({{TIME}})</th><td><font size=5><b>{{WEATHER}}</b></font></td></tr>
<tr><th>Tonight</th><td>Rain, heavy at times. Thunderstorms possible after midnight.</td></tr>
<tr><th>Wind</th><td>South-westerly, gusting.</td></tr>
<tr><th>Visibility</th><td>Poor. Mist over low ground, especially near the old goods yard.</td></tr>
</table>
<p><b>Forecaster's note:</b> Friday the 13th brings a deep area of low pressure from the west. Motorists are advised to avoid low-lying car parks.</p>
<p><a href="http://www.winnight.net/">NightNet Start</a></p></body></html>""",
}
