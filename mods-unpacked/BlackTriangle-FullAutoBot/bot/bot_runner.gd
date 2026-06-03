extends Node

# Main bot loop. Replaces the Python WebSocket client of the old prototype:
# everything runs in-process so the mod is self-contained (no external deps).
#
# Activated by the robot button on the difficulty screen — sets `active=true`,
# from then on _physics_process drives shop / level-up / crate / movement
# decisions until run end.

const LOG_NAME = "BlackTriangle:FullAutoBot:Runner"

# Set by difficulty_selection_ext when the user clicks the robot button.
var active: bool = false
# Movement direction applied by player_movement_behavior_ext via the
# bot.current_move_vector path.
var current_move_vector: Vector2 = Vector2.ZERO

# Decision sub-systems (instantiated once). Use preload paths instead of
# class_name references so the script parses cleanly even before ModLoader
# has registered the mod's class_name table.
const _PROFILES_SCRIPT = preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/build_profiles.gd")
const _SHOP_SCRIPT = preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/shop_strategy.gd")
const _FIELD_SCRIPT = preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/potential_field.gd")
var _profiles
var _shop
var _field

# Action throttle (the game UI doesn't react well to back-to-back inputs).
var _last_shop_action_at: float = 0.0
var _last_levelup_action_at: float = 0.0
var _last_crate_action_at: float = 0.0
const ACTION_INTERVAL = 0.25

# Stat names whose live values we need for combat valuation.
const _STAT_NAMES = [
	"max_hp", "armor", "dodge", "speed", "hp_regeneration", "lifesteal",
	"crit_chance", "crit_damage", "attack_speed", "percent_damage", "damage",
	"ranged_damage", "melee_damage", "elemental_damage", "range",
	"harvesting", "engineering", "luck",
]


func _ready() -> void:
	_profiles = _PROFILES_SCRIPT.new()
	_shop = _SHOP_SCRIPT.new()
	_field = _FIELD_SCRIPT.new()
	ModLoaderLog.info("BotRunner ready", LOG_NAME)


func _physics_process(_delta: float) -> void:
	# PlayerMovementBehavior extension reads `current_move_vector` directly
	# (bypasses Input.action_press, which only supports unit-strength axis
	# components — diagonal moves stuttered). Just keep the vector updated.
	if not active:
		current_move_vector = Vector2.ZERO
		return
	var scene = get_tree().current_scene
	if scene == null: return
	if scene is Main:
		_handle_combat(scene)
		return
	if scene is BaseShop:
		current_move_vector = Vector2.ZERO
		_handle_shop(scene)
		return
	current_move_vector = Vector2.ZERO
	_handle_overlay(scene)


# ───────────────────────────── combat ─────────────────────────────────────────

var _flee_tick := 0
func _handle_combat(main) -> void:
	var state = _gather_combat_state(main)
	if state.empty():
		current_move_vector = Vector2.ZERO
		return
	var profile = _profiles.get_profile(state.get("character", ""))
	# Throttle flee strategies (Pacifist sampling / Beast Master orbital /
	# Bull / Wounded pure-repulsion) to 30Hz — matches the inertia the
	# Python prototype had at 20Hz. Without this, two symmetric projectiles
	# whose forces cancel keep the bot frozen on every 60Hz tick. At half
	# rate the prev_move momentum carries the bot through the cancellation.
	if profile.flee_mode:
		_flee_tick += 1
		if _flee_tick % 2 == 0:
			# Skip recompute — leave current_move_vector as-is so PlayerMovement
			# extension keeps applying the last decision.
			_handle_overlay(main)
			return
	current_move_vector = _field.compute_movement(state, profile)
	# Drive overlays that can fire mid-wave (level-up / crate).
	_handle_overlay(main)


