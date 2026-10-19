extends Node

## Loads every script and scene in the project, then checks a few invariants
## that are cheap to assert and expensive to discover on a study day.
##
## WHY THIS EXISTS, given the workflow already runs Godot:
##
## GDScript only parses a script when something loads it. `godot --headless
## --quit` boots the MAIN MENU and nothing else, so a parse error anywhere in
## phase_1.gd, phase_2.gd, robot.gd or any level scene passes it silently and
## ships. That is not hypothetical — `var actions := right_panel.assigned_...`
## could not infer a type from an untyped @onready, the boot check reported
## clean, and phase 2 would have gone live with no behaviour at all.
##
## Run from the workflow before the export:
##   godot --headless --path . res://tools/check_all.tscn
##
## It prints CHECK_ALL: OK or CHECK_ALL: FAILED as its last line. The workflow
## greps for that rather than trusting the exit code, which headless Godot does
## not always set the way you would hope.
##
## exclude_filter in export_presets.cfg keeps check_all.tscn out of the
## build. The .gd still rides along — Godot collects scripts separately
## from the filter — but nothing references it, so it is a few KB of
## inert text in a 3.8MB pck rather than anything that can run.
##
## It has to be a scene rather than `--script`, because `--script` does
## not register autoloads and this needs Global and DropSlot.

## Blocks whose integer must never move. Every program a student has written is
## stored as these numbers in events.payload.code, so renumbering one silently
## rewrites every run already recorded. Add to this list, never edit it.
const FROZEN_ACTION_IDS := {
	"MoveForward": 1,
	"MoveBackward": 2,
	"MoveRandom": 3,
	"TurnRight": 4,
	"TurnLeft": 5,
	"Turn180": 6,
	"TurnRandom": 7,
	"IsObstacleFront": 8,
	"IsObstacleRight": 9,
	"IsObstacleLeft": 10,
	"IsSpaceTravelledFront": 11,
	"IsSpaceTravelledRight": 12,
	"IsSpaceTravelledLeft": 13,
}


func _ready() -> void:
	var failures := 0
	failures += _check_everything_loads()
	failures += _check_action_ids_frozen()
	failures += _check_labels_are_drawable()

	print("")
	print("CHECK_ALL: OK" if failures == 0 else "CHECK_ALL: FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_everything_loads() -> int:
	var scripts: Array[String] = []
	var scenes: Array[String] = []
	_walk("res://", scripts, scenes)

	var bad := 0

	# load() is NOT enough on its own. A GDScript with a parse error still
	# comes back as a non-null object — verified against the real
	# "cannot infer the type" bug — so a null check alone passes everything
	# and the whole exercise is theatre.
	#
	# can_instantiate() is the signal that actually discriminates: false for a
	# script that failed to parse, true for one that compiled. reload() also
	# reports it, but returns ERR_ALREADY_IN_USE for anything already live —
	# which is every autoload, and this script — so it cannot be used here.
	for path in scripts:
		var script: Script = load(path)
		if script == null:
			print("  FAILED TO LOAD:   ", path)
			bad += 1
		elif not script.can_instantiate():
			print("  FAILED TO PARSE:  ", path)
			bad += 1

	# Scenes are checked with can_instantiate() rather than by instantiating:
	# building one headless runs _ready, and several of this project's scenes
	# block forever without a display server.
	for path in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			print("  FAILED TO LOAD:   ", path)
			bad += 1
		elif not packed.can_instantiate():
			print("  CANNOT INSTANTIATE: ", path)
			bad += 1

	print("loads:  %d scripts + %d scenes -> %s" % [
		scripts.size(), scenes.size(), "ok" if bad == 0 else "%d BROKEN" % bad])
	return bad


## Guards the one mistake the comments in global.gd warn about but cannot
## prevent: reordering CodeAction, which would redefine every logged program.
func _check_action_ids_frozen() -> int:
	var bad := 0
	for name in FROZEN_ACTION_IDS:
		var expected: int = FROZEN_ACTION_IDS[name]
		var actual: int = Global.CodeAction.get(name, -1)
		if actual != expected:
			print("  ACTION ID MOVED: %s is %d, must be %d — this redefines every program already in Supabase" % [
				name, actual, expected])
			bad += 1
	print("ids:    %d frozen action values -> %s" % [
		FROZEN_ACTION_IDS.size(), "ok" if bad == 0 else "%d MOVED" % bad])
	return bad


## Every character a block prints has to exist in the slot font. KG Red Hands
## has no arrow glyphs at all, so a perfectly reasonable "↳" rendered as an
## empty box and only a screenshot caught it.
func _check_labels_are_drawable() -> int:
	var font: FontFile = load("res://Fonts/KGRedHands.ttf")
	if font == null:
		print("  slot font missing")
		return 1

	var bad := 0
	var texts: Array[String] = []
	for action in Global.CodeAction.values():
		if action != Global.CodeAction.NULL:
			texts.append(Global.display_name(action))
	texts.append(DropSlot.GUARD_PREFIX)

	for text in texts:
		for i in range(text.length()):
			var c := text.unicode_at(i)
			if c == 32:
				continue
			if not font.has_char(c):
				print("  UNDRAWABLE: \"%s\" contains U+%04X, which KG Red Hands lacks" % [text, c])
				bad += 1
				break

	print("glyphs: %d labels -> %s" % [texts.size(), "ok" if bad == 0 else "%d UNDRAWABLE" % bad])
	return bad


## addons/ is skipped: it is third-party, some of it is editor-only, and a
## failure there is not something this project can act on.
func _walk(dir_path: String, scripts: Array[String], scenes: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				_walk(full, scripts, scenes)
		elif entry.ends_with(".gd"):
			scripts.append(full)
		elif entry.ends_with(".tscn"):
			scenes.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
