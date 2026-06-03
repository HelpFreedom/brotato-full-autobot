extends "res://ui/menus/run/difficulty_selection/difficulty_selection.gd"

# Adds a "Full Auto Bot" robot button on the difficulty selection screen.
# Clicking it activates BotRunner and starts a Danger 6 run via the regular
# "_on_element_pressed" flow so save/progression stay consistent.

const _ICON_PATH := "res://mods-unpacked/BlackTriangle-FullAutoBot/assets/bot_button.png"


func _ready() -> void:
	._ready()
	_install_bot_button()


func _install_bot_button() -> void:
	# Mirror the look of regular InventoryElement buttons: vanilla `Button`,
	# 96×96 with an icon, sized to flow in the same GridContainer row as D0-D6.
	# Adding as a child of _inventory1 (the GridContainer itself) puts the
	# button in the next free cell of the grid -> visually one row, no overlap.
	if _inventory1 == null:
		return
	var btn := Button.new()
	btn.name = "BotAutoplayButton"
	btn.rect_min_size = Vector2(96, 96)
	btn.icon_align = Button.ALIGN_CENTER
	btn.expand_icon = true
	var tex := _load_icon()
	if tex != null:
		btn.icon = tex
	# No hint_tooltip — Brotato's tooltip overlay is too intrusive for a
	# corner button.
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_ALL
	btn.connect("pressed", self, "_on_bot_button_pressed")
	_inventory1.add_child(btn)


func _load_icon() -> Texture:
	# PNGs shipped inside a mod zip don't have .import metadata, so Godot's
	# resource loader can't decode them. Read the raw bytes via File (which
	# DOES go through the virtual filesystem ModLoader registered) and build
	# an ImageTexture at runtime.
	var tex: Texture = load(_ICON_PATH) as Texture
	if tex != null:
		return tex
	var f := File.new()
	if f.open(_ICON_PATH, File.READ) == OK:
		var buf := f.get_buffer(f.get_len())
		f.close()
		var img := Image.new()
		if img.load_png_from_buffer(buf) == OK:
			var itex := ImageTexture.new()
			itex.create_from_image(img, 0)
			return itex
	return null


func _on_bot_button_pressed() -> void:
	if difficulty_selected:
		return
	# Activate bot driver (autoload root is whatever ModLoader named the
	# mod's mod_main; iterate children of /root looking for our BotRunner).
	var runner = _find_bot_runner()
	if runner != null:
		runner.set("active", true)
	else:
		printerr("[BlackTriangle:FullAutoBot] BotRunner not found in /root tree")
	# Click the D6 element (Inventory1's children include all difficulty buttons).
	var d6 = _find_difficulty_element(6)
	if d6 != null:
		_on_element_pressed(d6, 0)


func _find_bot_runner() -> Node:
	# Known ModLoader path: /root/ModLoader/<mod_id>/BotRunner. Recursive scan
	# is the fallback in case ModLoader changes its container path.
	var root := get_tree().get_root()
	var r = root.get_node_or_null("ModLoader/BlackTriangle-FullAutoBot/BotRunner")
	if r != null:
		return r
	return _find_node_by_name(root, "BotRunner", 4)


func _find_node_by_name(node: Node, target: String, depth: int) -> Node:
	if node == null or depth < 0:
		return null
	if node.name == target:
		return node
	for c in node.get_children():
		var r = _find_node_by_name(c, target, depth - 1)
		if r != null:
			return r
	return null


func _find_difficulty_element(value: int):
	if _inventory1 == null:
		return null
	# Inventory1 is a GridContainer holding InventoryElement nodes; iterate
	# children directly rather than relying on a get_elements() helper.
	for el in _inventory1.get_children():
		if el != null and "item" in el and el.item != null and el.item.value == value:
			return el
	return null