func _gather_combat_state(main) -> Dictionary:
	var state = {
		"phase": "combat",
		"wave": RunData.current_wave,
		"character": _character_id(),
	}
	var es = main.get_node_or_null("EntitySpawner")
	if es == null: return state

	# Player
	var players = []
	for p in es._players:
		if not is_instance_valid(p) or p.dead: continue
		players.append({
			"x": p.global_position.x,
			"y": p.global_position.y,
			"hp": p.current_stats.health,
			"max_hp": p.max_stats.health,
			"speed": p.max_stats.speed,
		})
	state["players"] = players
	if not players.empty(): state["player"] = players[0]

	# Enemies / bosses
	var enemies = []
	for e in es.enemies:
		if not is_instance_valid(e) or e.dead: continue
		enemies.append({"x": e.global_position.x, "y": e.global_position.y,
			"hp": e.current_stats.health, "speed": e.current_stats.speed})
	state["enemies"] = enemies

	var bosses = []
	for b in es.bosses:
		if not is_instance_valid(b) or b.dead: continue
		bosses.append({"x": b.global_position.x, "y": b.global_position.y,
			"hp": b.current_stats.health, "speed": b.current_stats.speed})
	state["bosses"] = bosses

	# Projectiles
	var projs = []
	var projs_node = main.get_node_or_null("%EnemyProjectiles")
	if projs_node:
		for proj in projs_node.get_children():
			if not is_instance_valid(proj) or not proj.visible: continue
			if not ("global_position" in proj): continue
			var vel = Vector2.ZERO
			if "velocity" in proj:
				vel = proj.velocity
			projs.append({"x": proj.global_position.x, "y": proj.global_position.y,
				"vx": vel.x, "vy": vel.y})
	state["projectiles"] = projs

	# Loot
	var loot = []
	var mats = main.get_node_or_null("%Materials")
	if mats:
		for item in mats.get_children():
			if not is_instance_valid(item) or not item.visible: continue
			loot.append({"x": item.global_position.x, "y": item.global_position.y})
	state["loot"] = loot

	# Consumables (fruits etc)
	var cons = []
	var cons_node = main.get_node_or_null("%Consumables")
	if cons_node:
		for c in cons_node.get_children():
			if not is_instance_valid(c) or not c.visible: continue
			cons.append({"x": c.global_position.x, "y": c.global_position.y})
	state["consumables"] = cons

	# Weapons (with max_range — drives engagement distance)
	var weapons = []
	for w in RunData.get_player_weapons(0):
		if w == null or w.stats == null: continue
		weapons.append({
			"type": "ranged" if w.type == 1 else "melee",
			"max_range": w.stats.max_range,
			"damage": w.stats.damage,
			"cooldown": w.stats.cooldown,
		})
	state["weapons"] = weapons

	# Stand-still check input for Soldier
	state["can_attack_while_moving"] = RunData.get_player_effect(Keys.can_attack_while_moving_hash, 0) > 0

	# Arena
	var zone_data = _get_current_zone_data()
	if zone_data:
		state["arena"] = {"width": zone_data.width * 64, "height": zone_data.height * 64}
	else:
		state["arena"] = {"width": 2048, "height": 1536}
	return state


# ───────────────────────────── shop ───────────────────────────────────────────

func _handle_shop(shop) -> void:
	current_move_vector = Vector2.ZERO
	var now = OS.get_ticks_msec() / 1000.0
	if now - _last_shop_action_at < ACTION_INTERVAL: return
	var state = _gather_shop_state(shop)
	if state.empty(): return
	var profile = _profiles.get_profile(state.get("character", ""))
	var action: Dictionary = _shop.decide_shop(state, profile)
	if action.empty() or action.get("type", "") == "shop_go":
		_shop_go(shop)
	else:
		_apply_shop_action(shop, action)
	_last_shop_action_at = now


