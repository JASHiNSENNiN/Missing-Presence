extends GutTest


const ACT_DIR := "res://Dialogue/Acts/"
const ACTS := ["act1", "act2", "act3", "act4", "act5_bad", "act5_good", "act5_neutral"]
const EXPECTED_CHOICES := {"act1": 6, "act2": 6, "act3": 0, "act4": 3}


func _lines(act: String) -> PackedStringArray:
	var f := FileAccess.open(ACT_DIR + act + ".dtl", FileAccess.READ)
	assert_not_null(f, "cannot open " + act)
	if f == null:
		return PackedStringArray()
	var text := f.get_as_text()
	f.close()
	return text.split("\n")


func _hits(pattern: String) -> Array:
	var re := RegEx.new()
	assert_eq(re.compile(pattern), OK, "bad regex: " + pattern)
	var found: Array = []
	for act in ACTS:
		var n := 0
		for line in _lines(act):
			n += 1
			if re.search(line) != null:
				found.append("%s:%d  %s" % [act, n, line.strip_edges()])
	return found


func test_no_leaked_choice_or_route_markers() -> void:
	# screenplay labels the conversion must never surface as dialogue
	var checks := {
		"choice label (CHOICE/CHOCIE X:)": "^\\s*CHO[A-Za-z]*IE?\\s+[ABC]\\s*:",
		"route marker": "^\\s*(GOOD|NEUTRAL|BAD|STRAIGHT)\\s+ROUTE",
		"conditional trigger": "CONDITIONAL TRIGGER",
		"perspective shift": "PERSPECTIVE SHIFT",
		"phone ui marker": "PHONE UI APPEARS",
	}
	for label in checks:
		var hits := _hits(checks[label])
		assert_eq(hits.size(), 0, "leaked %s:\n%s" % [label, "\n".join(hits)])


func test_no_divider_runs() -> void:
	var hits := _hits("[\\x{2014}\\x{2013}]{2,}|-{15,}|_{15,}")
	assert_eq(hits.size(), 0, "leaked divider runs:\n%s" % "\n".join(hits))


func test_no_possessive_or_list_missplit_speakers() -> void:
	# "Jennifer: 's smile fades." / "Maya: , Jennifer, and..." = narration mis-parsed as speech
	var possessive := _hits("^\\s*[A-Z][a-z]+:\\s*'?s[ .]")
	assert_eq(possessive.size(), 0, "possessive narration mis-split as speaker:\n%s" % "\n".join(possessive))
	var listing := _hits("^\\s*[A-Z][a-z]+:\\s*,\\s")
	assert_eq(listing.size(), 0, "character-list narration mis-split as speaker:\n%s" % "\n".join(listing))


func test_choice_option_counts_match_source() -> void:
	for act in EXPECTED_CHOICES:
		var count := 0
		for line in _lines(act):
			if line.begins_with("- "):
				count += 1
		assert_eq(count, EXPECTED_CHOICES[act], "%s choice-option count drifted from the script" % act)


func test_choice_labels_are_not_bloated_with_narration() -> void:
	# a choice button is a short label; a very long "- " line means narration got glued on
	var long_opts: Array = []
	for act in ACTS:
		var n := 0
		for line in _lines(act):
			n += 1
			if line.begins_with("- ") and line.length() > 90:
				long_opts.append("%s:%d (%d chars)" % [act, n, line.length()])
	assert_eq(long_opts.size(), 0, "choice options with glued narration:\n%s" % "\n".join(long_opts))


func test_conditional_chains_are_well_formed() -> void:
	# an 'elif' must never follow an 'else' at the same indent (route branch unreachable)
	var problems: Array = []
	for act in ACTS:
		var seen_else := {}
		var n := 0
		for line in _lines(act):
			n += 1
			var s := line.strip_edges()
			var indent := line.length() - line.lstrip("\t").length()
			if s.begins_with("if ") and s.ends_with(":"):
				seen_else.erase(indent)
			elif s == "else:":
				seen_else[indent] = n
			elif s.begins_with("elif ") and s.ends_with(":"):
				if seen_else.has(indent):
					problems.append("%s: else@%d then elif@%d" % [act, seen_else[indent], n])
	assert_eq(problems.size(), 0, "malformed else-before-elif chains:\n%s" % "\n".join(problems))
