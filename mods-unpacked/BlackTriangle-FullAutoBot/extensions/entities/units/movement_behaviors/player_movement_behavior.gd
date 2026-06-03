extends "res://entities/units/movement_behaviors/player_movement_behavior.gd"

# Hand the player's movement vector over to BotRunner when the bot is active.
# Manual input (any direction key) takes priority — pressing a movement key
# yields control back to the human immediately.

var _bot_runner_cache: Node = null


func get_movement() -> Vector2:
	var human: Vector2 = .get_movement()
	var runner := _get_bot_runner()
	if runner == null or not runner.get("active"):
		return human
	if human.length() > 0.05:
		# Player took over — disable bot for the rest of the run.
		runner.set("active", false)
		return human
	return runner.current_move_vector


func _get_bot_runner() -> Node:
	if _bot_runner_cache != null and is_instance_valid(_bot_runner_cache):
		return _bot_runner_cache
	# Known ModLoader path: /root/ModLoader/<mod_id>/BotRunner
	var root := get_tree().get_root()
	var r = root.get_node_or_null("ModLoader/BlackTriangle-FullAutoBot/BotRunner")
	if r != null:
		_bot_runner_cache = r
		return r
	# Fallback: recursive scan up to a few levels.
	return _find_runner_recursive(root, 4)


func _find_runner_recursive(node: Node, depth: int) -> Node:
	if node == null or depth < 0:
		return null
	if node.name == "BotRunner":
		_bot_runner_cache = node
		return node
	for c in node.get_children():
		var r = _find_runner_recursive(c, depth - 1)
		if r != null:
			return r
	return null