func _gather_shop_state(shop) -> Dictionary:
	var gold: int = RunData.get_player_gold(0)
	var state = {
		"phase": "shop",
		"wave": RunData.current_wave,
		"gold": gold,
		"character": _character_id(),
	}
	var reroll_price: int = 0
	if "_reroll_price" in shop and shop._reroll_price.size() > 0:
		reroll_price = shop._reroll_price[0]
	state["reroll_price"] = reroll_price

	var items = []
	var container = shop._get_shop_items_container(0)
	if container != null:
		for i in container._shop_items.size():
			var node = container._shop_items[i]
			if node == null or not node.active or node.item_data == null: continue
			var data = node.item_data
			var entry = {
				"slot": i,
				"id": data.my_id,
				"price": node.value,
				"tier": data.tier,
				"category": _item_category(data),
				"affordable": gold >= node.value,
				"locked": node.locked,
				"effects": _effects_to_list(data.effects),
				"tags": _item_tags(data),
				"locks_weapons": _item_locks_weapons(data),
				"blocks_healing": _item_blocks_healing(data),
			}
			if data is WeaponData:
				entry["weapon_type"] = "ranged" if data.type == 1 else "melee"
				entry["weapon_id"] = data.weapon_id
				entry["sets"] = _weapon_sets(data)
				entry["upgrades"] = data.upgrades_into != null and data.tier + 1 <= RunData.get_player_effect(Keys.max_weapon_tier_hash, 0)
				entry["can_buy"] = container._can_weapon_be_bought(node)
				entry["usable"] = _weapon_usable(data)
				if data.stats != null:
					entry["damage"] = data.stats.damage
					entry["cooldown"] = data.stats.cooldown
					entry["scaling"] = _weapon_scaling(data.stats)
					entry["crit_chance"] = data.stats.crit_chance
					entry["crit_damage"] = data.stats.crit_damage
					entry["is_healing"] = data.stats.is_healing
			items.append(entry)
	state["shop_items"] = items
	state["build"] = _build_dict()
	return state


func _apply_shop_action(shop, action: Dictionary) -> void:
	match action.get("type", ""):
		"shop_buy":
			var slot: int = int(action.get("slot", -1))
			var container = shop._get_shop_items_container(0)
			if container != null and slot >= 0 and slot < container._shop_items.size():
				var node = container._shop_items[slot]
				if node != null and node.active:
					container.on_shop_item_buy_button_pressed(node)
		"shop_lock", "shop_unlock":
			var slot: int = int(action.get("slot", -1))
			var container = shop._get_shop_items_container(0)
			if container != null and slot >= 0 and slot < container._shop_items.size():
				var node = container._shop_items[slot]
				if node != null and node.active:
					node.change_lock_status(action["type"] == "shop_lock")
		"shop_reroll":
			shop._on_RerollButton_pressed(0)
		"shop_combine":
			var idx: int = int(action.get("index", -1))
			var weapons = RunData.get_player_weapons(0)
			if idx >= 0 and idx < weapons.size():
				shop._on_item_combine_button_pressed(weapons[idx], 0)
		"shop_sell":
			var idx: int = int(action.get("index", -1))
			var weapons = RunData.get_player_weapons(0)
			if idx >= 0 and idx < weapons.size():
				shop._on_item_discard_button_pressed(weapons[idx], 0)


func _shop_go(shop) -> void:
	# Brotato names the "next wave" button GoButton. Method takes a player index.
	if shop.has_method("_on_GoButton_pressed"):
		shop._on_GoButton_pressed(0)
	elif shop.has_method("_on_ContinueButton_pressed"):
		shop._on_ContinueButton_pressed()


# ───────────────────────── level-up / crate overlay ───────────────────────────

