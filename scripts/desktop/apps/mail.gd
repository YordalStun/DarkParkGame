extends Control
## Mail: a small inbox of messages, plus a compose window.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

const DEFAULT_MAIL := [
	{"from": "Dale Whitcombe", "subj": "FWD: Hospital staff parking - Lot C", "date": "Fri 13 Oct", "unread": true, "body":
"Dave,\n\nSame again tonight. Forwarding for your records.\n\nDale\n\n----- Forwarded message -----\nFrom: Facilities, Ashford General Hospital\nDate: Tue 10 Oct\n\nFollowing the burst culvert on Monday night, Staff Car Park A remains under water and is closed until further notice.\n\nNight staff will park in Ashford Parking Authority Lot C, entering through Booth 2. The booth will hold a list of rostered night staff each evening. Please have your staff identity card ready. Cards must be in date.\n\nWe expect the car park to reopen on Monday 16th.\n\nFacilities"},
	{"from": "Dale Whitcombe", "subj": "Welcome to Lot C", "date": "Mon 9 Oct", "unread": true, "body":
"Hi,\n\nWelcome to the night team. You'll be on Booth 2, 23:00 to 07:00, Thursday to Sunday.\n\nA few things:\n  - Log every car after 22:00.\n  - Patrol at midnight and 03:00. Take the torch.\n  - Keep the booth door shut. It lets the damp in.\n  - Don't bother with the cameras. They're being looked at.\n\nIf anything weird happens, write it in the logbook and ring me on 214. Not before 8am though. I like my sleep.\n\nDale"},
	{"from": "Ashford Parking Authority", "subj": "Lot C: change to closing hours", "date": "Wed 11 Oct", "unread": true, "body":
"To all Lot C staff,\n\nFrom the 20th the car park will close to the public at 23:00 instead of midnight. Please make sure the barrier is down and the lot is clear by then.\n\nPlease do NOT wait for any vehicle that appears to be waiting. If a vehicle remains in Row C after closing, record the time and leave it.\n\nAshford Parking Authority"},
	{"from": "R. Kessler", "subj": "RE: RE: RE: things I noticed", "date": "Fri 29 Sep", "unread": true, "body":
"Dale,\n\nI know what you said. I'm not asking for a different booth, I'm asking you to come out here at 2am and stand where I stand.\n\nThe phone rang again. There's nobody at the other end, but you can hear the rain. It wasn't raining.\n\nI've left a note on the floppy. If anything happens, look there.\n\nRoy"},
	{"from": "Payroll", "subj": "Overtime claim form", "date": "Thu 5 Oct", "unread": false, "body":
"Please note that overtime claims are paid only if the form is countersigned by your supervisor.\n\nClaims for time spent \"outside the booth for unspecified reasons\" will be rejected."},
	{"from": "MAILER-DAEMON", "subj": "Undeliverable: r.kessler@ashford-nws.com", "date": "Sat 7 Oct", "unread": false, "body":
"Your message could not be delivered to r.kessler@ashford-nws.com.\n\nReason: the mailbox is not responding.\n\nThe mailbox has not responded since 29 Sep."},
]

var os: Node
var win: Control
var list: ItemList
var body: RichTextLabel


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	if os.mailbox.is_empty():
		for m in DEFAULT_MAIL:
			os.mailbox.append(m.duplicate())
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var bar: Control = MBar.new()
	box.add_child(bar)
	bar.setup(os, [["File", func(): return [{"text": "New Message", "act": compose}, {"sep": true}, {"text": "Close", "act": func(): win.request_close()}]],
		["Help", func(): return [{"text": "About Mail", "act": func(): Dialogs.msgbox(os, "About Mail", "NightWin Mail 1.0\nLocal network mail.", "info")}]]])
	var tb := HBoxContainer.new()
	box.add_child(tb)
	var nb: Button = os.button("New Message", Vector2(96, 23))
	nb.pressed.connect(compose)
	tb.add_child(nb)
	var rb: Button = os.button("Delete", Vector2(60, 23))
	rb.pressed.connect(_delete)
	tb.add_child(rb)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 110)
	list.item_selected.connect(_show)
	box.add_child(list)
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.selection_enabled = true
	body.add_theme_stylebox_override("normal", W95.field())
	body.add_theme_font_override("normal_font", W95.font("mono"))
	body.add_theme_font_size_override("normal_font_size", 12)
	box.add_child(body)
	_fill()


