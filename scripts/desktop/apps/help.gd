extends Control
## A tiny help viewer.

const W95 := preload("res://scripts/desktop/w95.gd")

const TEXT := """[b]NightWin 95 Help[/b]

[b]Starting programs[/b]
Click Start, then Programs. Double-click an icon on the desktop to open it.

[b]Moving windows[/b]
Drag the blue title bar. Drag an edge to resize. Double-click the title bar to maximise.

[b]The Internet[/b]
Open NightNet Explorer. The first time you go online the modem will dial. Type an address
(like www.winnight.net) or a few words to search.

[b]Gate and cameras[/b]
Programs > Nightwatch has Gate Control and CamLink.

[b]Saving work[/b]
Notepad saves into My Documents.

[b]Leaving[/b]
Choose Start > Shut Down. "Restart in MS-DOS mode" takes you back to the green terminal.

[b]Something wrong?[/b]
Call the supervisor on extension 214. Do not restart the machine during a shift.
"""


func setup(os: Node, _win: Control, _args: Dictionary) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = TEXT
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 4
	r.offset_top = 4
	r.offset_right = -4
	r.offset_bottom = -4
	r.add_theme_stylebox_override("normal", W95.field())
	r.selection_enabled = true
	add_child(r)