func _handle_overlay(scene) -> void:
	var ui = _get_upgrades_ui(scene)
	if ui == null or not ui.visible:
		return
	var pc = ui._get_player_container(0) if ui.has_method("_get_player_container") else null
	if pc == null or not pc.visible:
		return

	var now = OS.get_ticks_msec() / 1000.0

	# Crate (item box from a chest): pc._items_container visible + _item_data set.
	if "_items_container" in pc and pc._items_container != null and pc._items_container.visible:
		if now - _last_crate_action_at < ACTION_INTERVAL:
			return
		_handle_crate_overlay(pc)
		_last_crate_action_at = now
		return

	# Level-up
	if now - _last_levelup_action_at < ACTION_INTERVAL:
		return

	var uis: Array = []
	if pc.has_method("_get_upgrade_uis"):
		uis = pc._get_upgrade_uis()
	var options: Array = []
	for i in range(uis.size()):
		var u = uis[i]
		if u == null or not u.visible: continue
		var data = u.get("upgrade_data") if "upgrade_data" in u else null
		if data == null: continue
		options.append({
			"index": i,
			"effects": _effects_to_list(data.effects),
			"tier": data.tier if "tier" in data else 0,
		})
	if options.empty():
		return

	var profile = _profiles.get_profile(_character_id())
	var state = {
		"options": options,
		"wave": RunData.current_wave,
		"gold": RunData.get_player_gold(0),
		"reroll_price": 0,
		"reroll_count": 0,
		"build": _build_dict(),
	}
	var action: Dictionary = _shop.decide_levelup(state, profile)
	match action.get("type", ""):
		"levelup_choose":
			var idx: int = int(action.get("index", -1))
			if idx >= 0 and idx < uis.size():
				var data = uis[idx].get("upgrade_data") if "upgrade_data" in uis[idx] else null
				if data != null:
					pc._on_choose_button_pressed(data)
		"levelup_reroll":
			if pc.has_method("_on_RerollButton_pressed"):
				pc._on_RerollButton_pressed()
	_last_levelup_action_at = now


func _handle_crate_overlay(pc) -> void:
	# pc._item_data carries the offered item (weapon or item).
	var item_data = pc.get("_item_data") if "_item_data" in pc else null
	if item_data == null:
		# Consumables show up here too — let the game auto-take.
		if pc.has_method("_on_TakeButton_pressed"):
			pc._on_TakeButton_pressed()
		return
	var item := {
		"id": item_data.my_id if "my_id" in item_data else "",
		"tier": item_data.tier if "tier" in item_data else 0,
		"effects": _effects_to_list(item_data.effects) if "effects" in item_data else [],
		"tags": item_data.tags if "tags" in item_data and item_data.tags != null else [],
	}
	# Mark weapons separately so shop_strategy can apply allow_melee/allow_ranged.
	if item_data is WeaponData:
		item["category"] = "weapon"
		item["weapon_type"] = "ranged" if item_data.type == 1 else "melee"
	else:
		item["category"] = "item"
	var profile = _profiles.get_profile(_character_id())
	var state = {
		"item": item,
		"wave": RunData.current_wave,
		"build": _build_dict(),
	}
	var action: Dictionary = _shop.decide_crate(state, profile)
	if action.get("type", "") == "crate_take" and pc.has_method("_on_TakeButton_pressed"):
		pc._on_TakeButton_pressed()
	elif pc.has_method("_on_DiscardButton_pressed"):
		pc._on_DiscardButton_pressed()


# ─────────────────────── shared helpers (ported from old mod) ─────────────────

func _get_active_player_container():
	var scene = get_tree().current_scene
	if scene == null: return null
	if scene.get("_entity_spawner") == null: return null
	var ui = _get_upgrades_ui(scene)
	if ui == null: return null
	if ui.has_method("_get_player_container"):
		return ui._get_player_container(0)
	return null


func _get_upgrades_ui(scene):
	if "_upgrades_ui" in scene: return scene._upgrades_ui
	if scene.has_method("get_node_or_null"):
		return scene.get_node_or_null("%UpgradesUI")
	return null


func _character_id() -> String:
	var c = RunData.get_player_character(0)
	return c.my_id if c != null else ""


func _get_current_zone_data():
	for zone in ZoneService.zones:
		if zone.my_id == RunData.current_zone:
			return zone
	if ZoneService.zones.size() > 0:
		return ZoneService.zones[0]
	return null