func _fill() -> void:
	var sel := list.get_selected_items()
	list.clear()
	var unread := 0
	for m in os.mailbox:
		var mark := "" if not m.unread else "* "
		list.add_item("%s%s  -  %s   (%s)" % [mark, m.from, m.subj, m.date], W95.icon("mail" if m.unread else "doc", true))
		if m.unread:
			unread += 1
	win.set_title("Inbox - Mail  (%d unread)" % unread if unread > 0 else "Inbox - Mail")
	if sel.size() > 0 and sel[0] < list.item_count:
		list.select(sel[0])


func _show(i: int) -> void:
	var m: Dictionary = os.mailbox[i]
	m.unread = false
	body.text = "From:     %s\nDate:     %s\nSubject:  %s\n%s\n\n%s" % [m.from, m.date, m.subj, "-".repeat(50), m.body]
	_fill()
	list.select(i)


func _delete() -> void:
	var s := list.get_selected_items()
	if s.size() > 0:
		os.mailbox.remove_at(s[0])
		body.text = ""
		_fill()


func compose() -> void:
	var dlg := Dialogs.make(os, "New Message", "mail", Vector2(390, 300))
	var c: Control = dlg.client
	c.add_child(Dialogs._label("To:", Vector2(10, 12)))
	var to := LineEdit.new()
	to.position = Vector2(60, 8)
	to.size = Vector2(310, 22)
	c.add_child(to)
	c.add_child(Dialogs._label("Subject:", Vector2(10, 40)))
	var subj := LineEdit.new()
	subj.position = Vector2(60, 36)
	subj.size = Vector2(310, 22)
	c.add_child(subj)
	var txt := TextEdit.new()
	txt.position = Vector2(10, 66)
	txt.size = Vector2(360, 170)
	c.add_child(txt)
	var send: Button = os.button("Send")
	send.position = Vector2(206, 244)
	send.size = Vector2(75, 23)
	send.pressed.connect(func():
		var target := to.text.strip_edges()
		var s := subj.text if subj.text != "" else "(no subject)"
		os.close_dialog(dlg)
		if target == "":
			Dialogs.msgbox(os, "Mail", "You must specify at least one recipient.", "warn")
			return
		Dialogs.msgbox(os, "Mail", "Your message has been sent.", "info")
		_reply_later(target, s))
	c.add_child(send)
	var cancel: Button = os.button("Cancel")
	cancel.position = Vector2(290, 244)
	cancel.size = Vector2(75, 23)
	cancel.pressed.connect(func(): os.close_dialog(dlg))
	c.add_child(cancel)
	os.show_dialog(dlg, false)
	to.grab_focus()


func _reply_later(target: String, subj: String) -> void:
	await os.get_tree().create_timer(6.0).timeout
	var low := target.to_lower()
	var m: Dictionary
	if low.contains("kessler"):
		m = {"from": "R. Kessler", "subj": "Auto-reply: " + subj, "date": "Now", "unread": true,
			"body": "I am out of the office until further notice.\n\nIf your matter is urgent, check the floppy disk.\n\nIf somebody answers this message, it isn't me."}
	else:
		m = {"from": "MAILER-DAEMON", "subj": "Undeliverable: " + subj, "date": "Now", "unread": true,
			"body": "Your message to '%s' could not be delivered.\n\nReason: no route to host. The phone line may be busy." % target}
	os.mailbox.append(m)
	os.play("ding", -12.0)
	if is_instance_valid(list):
		_fill()
