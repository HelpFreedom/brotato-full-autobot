extends Reference
class_name BotConfig

# Constants ported from the Python prototype's config.py.
# Static dictionary -- kept as `const` so it can be read without instantiating.

# ── Potential-field forces ─────────────────────────────────────────────────────
const ENEMY_REPULSION := 600.0
const BOSS_REPULSION := 1800.0
const PROJECTILE_REPULSION := 1000.0
const LOOT_ATTRACTION := 60.0
const CONSUMABLE_ATTRACTION := 80.0
const WALL_REPULSION := 800.0
const ENEMY_INFLUENCE_RADIUS := 500.0
const PROJECTILE_INFLUENCE_RADIUS := 300.0
const WALL_MARGIN := 150.0
const SAFETY_DISTANCE := 250.0
const CIRCLING_STRENGTH := 0.6

# ── Engagement (weapon-aware kiting) ───────────────────────────────────────────
const CONTACT_DANGER := 70.0
const CONTACT_REPULSION := 4000.0
const MIN_ENGAGE_DISTANCE := 95.0
const SAFE_FALLBACK_DISTANCE := 450.0
const ENGAGE_PULL := 0.22
const ENGAGE_PULL_THRESHOLD := 1.5
const ENGAGE_SPRING_K := 0.012
const ENGAGE_HP_HIGH := 0.75
const ENGAGE_HP_LOW := 0.25
const DEFAULT_ENGAGE_DISTANCE := 400.0

# ── Sampling-based flee (Pacifist) ─────────────────────────────────────────────
const FLEE_HORIZON := 1.0
const FLEE_TIME_SAMPLES := 6
const FLEE_DIRECTIONS := 36
const FLEE_CROWD_RADIUS := 160.0
const FLEE_CROWD_K := 2.0
const FLEE_WALL_MARGIN := 220.0
const FLEE_WALL_PENALTY := 600.0
const FLEE_CENTER_BIAS := 80.0
const FLEE_STUCK_DIST := 300.0
const FLEE_STUCK_CENTER_MULT := 6.0
const FLEE_MOVE_SMOOTHING := 0.85
const FLEE_ENEMY_SPEED_SAFETY := 1.5
const FLEE_BULLET_DANGER := 70.0
const FLEE_BULLET_K := 10.0
const FLEE_BODY_DANGER := 110.0
const FLEE_BODY_K := 0.25
const FLEE_HYSTERESIS_BONUS := 25.0
const FLEE_REVERSE_PENALTY := 0.0
const FLEE_MAX_TURN_RAD := 3.14
const FLEE_AWAY_PENALTY := 800.0
const FLEE_REPEL_RANGE := 360.0
const FLEE_REPEL_K := 0.018

# ── Orbital flee (Beast Master) ────────────────────────────────────────────────
const ORBIT_RADIUS_FRACTION := 0.28
const ORBIT_INNER_FRACTION := 0.6
const ORBIT_RADIAL_MIX_BASE := 0.15
const ORBIT_RADIAL_MIX_GAIN := 0.85
const ORBIT_RADIAL_MIX_MAX := 0.85
const ORBIT_VEER_DIST := 200.0
const ORBIT_VEER_HORIZON := 1.0
const ORBIT_VEER_STEPS := 6
const ORBIT_VEER_STRENGTH := 0.65
const ORBIT_MIN_TANGENT := 0.3
const ORBIT_TANGENT_BLOCK_RADIAL_NUDGE := 1.0
const ORBIT_CRITICAL_DIST := 120.0
const ORBIT_CRITICAL_RADIAL := 4.0

# ── Pure-repulsion flee (Bull, Wounded) ────────────────────────────────────────
const REPULSION_CENTROID_REACH := 350.0
const REPULSION_CENTROID_K := 10.0
const REPULSION_BULLET_REACH := 250.0
const REPULSION_BULLET_K := 60.0
const REPULSION_CENTER_K := 3.0
const REPULSION_CENTER_INNER := 250.0
const REPULSION_CENTER_SPAN := 500.0
const REPULSION_WALL_MARGIN := 320.0
const REPULSION_WALL_K := 80.0
const PURE_REPULSION_SMOOTHING := 0.15
const PANIC_BODY_REACH := 120.0
const PANIC_BULLET_REACH := 140.0
const PURE_REPULSION_PANIC_SMOOTHING := 0.7
const PANIC_WALL_K := 80.0
const PANIC_MIN_MAGNITUDE := 5.0

# ── Bull-specific ──────────────────────────────────────────────────────────────
const BULL_ATTACK_HP_RATIO := 0.6
const BULL_CLUSTER_MIN := 4
const BULL_CLUSTER_RADIUS := 250.0

# ── Movement smoothing & misc ──────────────────────────────────────────────────
const BOSS_WEIGHT := 2.5
const MOVE_SMOOTHING := 0.30

# ── Stop-and-shoot (Soldier) ───────────────────────────────────────────────────
const STAND_DANGER_DIST := 150.0
const STAND_BULLET_CLEAR := 95.0

# ── Predictive dodging / escape sampling ───────────────────────────────────────
const ENEMY_LOOKAHEAD := 0.25
const PROJ_MAX_HORIZON := 0.9
const PROJ_THREAT_RADIUS := 110.0
const ESCAPE_DIRECTIONS := 24
const ESCAPE_HORIZON := 0.55
const ESCAPE_TIME_SAMPLES := 6
const ESCAPE_SAFE_CLEARANCE := 130.0
const ESCAPE_PANIC_CLEARANCE := 45.0
const ESCAPE_WALL_MARGIN := 90.0
const ESCAPE_WALL_PENALTY := 250.0
const ESCAPE_ALIGN_BONUS := 18.0
const ENEMY_AVOID_DIST := 95.0
const ENEMY_AVOID_PENALTY := 3.0

