extends Reference
class_name BotBuildProfiles

const BotBuildProfile := preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/build_profile.gd")

# Registry of per-character build identities. Each entry is a Dictionary that
# overrides defaults in BotBuildProfile. get_profile(character_id) returns the
# right profile (falling back to DEFAULT for unknown ids).
#
# Godot 3 doesn't allow `static var`, so we instantiate this registry once
# (BotRunner owns the instance) and look up via instance methods.

var _cache := {}
var _default: BotBuildProfile


func _init() -> void:
	_default = BotBuildProfile.new()
	_default.name = "default"
	var specs = _profile_specs()
	for cid in specs:
		var p := BotBuildProfile.new()
		p.init_from_dict(specs[cid])
		_cache[cid] = p


func get_profile(character_id: String) -> BotBuildProfile:
	if _cache.has(character_id):
		return _cache[character_id]
	return _default


# Every named profile. Field names match BotBuildProfile vars. Strings used
# instead of Python's list literals because GDScript dicts are JSON-clean.
func _profile_specs() -> Dictionary:
	return {
		"character_ranger": {
			"name": "ranger",
			"wanted_tags": ["stat_ranged_damage", "stat_range"],
			"allow_melee": false,
			"preferred_sets": ["set_gun", "set_precise", "set_ethereal"],
			"set_synergy": 10.0, "engage_scale": 1.30, "dodge_caution": 1.20,
		},
		"character_soldier": {
			"name": "soldier",
			"wanted_tags": ["stand_still"],
			"allow_melee": false,
			"preferred_sets": ["set_gun", "set_precise"],
			"set_synergy": 9.0, "engage_scale": 1.10, "dodge_caution": 1.15,
		},
		"character_brawler": {
			"name": "brawler",
			"wanted_tags": ["stat_melee_damage"],
			"allow_ranged": false,
			"preferred_sets": ["set_unarmed", "set_precise"],
			"set_synergy": 11.0, "engage_scale": 0.90, "dodge_caution": 1.0,
		},
		"character_crazy": {
			"name": "crazy",
			"wanted_tags": ["stat_crit_chance", "stat_melee_damage"],
			"preferred_sets": ["set_precise"],
			"set_synergy": 10.0, "engage_scale": 1.15, "dodge_caution": 1.25,
		},
		"character_mage": {
			"name": "mage",
			"wanted_tags": ["stat_elemental_damage"],
			"preferred_sets": ["set_elemental"],
			"set_synergy": 11.0, "engage_scale": 1.10, "dodge_caution": 1.05,
		},
		"character_chunky": {
			"name": "chunky",
			"wanted_tags": ["stat_max_hp", "consumable", "stat_luck"],
			"set_synergy": 8.0, "engage_scale": 1.20, "dodge_caution": 1.25,
		},
		"character_old": {
			"name": "old",
			"wanted_tags": ["stat_engineering", "less_enemies", "less_enemy_speed"],
			"set_synergy": 8.0, "engage_scale": 1.05, "dodge_caution": 1.10,
		},
		"character_lucky": {
			"name": "lucky",
			"wanted_tags": ["stat_luck", "pickup", "exploration"],
			"set_synergy": 8.0, "engage_scale": 1.10, "dodge_caution": 1.10,
		},
		"character_mutant": {
			"name": "mutant",
			"wanted_tags": ["xp_gain"],
		},
		"character_generalist": {
			"name": "generalist",
			"wanted_tags": ["stat_melee_damage", "stat_ranged_damage"],
			"preferred_sets": ["set_ethereal"],
			"set_synergy": 10.0,
		},
		"character_loud": {
			"name": "loud",
			"wanted_tags": ["more_enemies"],
			"preferred_sets": ["set_ethereal"],
			"set_synergy": 10.0, "engage_scale": 1.05, "dodge_caution": 1.10,
		},
		"character_multitasker": {
			"name": "multitasker",
			"preferred_sets": ["set_primitive"],
			"set_synergy": 12.0,
		},
		"character_wildling": {
			"name": "wildling",
			"preferred_sets": ["set_primitive"],
			"set_synergy": 11.0,
		},
		"character_apprentice": {
			"name": "apprentice",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_dodge", "xp_gain"],
			"preferred_sets": ["set_gun"],
			"set_synergy": 10.0, "engage_scale": 1.35, "dodge_caution": 1.45,
		},
		"character_arms_dealer": {
			"name": "arms_dealer",
			"combine_bonus": 0.0, "set_synergy": 0.0,
			"engage_scale": 1.20, "dodge_caution": 1.20,
		},
		"character_artificer": {
			"name": "artificer",
			"wanted_tags": ["explosive", "stat_armor", "stat_max_hp"],
			"allow_melee": false,
			"preferred_sets": ["set_explosive"],
			"set_synergy": 18.0, "engage_scale": 1.35, "dodge_caution": 1.30,
			"starting_weapon": "weapon_shredder_1",
		},
		"character_baby": {
			"name": "baby",
			"wanted_tags": ["xp_gain"],
			"preferred_sets": ["set_primitive"],
			"set_synergy": 14.0, "combine_bonus": 3.0,
			"starting_weapon": "weapon_stick_1",
			"dodge_caution": 1.10,
		},
		"character_beast_master": {
			"name": "beast_master",
			"wanted_tags": ["pet", "stat_luck"],
			"no_weapons": true, "set_synergy": 0.0, "combine_bonus": 0.0,
			"tier_bonus": 6.0, "flat_damage_value": 4.0,
			"min_buy_score": 30.0, "reroll_gold_factor": 2.0,
			"flee_mode": true, "use_pure_repulsion_flee": true,
			"shop_must_tag": "pet", "pursue_enemies": false,
			"engage_scale": 1.0, "fixed_engage_distance": 300.0,
			"dodge_caution": 1.45, "ehp_value_multiplier": 1.3,
			"speed_value_multiplier": 4.0,
			"tag_bonus_overrides": {"pet": 80.0},
		},
		"character_bull": {
			"name": "bull",
			"wanted_tags": ["stat_armor", "stat_hp_regeneration", "explosive", "stat_max_hp"],
			"no_weapons": true, "set_synergy": 0.0, "combine_bonus": 0.0,
			"tier_bonus": 6.0, "flat_damage_value": 8.0,
			"min_buy_score": 3.0,
			"flee_mode": true, "use_pure_repulsion_flee": true,
			"bull_mode": true, "engage_scale": 1.0,
			"fixed_engage_distance": 85.0, "pursue_enemies": false,
			"dodge_caution": 1.0, "ehp_value_multiplier": 1.5,
			"utility_overrides": {
				"explosion_damage": 6.0, "explosion_size": 8.0,
				"effect_explode": 5.0, "explode_on_death": 3.0,
				"explode_on_consumable": 3.0,
			},
		},
		"character_renegade": {
			"name": "renegade",
			"wanted_tags": ["stat_attack_speed", "stat_crit_chance", "piercing",
				"stat_max_hp", "stat_armor", "stat_dodge"],
			"allow_melee": false,
			"preferred_sets": ["set_gun", "set_precise"],
			"set_synergy": 10.0, "starting_weapon": "weapon_crossbow_1",
			"engage_scale": 1.30, "dodge_caution": 1.25,
			"dps_gain_weight": 0.0, "ehp_value_multiplier": 1.3,
			"min_buy_score": 6.0,
			"utility_overrides": {
				"piercing": 14.0, "projectiles": 22.0,
				"stat_attack_speed": 3.0, "stat_crit_chance": 2.0,
			},
		},
		"character_saver": {
			"name": "saver",
			"wanted_tags": ["stat_attack_speed"],
			"allow_melee": false,
			"allowed_weapon_ids": ["weapon_smg"],
			"preferred_sets": ["set_gun"],
			"set_synergy": 15.0, "combine_bonus": 0.0,
			"tier_bonus": 6.0, "auto_combine": false,
			"starting_weapon": "weapon_pistol_1",
			"min_buy_score": 999.0, "reroll_gold_factor": 1.0,
			"disable_rich_mode": true,
			"engage_scale": 1.30, "dodge_caution": 1.20,
		},
		"character_sick": {
			"name": "sick",
			"wanted_tags": ["stat_lifesteal", "stat_attack_speed", "stat_max_hp",
				"stat_armor", "stat_dodge"],
			"preferred_sets": ["set_medical", "set_blade"],
			"set_synergy": 10.0, "starting_weapon": "weapon_medical_gun_1",
			"engage_scale": 1.20, "dodge_caution": 1.15,
			"utility_overrides": {"stat_lifesteal": 4.0},
		},
		"character_speedy": {
			"name": "speedy",
			"wanted_tags": ["stat_speed", "stat_dodge", "stat_lifesteal",
				"stat_max_hp", "stat_attack_speed"],
			"preferred_sets": ["set_blade", "set_precise"],
			"set_synergy": 10.0, "starting_weapon": "weapon_knife_1",
			"engage_scale": 0.95, "dodge_caution": 1.20,
			"speed_value_multiplier": 2.0, "ehp_value_multiplier": 1.3,
		},
		"character_streamer": {
			"name": "streamer",
			"wanted_tags": ["structure", "stat_percent_damage", "stat_attack_speed",
				"stat_max_hp", "stat_armor"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 10.0, "engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_technomage": {
			"name": "technomage",
			"wanted_tags": ["stat_engineering", "structure", "stat_elemental_damage",
				"stat_max_hp", "stat_armor"],
			"preferred_sets": ["set_tool", "set_elemental"],
			"set_synergy": 11.0, "starting_weapon": "weapon_wrench_1",
			"engage_scale": 1.30, "dodge_caution": 1.25,
			"ehp_value_multiplier": 1.4,
		},
		"character_vagabond": {
			"name": "vagabond",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_attack_speed",
				"stat_crit_chance"],
			"set_synergy": 0.0, "combine_bonus": 0.0, "auto_combine": false,
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_vampire": {
			"name": "vampire",
			"wanted_tags": ["stat_lifesteal", "stat_attack_speed", "stat_max_hp",
				"stat_armor", "stat_dodge"],
			"preferred_sets": ["set_medical", "set_blade"],
			"set_synergy": 10.0, "starting_weapon": "weapon_medical_gun_1",
			"engage_scale": 1.20, "dodge_caution": 1.15,
			"utility_overrides": {"stat_lifesteal": 4.0},
		},
		"character_well_rounded": {
			"name": "well_rounded",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_attack_speed",
				"stat_crit_chance"],
			"set_synergy": 8.0, "engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_wounded": {
			"name": "wounded",
			"wanted_tags": ["stat_dodge", "stat_speed", "stat_attack_speed",
				"stat_ranged_damage", "stat_crit_chance"],
			"allow_melee": false,
			"preferred_sets": ["set_gun", "set_precise"],
			"set_synergy": 12.0, "starting_weapon": "weapon_pistol_1",
			"flee_mode": true, "use_pure_repulsion_flee": true,
			"pursue_enemies": false, "engage_scale": 1.0,
			"fixed_engage_distance": 500.0, "dodge_caution": 1.80,
			"speed_value_multiplier": 2.5, "dps_gain_weight": 1.0,
			"shop_must_items": ["item_tardigrade"],
			"forbidden_stats": ["stat_max_hp", "stat_hp_regeneration",
				"stat_lifesteal", "stat_armor"],
			"banned_item_ids": ["item_chameleon"],
			"auto_combine": false,
			"utility_overrides": {
				"hit_protection": 25.0, "jellyshield_count": 12.0,
				"stat_dodge": 10.0, "dodge_cap": 7.0, "stat_speed": 3.5,
			},
		},
		"character_cryptid": {
			"name": "cryptid",
			"wanted_tags": ["exploration", "stat_dodge", "stat_armor", "stat_hp_regeneration"],
			"preferred_sets": ["set_precise"],
			"set_synergy": 10.0, "starting_weapon": "weapon_claw_1",
			"engage_scale": 1.10, "dodge_caution": 1.15,
		},
		"character_cyborg": {
			"name": "cyborg",
			"wanted_tags": ["structure", "stat_ranged_damage", "stat_armor"],
			"allow_melee": false,
			"preferred_sets": ["set_gun"],
			"set_synergy": 10.0, "engage_scale": 1.10, "dodge_caution": 1.15,
		},
		"character_demon": {
			"name": "demon",
			"wanted_tags": ["stat_max_hp"],
			"preferred_sets": ["set_ethereal"],
			"set_synergy": 11.0, "combine_bonus": 0.0,
			"min_buy_score": 8.0, "starting_weapon": "weapon_ghost_scepter_1",
			"engage_scale": 1.20, "dodge_caution": 1.30,
		},
		"character_doctor": {
			"name": "doctor",
			"wanted_tags": ["stat_hp_regeneration", "stat_armor"],
			"preferred_sets": ["set_medical"],
			"set_synergy": 11.0, "starting_weapon": "weapon_medical_gun_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_engineer": {
			"name": "engineer",
			"wanted_tags": ["stat_engineering", "structure", "stat_armor", "stat_hp_regeneration"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 11.0, "starting_weapon": "weapon_wrench_1",
			"engage_scale": 1.20, "dodge_caution": 1.20,
		},
		"character_entrepreneur": {
			"name": "entrepreneur",
			"wanted_tags": ["stat_harvesting", "economy", "stat_engineering", "structure"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 11.0, "starting_weapon": "weapon_wrench_1",
			"min_buy_score": 1.0, "engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_explorer": {
			"name": "explorer",
			"wanted_tags": ["stat_speed", "exploration", "consumable", "stat_engineering"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 10.0, "starting_weapon": "weapon_wrench_1",
			"engage_scale": 1.20, "dodge_caution": 1.20,
		},
		"character_farmer": {
			"name": "farmer",
			"wanted_tags": ["stat_harvesting", "consumable", "stat_armor"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 10.0, "starting_weapon": "weapon_pruner_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_fisherman": {
			"name": "fisherman",
			"wanted_tags": ["stat_harvesting", "stat_armor"],
			"preferred_sets": ["set_primitive"],
			"set_synergy": 12.0, "combine_bonus": 4.0,
			"starting_weapon": "weapon_stick_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_ghost": {
			"name": "ghost",
			"wanted_tags": ["stat_dodge", "stat_max_hp", "stat_hp_regeneration"],
			"preferred_sets": ["set_ethereal"],
			"set_synergy": 12.0, "starting_weapon": "weapon_ghost_axe_1",
			"engage_scale": 1.15, "dodge_caution": 1.10,
		},
		"character_gladiator": {
			"name": "gladiator",
			"wanted_tags": ["stat_melee_damage", "stat_armor", "stat_max_hp"],
			"allow_ranged": false,
			"set_synergy": 0.0, "combine_bonus": 0.0,
			"starting_weapon": "weapon_spear_1",
			"engage_scale": 1.05, "dodge_caution": 1.15,
		},
		"character_glutton": {
			"name": "glutton",
			"wanted_tags": ["explosive", "stat_melee_damage", "consumable", "stat_max_hp"],
			"preferred_sets": ["set_tool"],
			"set_synergy": 11.0, "starting_weapon": "weapon_pruner_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_golem": {
			"name": "golem",
			"wanted_tags": ["stat_max_hp", "stat_armor"],
			"starting_weapon": "weapon_spiky_shield_1",
			"set_synergy": 10.0, "engage_scale": 1.10, "dodge_caution": 1.15,
		},
		"character_hunter": {
			"name": "hunter",
			"wanted_tags": ["stat_range", "stat_crit_chance", "stat_armor"],
			"allow_melee": false,
			"preferred_sets": ["set_precise"],
			"set_synergy": 11.0, "starting_weapon": "weapon_crossbow_1",
			"engage_scale": 1.30, "dodge_caution": 1.20,
		},
		"character_jack": {
			"name": "jack",
			"wanted_tags": ["stat_crit_chance", "stat_armor", "stat_max_hp"],
			"preferred_sets": ["set_precise"],
			"set_synergy": 10.0, "starting_weapon": "weapon_knife_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_king": {
			"name": "king",
			"wanted_tags": ["stat_crit_chance", "stat_armor", "stat_max_hp"],
			"preferred_sets": ["set_precise"],
			"set_synergy": 10.0, "tier_bonus": 8.0, "combine_bonus": 20.0,
			"starting_weapon": "weapon_pistol_1",
			"engage_scale": 1.15, "dodge_caution": 1.15,
		},
		"character_knight": {
			"name": "knight",
			"wanted_tags": ["stat_armor", "stat_max_hp"],
			"allow_ranged": false,
			"preferred_sets": ["set_blade"],
			"set_synergy": 10.0, "starting_weapon": "weapon_sword_1",
			"engage_scale": 1.05, "dodge_caution": 1.15,
		},
		"character_lich": {
			"name": "lich",
			"wanted_tags": ["stat_max_hp", "stat_hp_regeneration", "stat_lifesteal"],
			"preferred_sets": ["set_blade"],
			"set_synergy": 10.0, "starting_weapon": "weapon_scissors_1",
			"engage_scale": 1.15, "dodge_caution": 1.10,
		},
		"character_masochist": {
			"name": "masochist",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_hp_regeneration", "stat_lifesteal"],
			"preferred_sets": ["set_ethereal"],
			"set_synergy": 10.0, "starting_weapon": "weapon_ghost_axe_1",
			"engage_scale": 0.95, "dodge_caution": 0.85,
		},
		"character_one_arm": {
			"name": "one_arm",
			"wanted_tags": ["explosive", "stat_percent_damage", "stat_max_hp",
				"stat_armor", "stat_hp_regeneration", "stat_dodge"],
			"allow_melee": false,
			"preferred_sets": ["set_explosive"],
			"set_synergy": 14.0, "combine_bonus": 40.0, "tier_bonus": 8.0,
			"starting_weapon": "weapon_shredder_1",
			"lock_weapons": false,
			"min_buy_score": 6.0, "reroll_gold_factor": 1.5,
			"engage_scale": 1.40, "dodge_caution": 1.30,
			"ehp_value_multiplier": 2.0,
			"utility_overrides": {
				"explosion_damage": 4.0, "explosion_size": 5.0,
				"effect_explode": 6.0, "explode_on_death": 4.0,
				"explode_on_consumable": 3.0,
			},
		},
		"character_pacifist": {
			"name": "pacifist",
			"wanted_tags": ["stat_max_hp", "stat_hp_regeneration", "stat_armor",
				"stat_dodge", "stat_harvesting", "knockback"],
			"allow_ranged": false,
			"preferred_sets": ["set_unarmed"],
			"set_synergy": 25.0,
			"allowed_weapon_ids": ["weapon_hand"],
			"dps_gain_weight": 0.0,
			"starting_weapon": "weapon_hand_1",
			"min_buy_score": 6.0, "reroll_gold_factor": 1.5,
			# Experimental: borrow Bull's pure-repulsion flee (centroid + panic +
			# perpendicular escape) WITHOUT bull_mode (so no rush-in). Sampling-
			# based flee was trembling between mirror bullets.
			"flee_mode": true,
			"use_pure_repulsion_flee": true,
			"auto_combine": false,
			"speed_value_multiplier": 2.5, "ehp_value_multiplier": 1.3,
			"pursue_enemies": false, "engage_scale": 1.0,
			"fixed_engage_distance": 300.0, "dodge_caution": 1.50,
			"utility_overrides": {"knockback": 30.0, "stat_lifesteal": 0.0},
		},
		# ── DLC characters (Abyssal Terrors + earlier expansions) ─────────
		"character_sailor": {
			"name": "sailor",
			"wanted_tags": ["stat_speed", "stat_melee_damage", "stat_attack_speed"],
			"preferred_sets": ["set_blade", "set_blunt"],
			"set_synergy": 10.0,
			"speed_value_multiplier": 2.5,
			"engage_scale": 0.7, "dodge_caution": 1.2,
		},
		"character_curious": {
			"name": "curious",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_attack_speed"],
			"set_synergy": 6.0,
		},
		"character_builder": {
			"name": "builder",
			"wanted_tags": ["stat_engineering", "structure", "stat_armor"],
			"preferred_sets": ["set_engineering"],
			"set_synergy": 10.0, "engage_scale": 1.15,
			"tag_bonus_overrides": {"structure": 12.0},
		},
		"character_buccaneer": {
			"name": "buccaneer",
			"wanted_tags": ["stat_harvesting", "gold_drops", "stat_ranged_damage"],
			"preferred_sets": ["set_gun", "set_precise"],
			"set_synergy": 8.0, "engage_scale": 1.20,
		},
		"character_captain": {
			"name": "captain",
			"wanted_tags": ["pet", "stat_max_hp", "stat_attack_speed"],
			"set_synergy": 8.0, "engage_scale": 1.10,
			"tag_bonus_overrides": {"pet": 25.0},
		},
		"character_creature": {
			"name": "creature",
			"wanted_tags": ["stat_curse", "stat_max_hp", "stat_armor"],
			"set_synergy": 7.0, "engage_scale": 1.10, "dodge_caution": 1.15,
		},
		"character_diver": {
			"name": "diver",
			"wanted_tags": ["stat_elemental_damage", "burn_damage", "stat_burning_chance"],
			"preferred_sets": ["set_elemental"],
			"set_synergy": 10.0, "engage_scale": 1.25, "dodge_caution": 1.20,
		},
		"character_druid": {
			"name": "druid",
			"wanted_tags": ["stat_engineering", "stat_harvesting", "structure"],
			"preferred_sets": ["set_engineering"],
			"set_synergy": 9.0, "engage_scale": 1.10,
		},
		"character_dwarf": {
			"name": "dwarf",
			"wanted_tags": ["stat_armor", "stat_melee_damage", "stat_max_hp"],
			"preferred_sets": ["set_blunt"],
			"set_synergy": 10.0, "engage_scale": 0.8,
			"ehp_value_multiplier": 1.5,
		},
		"character_gangster": {
			"name": "gangster",
			"wanted_tags": ["stat_attack_speed", "stat_ranged_damage", "stat_crit_chance"],
			"preferred_sets": ["set_gun"],
			"set_synergy": 10.0, "engage_scale": 1.10,
		},
		"character_hiker": {
			"name": "hiker",
			"wanted_tags": ["stat_range", "stat_ranged_damage", "stat_harvesting"],
			"preferred_sets": ["set_precise"],
			"set_synergy": 9.0, "engage_scale": 1.40, "dodge_caution": 1.15,
		},
		"character_ogre": {
			"name": "ogre",
			"wanted_tags": ["stat_max_hp", "stat_armor", "stat_melee_damage"],
			"preferred_sets": ["set_blunt"],
			"set_synergy": 10.0, "engage_scale": 0.6,
			"ehp_value_multiplier": 1.5,
		},
		"character_romantic": {
			"name": "romantic",
			"wanted_tags": ["stat_lifesteal", "stat_hp_regeneration", "stat_max_hp"],
			"set_synergy": 8.0, "engage_scale": 1.10, "dodge_caution": 1.10,
		},
		"character_chef": {
			"name": "chef",
			"wanted_tags": ["stat_max_hp", "stat_hp_regeneration", "stat_attack_speed"],
			"set_synergy": 7.0, "engage_scale": 1.20,
		},
	}
