## 台本ファイル（godot/story/*.txt）を読む。書式は godot/story/README.md。
## The words and what sets them off live in the chapter files; story.gd and door.gd ask for a block by its name.
extends RefCounted

const FILES := ["ch1", "ch2_20", "ch2_23"]
static var blocks := {}        # name -> the block's lines as written (indent kept: a choice's answers are indented)

static func load_all():
	if not blocks.is_empty(): return
	for f in FILES:
		var p := "res://story/%s.txt" % f
		if not FileAccess.file_exists(p): print("SCRIPT ERROR 台本: no file ", p); continue
		var key := ""
		for raw in FileAccess.get_file_as_string(p).split("\n"):
			var ln := String(raw).strip_edges()
			if ln == "" or ln.begins_with("//"): continue
			if ln.begins_with("【") and ln.ends_with("】"):
				key = ln.substr(1, ln.length() - 2)
				if blocks.has(key): print("SCRIPT ERROR 台本: 【%s】 twice (%s)" % [key, p])
				blocks[key] = []
			elif key != "": blocks[key].append(String(raw).rstrip(" \t\r"))

static func has(key: String) -> bool:
	load_all(); return blocks.has(key)

## a block as story.gd plays it: [{who, text, testimony?, to?, t?} | {note} | {choose: [..], then: [[..], ..]} | {do}]
## arg: what a %s in the words stands for
static func entries(key: String, arg := "") -> Array:
	load_all()
	if not blocks.has(key): print("SCRIPT ERROR 台本: no 【%s】" % key); return []
	return _parse(blocks[key], arg)

## a block's lines as plain text (the radio's sentences, the looks at the door)
static func lines(key: String) -> Array:
	load_all()
	if not blocks.has(key): print("SCRIPT ERROR 台本: no 【%s】" % key); return []
	return blocks[key].map(func(x): return String(x).strip_edges())

static func _indented(raw: String) -> bool:
	return raw.begins_with(" ") or raw.begins_with("\t") or raw.begins_with("　")

static func _parse(src: Array, arg: String) -> Array:
	var out := []; var i := 0
	while i < src.size():
		var ln := String(src[i]).strip_edges()
		if ln.begins_with("？"):
			var ch := {"choose": [], "then": []}
			while i < src.size() and String(src[i]).strip_edges().begins_with("？") and not _indented(src[i]):
				ch.choose.append(String(src[i]).strip_edges().substr(1).strip_edges()); i += 1
				var sub := []
				while i < src.size() and _indented(src[i]): sub.append(String(src[i]).strip_edges()); i += 1
				ch.then.append(_parse(sub, arg))
			out.append(ch); continue
		out.append(_entry(ln, arg)); i += 1
	return out

static func _entry(ln: String, arg: String) -> Dictionary:
	var e := {}
	var sp := ln.find(" ")
	if sp > 0 and ln.substr(0, sp).is_valid_float(): e["t"] = float(ln.substr(0, sp)); ln = ln.substr(sp + 1).strip_edges()
	if ln.begins_with("＞"): e["do"] = ln.substr(1).strip_edges(); return e
	if ln.begins_with("［") or ln.begins_with("（"): e["note"] = ln; return e
	if ln.begins_with("◇"): e["mission"] = ln.substr(1).strip_edges(); return e   # 試作97: what she set out to do (top left, stays)
	var c := ln.find("：")
	if c < 0: e["text"] = ln; return e
	var who := ln.substr(0, c)
	if who.ends_with("＊"): e["testimony"] = true; who = who.substr(0, who.length() - 1)
	var to := who.find("→")
	if to > 0: e["to"] = who.substr(to + 1); who = who.substr(0, to)
	e["who"] = who
	e["text"] = ln.substr(c + 1).replace("%s", arg) if arg != "" else ln.substr(c + 1)
	return e
