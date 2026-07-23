extends GutTest

## Regression for the "only one choice shows" bug.
## Dialogic builds a choice question from CONSECUTIVE Choice events and BREAKS at the
## first non-choice base-level event (subsystem_choices.get_current_choice_indexes).
## So every decision's options must be contiguous — only indented branch bodies between
## them. A stray base-level [signal]/event splits the block so only ONE option shows.
## This simulates that exact grouping at the text level, per act.

const EXPECTED := {
	"act1": [3, 3],   # two decisions, 3 options each
	"act2": [3, 3],
	"act3": [],       # linear, no choices
	"act4": [3],
	"act5_good": [],
	"act5_neutral": [],
	"act5_bad": [],
}


func _indent(s: String) -> int:
	return s.length() - s.lstrip("\t").length()


## Mirrors get_current_choice_indexes: walk consecutive base-level "- " options,
## skipping each option's indented body, breaking at the first non-choice base line.
func _group_sizes(act: String) -> Array:
	var f := FileAccess.open("res://Dialogue/Acts/%s.dtl" % act, FileAccess.READ)
	assert_not_null(f, "open " + act)
	if f == null:
		return []
	var L := f.get_as_text().split("\n")
	f.close()
	var n := L.size()
	var groups: Array = []
	var i := 0
	while i < n:
		if _indent(L[i]) == 0 and L[i].strip_edges().begins_with("- "):
			var count := 0
			var j := i
			while j < n:
				if _indent(L[j]) == 0 and L[j].strip_edges().begins_with("- "):
					count += 1
					j += 1
					while j < n and (L[j].strip_edges() == "" or _indent(L[j]) > 0):
						j += 1
					if j < n and _indent(L[j]) == 0 and L[j].strip_edges().begins_with("- "):
						continue
					break
				else:
					break
			groups.append(count)
			i = j
		else:
			i += 1
	return groups


func test_every_decision_groups_all_its_options() -> void:
	for act in EXPECTED:
		var got := _group_sizes(act)
		assert_eq(got, EXPECTED[act] as Array, "%s: choice groups must match (each decision shows ALL its options)" % act)


func test_no_single_option_choice_blocks() -> void:
	# a 1-option group is the signature of a choice broken by an inter-option event
	for act in EXPECTED:
		var got := _group_sizes(act)
		for sz in got:
			assert_gt(sz, 1, "%s has a 1-option choice group — a broken/split decision" % act)
