extends Node
## The real web engine behind NightNet Explorer: Chromium, embedded through the
## gdCEF GDExtension (res://cef_artifacts, fetched by tools/fetch_cef.sh).
## Real sites, JavaScript and video (YouTube) work through it. If the extension is
## missing, available() is false and the browser falls back to its own simple
## HTML renderer.
##
## One engine per game; each browser window asks it for a page view.

var _cef: Node
var _failed := false


static func available() -> bool:
	return ClassDB.class_exists("GdCEF")


## Starts Chromium the first time it is needed. Returns false if it can't.
func ensure() -> bool:
	if _cef != null:
		return true
	if _failed or not available():
		return false
	_cef = ClassDB.instantiate("GdCEF")
	_cef.name = "Chromium"
	add_child(_cef)
	var ok: bool = _cef.initialize({
		"incognito": true,          # nothing written to disk between sessions
		"locale": "en-US",
		"log_severity": "error",
		"remote_debugging_port": 0,
		"enable_media_stream": false,
	})
	if not ok:
		push_warning("Web engine failed to start: %s" % _cef.get_error())
		print("EVENT web engine failed: ", _cef.get_error())
		_cef.queue_free()
		_cef = null
		_failed = true
		return false
	print("EVENT web engine started")
	return true


## A new page view drawing into `target` (a TextureRect).
func create_view(url: String, target: TextureRect) -> Object:
	if not ensure():
		return null
	return _cef.create_browser(url, target, {
		"frame_rate": 30,
		"javascript": true,
		"enable_ad_block": true,
		"allow_downloads": false,
		"user_gesture_required": false,   # let YouTube start playing after a click on the page
	})


func _exit_tree() -> void:
	if _cef != null:
		_cef.shutdown()
		_cef = null