# ── Combat model (DPS / EHP valuation) ─────────────────────────────────────────
const DPS_PRIORITY := 1.0
const DEF_PRIORITY := 0.55
const SPEED_VALUE := 0.6
const ENEMY_HIT_BASE := 8.0
const ENEMY_HIT_PER_WAVE := 2.5
const MIN_DAMAGE_TAKEN_FRAC := 0.25
const REGEN_WINDOW := 6.0
const DODGE_CAP_DEFAULT := 70.0
const EHP_REF := 50.0

# ── Shop strategy ──────────────────────────────────────────────────────────────
const SHOP_MIN_SCORE := 4.0
const SHOP_GOLD_RESERVE := 0
const SHOP_REROLL_GOLD_FACTOR := 4.0
const CRATE_MIN_SCORE := 0.0
const SHOP_ACTION_INTERVAL := 0.25
const SHOP_PREMIUM_SCORE := 13.0
const SHOP_PREMIUM_REACH := 2.2
const SHOP_REROLL_WORTH := 6.0
const SHOP_RICH_GOLD_BASE := 100
const SHOP_RICH_GOLD_PER_WAVE := 130
const SHOP_RICH_GOLD_MAX := 1000
const SHOP_REROLL_RICH_WORTH := 20.0
const SHOP_MAX_REROLLS := 8
const SHOP_REROLL_GOLD_STEP := 120
const SHOP_MAX_REROLLS_CAP := 60
const SHOP_RICH_MIN_BUY := 1.0
const SHOP_SELL_MARGIN := 10.0
const COMBINE_MIN_WEAPONS := 4
const OFF_BUILD_PENALTY := 16.0
const HEALING_WEAPON_PENALTY := 12.0
const UNKNOWN_EFFECT_WEIGHT := 0.3

# ── Tier floors / tag weights ──────────────────────────────────────────────────
const ITEM_TIER_FLOOR := [3.0, 4.0, 8.0, 14.0, 18.0, 24.0, 30.0]
const TAG_STAT_VALUE := 2.0
const TAG_WANTED_BONUS := 3.0
const HARVESTING_DEADLINE_WAVE := 20.0

# ── Level-up reroll ────────────────────────────────────────────────────────────
const LEVELUP_REROLL_WORTH := 5.0
const LEVELUP_REROLL_GOLD_FACTOR := 6.0
const LEVELUP_REROLL_CAP := 2

# ── Per-stat utility weights ───────────────────────────────────────────────────
# Combat stats (HP/armor/dodge/AS/crit/damage) go through the DPS/EHP model in
# combat_model.gd, not this table. Anything else (range, harvesting, structures,
# downsides) is valued here. An item effect's sign decides good/bad.
static func utility_weights() -> Dictionary:
	return {
		"stat_lifesteal": 1.0, "stat_range": 0.1, "stat_harvesting": 0.2,
		"stat_engineering": 0.4, "stat_luck": 0.3, "stat_accuracy": 0.2,
		"piercing": 5.0, "piercing_damage": 0.3, "bounce": 1.5,
		"damage_against_bosses": 0.25, "giant_crit_damage": 0.2,
		"explosion_damage": 0.2, "explosion_size": 1.2, "effect_explode": 2.0,
		"explode_on_death": 1.0, "explode_on_consumable": 0.5,
		"projectiles_on_death": 1.0,
		"effect_burning": 2.0, "burn_chance": 0.4, "burning_spread": 0.5,
		"burning_cooldown_reduction": 0.3,
		"hit_protection": 3.0, "jellyshield_count": 2.0, "consumable_heal": 0.4,
		"hp_regen_bonus": 0.8, "heal_on_crit_kill": 0.5,
		"heal_when_pickup_gold": 0.3, "hp_start_next_wave": 0.2,
		"hp_start_wave": 0.2, "hp_cap": 0.2,
		"xp_gain": 0.15, "free_rerolls": 2.0, "items_price": 0.5,
		"recycling_gains": 0.2, "gold_drops": 0.3, "chance_double_gold": 0.2,
		"gold_on_crit_kill": 0.2, "gain_pct_gold_start_wave": 0.2,
		"instant_gold_attracting": 0.05, "pickup_range": 0.1,
		"harvesting_growth": 0.3, "knockback": 0.0,
		"gain_random_primary_stats_on_go_to_next_wave": 3.0, "wandering_bot": 3.0,
		"tree_turrets": 2.0, "trees": 1.5, "one_shot_trees": 1.0,
		"alien_eyes": 1.0, "item_hourglass": 1.0, "item_box_gold": 1.0,
		"lose_hp_per_second": 3.0, "enemy_damage": 0.6, "enemy_health": 0.5,
		"enemy_speed": 0.4, "enemy_fruit_drops": 0.2, "number_of_enemies": 0.5,
		"extra_enemies_next_wave": 0.8, "extra_elite_next_wave_chance": 0.6,
		"extra_loot_aliens_next_wave": 0.2, "fog_visibility": 0.3,
		"remove_speed": 0.5, "speed_cap": 0.3, "dodge_cap": 0.3,
	}