func _build_dict() -> Dictionary:
	var weapons = []
	for w in RunData.get_player_weapons(0):
		if w == null: continue
		var entry = {
			"id": w.my_id,
			"tier": w.tier,
			"type": "ranged" if w.type == 1 else "melee",
			"sets": _weapon_sets(w),
			"upgrades": w.upgrades_into != null and w.tier + 1 <= RunData.get_player_effect(Keys.max_weapon_tier_hash, 0),
			"index": RunData.get_player_weapons(0).find(w),
			"weapon_id": w.weapon_id,
		}
		if w.stats != null:
			entry["damage"] = w.stats.damage
			entry["cooldown"] = w.stats.cooldown
			entry["scaling"] = _weapon_scaling(w.stats)
			entry["crit_chance"] = w.stats.crit_chance
			entry["crit_damage"] = w.stats.crit_damage
			entry["is_healing"] = w.stats.is_healing
			entry["sell_value"] = ItemService.get_recycling_value(RunData.current_wave, w.value, 0, true)
		weapons.append(entry)
	return {
		"weapons": weapons,
		"stats": _current_stats(),
		"gain_mods": _stat_gain_mods(),
		"caps": _stat_caps(),
		"weapon_slots": RunData.get_player_effect(Keys.weapon_slot_hash, 0),
		"can_sell": not RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, 0),
	}


func _weapon_sets(w) -> Array:
	var out = []
	if "sets" in w and w.sets != null:
		for s in w.sets:
			if s != null and "my_id" in s: out.append(s.my_id)
	return out


func _item_tags(data) -> Array:
	if "tags" in data and data.tags != null: return data.tags
	return []


func _item_locks_weapons(data) -> bool:
	if not ("effects" in data) or data.effects == null: return false
	for e in data.effects:
		if e == null: continue
		if "key" in e and e.key == "lock_current_weapons": return true
	return false


func _item_blocks_healing(data) -> bool:
	if not ("effects" in data) or data.effects == null: return false
	for e in data.effects:
		if e == null: continue
		if "key" in e and (e.key == "no_heal" or e.key == "dmg_when_heal"): return true
	return false


func _item_category(data) -> String:
	if data is WeaponData: return "weapon"
	return "item"


func _effects_to_list(effects) -> Array:
	var out = []
	if effects == null: return out
	for e in effects:
		if e == null: continue
		var entry = {"key": "", "value": 0, "sign": 3}
		if "key" in e: entry["key"] = e.key
		if "value" in e: entry["value"] = e.value
		if "effect_sign" in e: entry["sign"] = e.effect_sign
		out.append(entry)
	return out


func _current_stats() -> Dictionary:
	var out = {}
	for n in _STAT_NAMES:
		out["stat_" + n] = Utils.get_stat(Keys.generate_hash("stat_" + n), 0)
	return out


func _stat_caps() -> Dictionary:
	return {
		"stat_dodge": RunData.get_player_effect(Keys.generate_hash("dodge_cap"), 0),
		"stat_crit_chance": RunData.get_player_effect(Keys.generate_hash("crit_chance_cap"), 0),
		"stat_speed": RunData.get_player_effect(Keys.generate_hash("speed_cap"), 0),
	}


func _stat_gain_mods() -> Dictionary:
	var out = {}
	var c = RunData.get_player_character(0)
	if c == null: return out
	for eff in c.effects:
		if eff != null and "stats_modified" in eff and eff.stats_modified != null:
			for st in eff.stats_modified:
				out[st] = out.get(st, 0) + eff.value
	return out


func _weapon_scaling(stats) -> Array:
	var out = []
	if "scaling_stats" in stats and stats.scaling_stats != null:
		for s in stats.scaling_stats:
			if s.size() >= 2:
				var key = s[0]
				if typeof(key) == TYPE_INT:
					key = Keys.hash_to_string[key] if Keys.hash_to_string.has(key) else ""
				if key != "":
					out.append([key, s[1]])
	return out


func _weapon_usable(data) -> bool:
	var max_t = RunData.get_player_effect(Keys.max_weapon_tier_hash, 0)
	var min_t = RunData.get_player_effect(Keys.min_weapon_tier_hash, 0)
	if data.tier > max_t or data.tier < min_t: return false
	if RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, 0) and data.type == 0: return false
	if RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, 0) and data.type == 1: return false
	return true
