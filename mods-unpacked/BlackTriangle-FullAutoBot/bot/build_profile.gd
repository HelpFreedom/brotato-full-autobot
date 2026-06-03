extends Reference
class_name BotBuildProfile

# One character's strategy identity. All fields default to a neutral baseline;
# named profiles override what the character cares about.

var name: String = "default"
var wanted_tags: Array = []                # +TAG_WANTED_BONUS on these tags
var allow_melee: bool = true
var allow_ranged: bool = true
var preferred_sets: Array = []             # e.g. ["set_gun", "set_precise"]
var set_synergy: float = 8.0
var combine_bonus: float = 14.0
var tier_bonus: float = 4.0
var min_buy_score: float = 4.0
var gold_reserve: int = 0
var reroll_gold_factor: float = 4.0
var engage_scale: float = 1.0              # >1 = kite at longer range
var dodge_caution: float = 1.0             # >1 = dodge earlier
var starting_weapon: String = ""
var lock_weapons: bool = true
var allowed_weapon_sets = null             # null = no filter; Array filters
var dps_gain_weight: float = 1.0
var flat_damage_value: float = 0.0
var no_weapons: bool = false
var pursue_enemies: bool = true
var fixed_engage_distance = null           # float, or null
var allowed_weapon_ids = null              # Array of weapon family ids, or null
var utility_overrides: Dictionary = {}
var flee_mode: bool = false
var auto_combine: bool = true
var speed_value_multiplier: float = 1.0
var ehp_value_multiplier: float = 1.0
var use_orbital_flee: bool = false
var use_pure_repulsion_flee: bool = false
var tag_bonus_overrides: Dictionary = {}
var shop_must_tag: String = ""
var shop_must_items: Array = []
var forbidden_stats: Array = []
var banned_item_ids: Array = []
var bull_mode: bool = false
var disable_rich_mode: bool = false
var body_pen_multiplier: float = 1.0


# Builder helper: fill the profile from a Dictionary literal in the registry,
# only setting keys that exist (so adding a new field doesn't break old entries).
func init_from_dict(d: Dictionary) -> BotBuildProfile:
	for k in d:
		set(k, d[k])
	return self
