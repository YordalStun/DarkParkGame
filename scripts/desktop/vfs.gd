extends RefCounted
## The computer's fake disk. Folders are Dictionaries {type:"dir", name, kids:{KEY: node}},
## files are {type:"file", name, text}. Lookups are case-insensitive, paths look like
## "C:\MY DOCUMENTS\SHIFT NOTES.TXT". Notepad and Paint can write new files here.

const RECYCLE := "C:\\RECYCLED"

const EXE_APPS := {
	"NOTEPAD.EXE": "notepad", "CALC.EXE": "calc", "PAINT.EXE": "paint", "WINMINE.EXE": "mines",
	"EXPLORER.EXE": "explorer", "COMMAND.COM": "dos", "NNEXPLOR.EXE": "browser", "CAMLINK.EXE": "camlink",
	"GATECTL.EXE": "gatectl", "MAIL.EXE": "mail", "CONTROL.EXE": "controlpanel",
}

var root := {"type": "dir", "name": "", "kids": {}}


func _init() -> void:
	_build()


# ---------------------------------------------------------------- queries
static func split(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for p in path.replace("/", "\\").split("\\"):
		if p != "":
			out.append(p)
	return out


static func join(a: String, b: String) -> String:
	if a.ends_with("\\"):
		return a + b
	return a + "\\" + b


static func parent_of(path: String) -> String:
	var parts := split(path)
	if parts.size() <= 1:
		return ""
	parts.remove_at(parts.size() - 1)
	var p := "\\".join(parts)
	return p + "\\" if parts.size() == 1 else p


static func base_name(path: String) -> String:
	var parts := split(path)
	return parts[parts.size() - 1] if parts.size() > 0 else ""


static func ext_of(name: String) -> String:
	var i := name.rfind(".")
	return name.substr(i + 1).to_upper() if i >= 0 else ""


func get_node(path: String) -> Variant:
	var n: Dictionary = root
	for p in split(path):
		if n.type != "dir":
			return null
		var k := p.to_upper()
		if not n.kids.has(k):
			return null
		n = n.kids[k]
	return n


func is_dir(path: String) -> bool:
	var n: Variant = get_node(path)
	return n != null and n.type == "dir"


## Folders first, then files, both alphabetical.
func list(path: String) -> Array:
	var n: Variant = get_node(path)
	if n == null or n.type != "dir":
		return []
	var dirs := []
	var files := []
	for k in n.kids:
		(dirs if n.kids[k].type == "dir" else files).append(n.kids[k])
	var cmp := func(a, b): return a.name.to_upper() < b.name.to_upper()
	dirs.sort_custom(cmp)
	files.sort_custom(cmp)
	return dirs + files


func read(path: String) -> String:
	var n: Variant = get_node(path)
	return n.text if n != null and n.type == "file" else ""


func write(path: String, text: String) -> bool:
	var dir_path := parent_of(path)
	var d: Variant = get_node(dir_path)
	if d == null or d.type != "dir":
		return false
	var name := base_name(path)
	d.kids[name.to_upper()] = {"type": "file", "name": name, "text": text}
	return true


func delete(path: String) -> bool:
	var d: Variant = get_node(parent_of(path))
	if d == null:
		return false
	return d.kids.erase(base_name(path).to_upper())


func make_dir(path: String) -> bool:
	var d: Variant = get_node(parent_of(path))
	if d == null or d.type != "dir":
		return false
	var name := base_name(path)
	if d.kids.has(name.to_upper()):
		return false
	d.kids[name.to_upper()] = {"type": "dir", "name": name, "kids": {}}
	return true


func size_of(n: Dictionary) -> int:
	if n.type == "dir":
		return 0
	return maxi(1, n.text.length()) if not n.has("bytes") else n.bytes


## Icon name for a node, based on its type and extension.
func icon_for(n: Dictionary) -> String:
	if n.type == "dir":
		return "folder"
	var up: String = n.name.to_upper()
	if EXE_APPS.has(up):
		match EXE_APPS[up]:
			"notepad": return "notepad"
			"calc": return "calc"
			"paint": return "paint"
			"mines": return "mine"
			"dos": return "dos"
			"browser": return "globe"
			"camlink": return "cam"
			"gatectl": return "gate"
			"mail": return "mail"
			"explorer": return "computer"
			"controlpanel": return "control"
	match ext_of(up):
		"EXE", "COM": return "app"
		"BMP": return "image"
		"WAV": return "speaker"
		_: return "doc"


func file_type_name(n: Dictionary) -> String:
	if n.type == "dir":
		return "File Folder"
	match ext_of(n.name):
		"TXT": return "Text Document"
		"EXE": return "Application"
		"COM": return "MS-DOS Application"
		"BAT": return "MS-DOS Batch File"
		"INI": return "Configuration Settings"
		"SYS": return "System file"
		"DLL": return "Application Extension"
		"BMP": return "Bitmap Image"
		"WAV": return "Wave Sound"
		"LOG": return "Text Document"
		"CFG": return "Configuration Settings"
		_: return "File"


# ------------------------------------------------------------------ content
func _dir(path: String) -> void:
	var parts := split(path)
	var n := root
	for p in parts:
		var k := p.to_upper()
		if not n.kids.has(k):
			n.kids[k] = {"type": "dir", "name": p, "kids": {}}
		n = n.kids[k]


func _file(path: String, text := "", bytes := -1) -> void:
	_dir(parent_of(path))
	write(path, text)
	if bytes >= 0:
		get_node(path)["bytes"] = bytes


func _build() -> void:
	for d in ["A:", "C:", "D:"]:
		_dir(d)
	root.kids["D:"]["notready"] = true
	for d in ["C:\\WINDOWS\\SYSTEM", "C:\\WINDOWS\\FONTS", "C:\\WINDOWS\\TEMP", "C:\\PROGRAM FILES\\NIGHTWATCH",
			"C:\\PROGRAM FILES\\ACCESSORIES", "C:\\MY DOCUMENTS", "C:\\NIGHT\\LOGS", "C:\\RECYCLED", "C:\\TEMP"]:
		_dir(d)

	_file("C:\\AUTOEXEC.BAT", "@ECHO OFF\nPROMPT $p$g\nPATH C:\\WINDOWS;C:\\WINDOWS\\COMMAND;C:\\NIGHT\nSET TEMP=C:\\TEMP\nC:\\NIGHT\\NWSLINK.COM /LOT:C /BOOTH:2\n")
	_file("C:\\CONFIG.SYS", "DEVICE=C:\\WINDOWS\\HIMEM.SYS\nDOS=HIGH,UMB\nFILES=40\nBUFFERS=20\nDEVICEHIGH=C:\\NIGHT\\CAMDRV.SYS /IRQ:5\n")
	_file("C:\\README.TXT", README)
	for exe in ["NOTEPAD.EXE", "CALC.EXE", "PAINT.EXE", "WINMINE.EXE", "EXPLORER.EXE", "CONTROL.EXE", "MAIL.EXE"]:
		_file("C:\\WINDOWS\\" + exe, "MZ", 24000 + exe.length() * 3111)
	_file("C:\\WINDOWS\\COMMAND.COM", "MZ", 93890)
	_file("C:\\WINDOWS\\NNEXPLOR.EXE", "MZ", 301568)
	_file("C:\\WINDOWS\\WIN.INI", "[windows]\nload=\nrun=\nNullPort=None\n\n[Desktop]\nWallpaper=(None)\nTileWallpaper=0\n\n[NightNet]\nHomePage=http://www.winnight.net/\n")
	_file("C:\\WINDOWS\\SYSTEM.INI", "[boot]\nshell=Explorer.exe\nlanguage=\n\n[386Enh]\nmouse=*vmouse\ndevice=C:\\NIGHT\\CAMDRV.SYS\n")
	for dll in ["KERNEL32.DLL", "USER32.DLL", "GDI32.DLL", "WININET.DLL", "COMCTL32.DLL", "MSVCRT.DLL"]:
		_file("C:\\WINDOWS\\SYSTEM\\" + dll, "MZ", 180000 + dll.length() * 9017)
	_file("C:\\WINDOWS\\FONTS\\ARIAL.TTF", "", 65000)
	_file("C:\\PROGRAM FILES\\NIGHTWATCH\\CAMLINK.EXE", "MZ", 412000)
	_file("C:\\PROGRAM FILES\\NIGHTWATCH\\GATECTL.EXE", "MZ", 88000)
	_file("C:\\PROGRAM FILES\\NIGHTWATCH\\README.TXT", NWS_README)
	_file("C:\\NIGHT\\GATE.CFG", "[gate]\nmode=MANUAL\nauto_close_s=45\nlamp=ON\n\n[remote]\nenabled=1\nport=COM2\n")
	_file("C:\\NIGHT\\CAMLINK.INI", "[links]\ncam1=ROW A  ... NO SIGNAL\ncam2=ROW B  ... NO SIGNAL\ncam3=ROW C  ... NO SIGNAL\ncam4=BOOTH  ... NO SIGNAL\n\n[service]\nlast_visit=Tue 3rd Oct\nnext_visit=\"next week\"\n")
	_file("C:\\NIGHT\\NWSLINK.COM", "MZ", 14210)
	_file("C:\\NIGHT\\LOGS\\OCT12.LOG", "22:41  VEHICLE IN   - plate ok\n23:12  VEHICLE OUT  - plate ok\n01:03  GATE ARM FAULT (self cleared)\n02:14  MOTION ROW C - no cause found\n02:14  MOTION ROW C - no cause found\n02:15  MOTION ROW C - no cause found\n02:16  OPERATOR LEFT BOOTH\n05:50  OPERATOR RETURNED\n06:00  SHIFT CHANGE\n")
	_file("C:\\MY DOCUMENTS\\SHIFT NOTES.TXT", SHIFT_NOTES)
	_file("C:\\MY DOCUMENTS\\PATROL.TXT", PATROL)
	_file("C:\\MY DOCUMENTS\\TO DO.TXT", "- buy batteries for the torch\n- ring mum back (Sunday)\n- ask Dale about the side door\n- stop looking at row C on the monitor\n")

	# Night three on: somebody left a hospital IT memo in the temp folder (the leaked IP address).
	if SaveGame.night() >= 3:
		_file("C:\\WINDOWS\\TEMP\\ITMEMO.TXT", IT_MEMO)

	# The floppy a previous operator left behind.
	_file("A:\\KESSLER.TXT", KESSLER)
	_file("A:\\LOT_C.BMP", "", 76854)

	# Things somebody deleted.
	_file("C:\\RECYCLED\\NOTES (OLD).TXT", RECYCLE_NOTES)
	_file("C:\\RECYCLED\\IMG_0013.BMP", "", 230454)
	_file("C:\\RECYCLED\\ROW C.WAV", "", 884210)
	_file("C:\\RECYCLED\\DO NOT OPEN.TXT", "I told you.\n")


const IT_MEMO := """ASHFORD GENERAL HOSPITAL  -  I.T. DEPARTMENT
INTERNAL MEMO  (DO NOT FORWARD, DO NOT LEAVE ON THE SHARED DRIVE)
=====================================================================

The remote clinic gateway is now live for out-of-hours staff.
To connect you need the MediCare Remote client. Download it from the
hospital site (www.ashfordgeneral.org, "Staff / Remote access") and run it.

   Host address:   10.113.7.20      (modem pool, answers 24 hours)
   User ID:        first initial, a dot, then surname.  e.g.  S.PIKE
   Password:       as issued by Personnel

Until the new system arrives, passwords stay as originally chosen.
Several staff told us that "something personal" is easiest to remember,
and we have decided that is fine for now.

Please do not write your password down.

Regards,
Keith, I.T. (ext. 3318)
"""

const README := """NIGHTWIN 95  -  NIGHTWATCH WORKSTATION EDITION
================================================

This computer is the property of Nightwatch Security Systems Ltd.
It is provided for the logging of vehicles, patrol times and gate
operations at Lot C only.

Unauthorised use is a disciplinary matter.

Programs are in the Start menu. Camera and gate controls are under
Programs > Nightwatch.

If anything on this machine stops responding, do not restart it
during a shift. Call the supervisor on extension 214.

Operators: please do not install games.
(Yes, we know about Minesweeper.)
"""

const NWS_README := """NIGHTWATCH CAMLINK  v1.3
Gate control module v1.1
------------------------------------------------
CAMLINK shows cameras 1-4 when the link is up.
GATECTL opens and closes the barrier arm remotely.

KNOWN ISSUES
 - Camera link reports NO SIGNAL after heavy rain.
 - Camera 3 occasionally reports MOTION when the lot is empty.
   This is a sensor fault. Do not log it as an incident.
 - Gate arm may self-cycle once at night. Cause unknown.
"""

const SHIFT_NOTES := """SHIFT NOTES - LOT C, BOOTH 2
------------------------------------
23:00  Took over from day shift. Nothing to report.
       Gate arm test OK. Patrol due at midnight.

REMINDERS
 - Log every vehicle that comes in after 22:00.
 - Camera links 1-4 are down since Tuesday's storm.
   Maintenance say "next week". They said that last week.
 - The torch is in the desk drawer. Batteries are new.
 - Do not use the side door once the lights go out in Row C.
   (Dale says that's a joke. I am not so sure it is.)
 - If the radio changes station by itself, leave it.
"""

const PATROL := """PATROL ROUTE - LOT C
--------------------
00:00  Gate, then Row A (left to right)
00:20  Row B, check the van with the flat tyre
00:40  Payphone - make sure the handset is back on its hook
01:00  Row C   << do this one quickly >>
01:15  Back to booth, sign the logbook

Walk, don't run. Don't shine the torch at the tree line.
"""

const KESSLER := """If you are reading this you have my old shift. Sorry.

I'm not a fanciful man. 22 years in the army and I never once
saw a thing I couldn't explain. Lot C is the first.

Things I wrote down, so I'd know I wasn't imagining them:

  * The car in row C. Dark saloon, no plates, always the third bay.
    It is there at 02:14. It is not there at 02:15. Nobody drives it.
  * The payphone rings. Only when it rains.
  * The gate arm lifts for nobody. I've watched the empty road.
  * Somebody uses this terminal when I'm on patrol. Files move.
    Windows are open when I get back.

Don't go looking. That's what I did.
Keep the radio on. It helps. I don't know why.

                                                - R. Kessler
"""

const RECYCLE_NOTES := """02:14  Row C
Car is back. Engine running.
No driver. Condensation inside the glass as if somebody
has been breathing in there for hours.

I went out to look.

I shouldn't have gone out to look.

Why is the booth light on if I'm still outside it
"""
