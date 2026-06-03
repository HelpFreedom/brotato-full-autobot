extends Reference
class_name BotShopStrategy

# Shop / level-up / crate decision engine — port of shop_strategy.py.
# Returns one action Dictionary or {} (caller throttles).

# Preload sibling scripts so we can refer to them without relying on the
# class_name registry being ready at parse time (mod zips parse before
# ModLoader injects class_name entries).
const BotConfig := preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/config.gd")
const BotCombatModel := preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/combat_model.gd")

# Tier→bonus (matches _TIER_BONUS in Python).
const _TIER_BONUS := [0.0, 1.0, 2.5, 5.0, 7.0, 10.0, 14.0]
const _SIGN_POSITIVE := 0
const _SIGN_NEGATIVE := 1
const _SIGN_NEUTRAL := 2
const _SIGN_FROM_VALUE := 3
const _COMBAT_STATS := [
	"stat_percent_damage", "stat_ranged_damage", "stat_melee_damage",
	"stat_elemental_damage", "stat_damage", "stat_attack_speed",
	"stat_crit_chance", "stat_crit_damage", "stat_max_hp", "stat_armor",
	"stat_dodge", "stat_hp_regeneration", "stat_speed",
]
const _DMG_TYPES := ["stat_ranged_damage", "stat_melee_damage", "stat_elemental_damage"]
const _FREEZE_KEYS := ["hp_cap", "speed_cap", "dodge_cap"]

# Per-shop-visit state. Resets each wave.
var _session_wave: int = -1
var _session_rerolls: int = 0
var _session_sold_families := {}


# ────────────────────────────── value helpers ─────────────────────────────────

func _tier_bonus(profile, tier: int) -> float:
	var base: float = _TIER_BONUS[tier] if tier >= 0 and tier < _TIER_BONUS.size() else 0.0
	return base * (profile.tier_bonus / 4.0)


func _effect_signed_value(e: Dictionary) -> float:
	var val = e.get("value", 0)
	if val == null: val = 0
	var eff_sign = e.get("sign", _SIGN_FROM_VALUE)
	if eff_sign == _SIGN_POSITIVE: return abs(float(val))
	if eff_sign == _SIGN_NEGATIVE: return -abs(float(val))
	if eff_sign == _SIGN_NEUTRAL: return 0.0
	return float(val)


func _combat_deltas(effects: Array) -> Dictionary:
	var d := {}
	for e in effects:
		var key = e.get("key", "")
		if _COMBAT_STATS.has(key):
			d[key] = d.get(key, 0.0) + _effect_signed_value(e)
	return d


func _utility_score(effects: Array, wave: int, profile) -> float:
	var overrides: Dictionary = profile.utility_overrides if profile else {}
	var weights := BotConfig.utility_weights()
	var score := 0.0
	for e in effects:
		var key = e.get("key", "")
		if _COMBAT_STATS.has(key) and not overrides.has(key):
			continue
		var w: float
		if overrides.has(key):
			w = overrides[key]
		elif weights.has(key):
			w = weights[key]
		else:
			w = BotConfig.UNKNOWN_EFFECT_WEIGHT
		if key == "stat_harvesting":
			w *= max(0.0, (BotConfig.HARVESTING_DEADLINE_WAVE - wave) / BotConfig.HARVESTING_DEADLINE_WAVE)
		score += w * _effect_signed_value(e)
	return score


func _effects_value(effects: Array, build: Dictionary, wave: int, profile) -> float:
	if effects.empty():
		return 0.0
	var combat := BotCombatModel.combat_value(build, _combat_deltas(effects), wave, profile)
	return combat + _utility_score(effects, wave, profile)


func _tag_score(tags: Array, profile) -> float:
	var overrides: Dictionary = profile.tag_bonus_overrides if profile else {}
	var weights := BotConfig.utility_weights()
	var score := 0.0
	for t in tags:
		if profile.wanted_tags.has(t):
			score += BotConfig.TAG_WANTED_BONUS
		if weights.has(t):
			score += weights[t] * BotConfig.TAG_STAT_VALUE
		if overrides.has(t):
			score += overrides[t]
	return score


# ─────────────────────────── weapon valuation ─────────────────────────────────

func _live_damage_types(build: Dictionary) -> Array:
	var totals := {}
	for w in build.get("weapons", []):
		for s in w.get("scaling", []):
			if typeof(s) == TYPE_ARRAY and s.size() >= 2 and _DMG_TYPES.has(s[0]):
				totals[s[0]] = totals.get(s[0], 0.0) + s[1]
	if not totals.empty():
		var peak: float = 0.0
		for v in totals.values():
			if v > peak:
				peak = v
		var out := []
		for k in totals:
			if totals[k] >= 0.25 * peak:
				out.append(k)
		return out
	var gm: Dictionary = build.get("gain_mods", {})
	var live := []
	for k in _DMG_TYPES:
		if gm.get(k, 0) > 0:
			live.append(k)
	return live if not live.empty() else _DMG_TYPES.duplicate()


func _is_off_build(w: Dictionary, build: Dictionary) -> bool:
	var scaling_types := []
	for s in w.get("scaling", []):
		if typeof(s) == TYPE_ARRAY and s.size() >= 2 and _DMG_TYPES.has(s[0]):
			if not scaling_types.has(s[0]): scaling_types.append(s[0])
	if scaling_types.empty(): return false
	var live = _live_damage_types(build)
	for st in scaling_types:
		if live.has(st):
			return false
	return true


func _set_synergy(sets: Array, owned_weapons: Array, profile) -> float:
	var owned_sets := []
	for w in owned_weapons:
		for s in w.get("sets", []):
			owned_sets.append(s)
	var seen := {}
	var val := 0.0
	for s in sets:
		if seen.has(s): continue
		seen[s] = true
		if profile.preferred_sets.has(s): val += profile.set_synergy * 0.5
		var cnt := 0
		for o in owned_sets:
			if o == s:
				cnt += 1
		val += profile.set_synergy * 0.35 * cnt
	return val


func _weapon_value(item: Dictionary, build: Dictionary, profile, owned_for_synergy: Array) -> float:
	var wtype: String = item.get("type", item.get("weapon_type", "ranged"))
	if wtype == "melee" and not profile.allow_melee: return -1e9
	if wtype == "ranged" and not profile.allow_ranged: return -1e9
	if profile.no_weapons: return -1e9
	if profile.allowed_weapon_sets != null:
		var hit := false
		for s in item.get("sets", []):
			if profile.allowed_weapon_sets.has(s):
				hit = true
				break
		if not hit: return -1e9
	if profile.allowed_weapon_ids != null:
		if not profile.allowed_weapon_ids.has(item.get("weapon_id")): return -1e9

	var stats: Dictionary = build.get("stats", {})
	var weapons: Array = build.get("weapons", [])
	var total: float = BotCombatModel.total_dps(weapons, stats)
	var dps: float = BotCombatModel.weapon_dps(item, stats)
	var score: float = (BotConfig.DPS_PRIORITY * 100.0 * dps / total) if total > 0 else (BotConfig.DPS_PRIORITY * 25.0)

	if _is_off_build(item, build): score -= BotConfig.OFF_BUILD_PENALTY
	if item.get("is_healing", false): score -= BotConfig.HEALING_WEAPON_PENALTY
	score += _tier_bonus(profile, item.get("tier", 0))
	score += _set_synergy(item.get("sets", []), owned_for_synergy, profile)
	if wtype == "melee": score -= 3.0
	return score


func _weapon_score(item: Dictionary, build: Dictionary, profile) -> float:
	var weapons: Array = build.get("weapons", [])
	var slots: int = build.get("weapon_slots", 6)
	var slots_full: bool = weapons.size() >= slots
	var same_id_owned := false
	for w in weapons:
		if w.get("id") == item.get("id"):
			same_id_owned = true
			break
	if same_id_owned and slots_full and not profile.auto_combine:
		return -1e9
	var score = _weapon_value(item, build, profile, weapons)
	if item.get("upgrades", false) and same_id_owned:
		score += profile.combine_bonus
	return score


func _owned_weapon_value(w: Dictionary, build: Dictionary, profile) -> float:
	var others := []
	for x in build.get("weapons", []):
		if x != w: others.append(x)
	return _weapon_value(w, build, profile, others)


# ─────────────────────────── item-level helpers ───────────────────────────────

func _item_tier_floor(tier: int) -> float:
	var floors = BotConfig.ITEM_TIER_FLOOR
	return floors[tier] if tier >= 0 and tier < floors.size() else 0.0


func _freezes_stat(item: Dictionary) -> bool:
	for e in item.get("effects", []):
		if _FREEZE_KEYS.has(e.get("key", "")):
			var v = e.get("value", 0)
			if v == null: v = 0
			if v <= 0: return true
	return false


func _locks_weapons(item: Dictionary) -> bool:
	if item.get("locks_weapons", false): return true
	for e in item.get("effects", []):
		if e.get("key") == "lock_current_weapons": return true
	return false


func _blocks_healing(item: Dictionary) -> bool:
	if item.get("blocks_healing", false): return true
	for e in item.get("effects", []):
		var k = e.get("key", "")
		if k == "no_heal" or k == "dmg_when_heal": return true
	return false


func _disables_all_healing(item: Dictionary) -> bool:
	for e in item.get("effects", []):
		if e.get("key", "") == "torture":
			var v = e.get("value", 0)
			if v == null: v = 0
			if v > 0: return true
	return false


func _building_healing(build: Dictionary) -> bool:
	var st: Dictionary = build.get("stats", {})
	if (st.get("stat_hp_regeneration", 0) or 0) >= 3: return true
	if (st.get("stat_lifesteal", 0) or 0) >= 3: return true
	for w in build.get("weapons", []):
		if w.get("is_healing", false): return true
	return false


func _arsenal_maxed(build: Dictionary) -> bool:
	var weapons: Array = build.get("weapons", [])
	if weapons.size() < build.get("weapon_slots", 6): return false
	for w in weapons:
		if w.get("upgrades", false):
			return false
	return true


func _is_vetoed(item: Dictionary, build: Dictionary) -> bool:
	if _freezes_stat(item): return true
	if _disables_all_healing(item): return true
	if _locks_weapons(item) and not _arsenal_maxed(build): return true
	if _blocks_healing(item) and _building_healing(build): return true
	return false


func item_score(item: Dictionary, build: Dictionary, profile, wave: int) -> float:
	if item.get("category") == "weapon":
		return _weapon_score(item, build, profile)
	if _is_vetoed(item, build): return -1e9
	if not profile.banned_item_ids.empty() and profile.banned_item_ids.has(item.get("id")):
		return -1e9
	var effects: Array = item.get("effects", [])
	if not profile.forbidden_stats.empty():
		var filtered := []
		for e in effects:
			if not profile.forbidden_stats.has(e.get("key", "")):
				filtered.append(e)
		effects = filtered
	var score := (_effects_value(effects, build, wave, profile)
		+ _tag_score(item.get("tags", []), profile)
		+ _tier_bonus(profile, item.get("tier", 0)))
	if effects.empty():
		return max(score, _item_tier_floor(item.get("tier", 0)))
	return score


func _combinable_index(weapons: Array) -> int:
	var by_id := {}
	for w in weapons:
		if not w.get("upgrades", false): continue
		var id = w.get("id")
		if not by_id.has(id): by_id[id] = []
		by_id[id].append(w)
	for wid in by_id:
		var group: Array = by_id[wid]
		if group.size() >= 2: return group[0].get("index", -1)
	return -1


# ─────────────────────────── session reset ────────────────────────────────────

func _reset_session_if_new(state: Dictionary) -> void:
	var w: int = state.get("wave", 0)
	if _session_wave != w:
		_session_wave = w
		_session_rerolls = 0
		_session_sold_families = {}


# ─────────────────────────── decide_shop ──────────────────────────────────────

func decide_shop(state: Dictionary, profile) -> Dictionary:
	_reset_session_if_new(state)
	var gold: int = state.get("gold", 0)
	var wave: int = state.get("wave", 1)
	var reroll_price: int = state.get("reroll_price", 0)
	var build: Dictionary = state.get("build", {})
	var items: Array = state.get("shop_items", [])
	var weapons: Array = build.get("weapons", [])
	var slots: int = build.get("weapon_slots", 6)
	var can_sell: bool = build.get("can_sell", true)
	var slots_full: bool = weapons.size() >= slots

	var rich_threshold: int = min(BotConfig.SHOP_RICH_GOLD_BASE + BotConfig.SHOP_RICH_GOLD_PER_WAVE * wave,
		BotConfig.SHOP_RICH_GOLD_MAX)
	var rich: bool = gold >= rich_threshold and not profile.disable_rich_mode
	var min_buy: float = BotConfig.SHOP_RICH_MIN_BUY if rich else profile.min_buy_score
	var reroll_cap: int = BotConfig.SHOP_MAX_REROLLS
	if rich:
		reroll_cap = min(BotConfig.SHOP_MAX_REROLLS_CAP,
			BotConfig.SHOP_MAX_REROLLS + int(gold / BotConfig.SHOP_REROLL_GOLD_STEP))

	# 0a) allowed_weapon_ids: needs more weapons of specific family → reroll hard
	var allowed_ids = profile.allowed_weapon_ids
	if allowed_ids != null and weapons.size() < slots:
		var has_allowed := false
		for it in items:
			if (it.get("category") == "weapon"
				and allowed_ids.has(it.get("weapon_id"))
				and it.get("affordable")
				and it.get("can_buy", true)
				and it.get("usable", true)):
				has_allowed = true; break
		if not has_allowed:
			var free0: bool = reroll_price <= 0
			var budget0: bool = free0 or gold >= reroll_price * profile.reroll_gold_factor + profile.gold_reserve
			if _session_rerolls < BotConfig.SHOP_MAX_REROLLS_CAP and budget0:
				_session_rerolls += 1
				return {"type": "shop_reroll"}

	# 0b) shop_must_items: target items (Wounded → tardigrade)
	var must_items: Array = profile.shop_must_items
	if not must_items.empty():
		# 0b.1: buy any visible+affordable target
		for it in items:
			if must_items.has(it.get("id")) and it.get("affordable") and it.get("can_buy", true):
				return {"type": "shop_buy", "slot": it["slot"]}
		# 0b.2: lock visible unaffordable target
		for it in items:
			if must_items.has(it.get("id")) and not it.get("affordable") and not it.get("locked", false):
				return {"type": "shop_lock", "slot": it["slot"]}
		# 0b.3: unlock non-target items
		for it in items:
			if it.get("locked", false) and not must_items.has(it.get("id")):
				return {"type": "shop_unlock", "slot": it["slot"]}
		# 0b.4: fill empty weapon slots first
		if weapons.size() < slots:
			for it in items:
				if (it.get("category") == "weapon"
					and it.get("affordable")
					and it.get("can_buy", true)
					and it.get("usable", true)
					and not _session_sold_families.has(it.get("weapon_id"))):
					var s = _weapon_score(it, build, profile)
					if s > 0: return {"type": "shop_buy", "slot": it["slot"]}
		# 0b.5: reroll exhaustively
		var has_aff_tgt := false
		for it in items:
			if must_items.has(it.get("id")) and it.get("affordable"):
				has_aff_tgt = true; break
		if not has_aff_tgt:
			var free_mi: bool = reroll_price <= 0
			var min_keep := 20
			var budget_mi: bool = free_mi or gold >= reroll_price * 2.0 + min_keep
			if _session_rerolls < BotConfig.SHOP_MAX_REROLLS_CAP and budget_mi:
				_session_rerolls += 1
				return {"type": "shop_reroll"}

	# 0) shop_must_tag (Beast Master)
	var must_tag: String = profile.shop_must_tag
	if must_tag != "":
		for it in items:
			var tags: Array = it.get("tags", []) if it.get("tags") != null else []
			if tags.has(must_tag) and it.get("affordable") and it.get("can_buy", true):
				return {"type": "shop_buy", "slot": it["slot"]}
		var free_e: bool = reroll_price <= 0
		var budget_e: bool = free_e or gold >= reroll_price * profile.reroll_gold_factor + profile.gold_reserve
		if _session_rerolls < BotConfig.SHOP_MAX_REROLLS_CAP and budget_e:
			_session_rerolls += 1
			return {"type": "shop_reroll"}
		return {"type": "shop_go"}

	# 1) Best purchase
	var best_score: float = min_buy
	var best_action := []
	for it in items:
		var is_weapon: bool = it.get("category") == "weapon"
		if is_weapon:
			if not it.get("usable", true): continue
			if _session_sold_families.has(it.get("weapon_id")): continue
		elif not it.get("can_buy", true):
			continue
		if not it.get("affordable"): continue
		var s := item_score(it, build, profile, wave)
		if s <= best_score: continue
		if not is_weapon:
			best_score = s; best_action = ["shop_buy", "slot", it["slot"]]; continue
		if it.get("can_buy", true):
			best_score = s; best_action = ["shop_buy", "slot", it["slot"]]
		elif slots_full:
			var combine_idx = _combinable_index(weapons)
			if combine_idx >= 0:
				best_score = s; best_action = ["shop_combine", "index", combine_idx]
			elif can_sell and not weapons.empty():
				var weakest = weapons[0]
				var weakest_val = _owned_weapon_value(weakest, build, profile)
				for w in weapons:
					var v = _owned_weapon_value(w, build, profile)
					if v < weakest_val:
						weakest = w
						weakest_val = v
				var eff_gold: int = gold + int(weakest.get("sell_value", 0))
				if eff_gold >= it.get("price", 0) and s > weakest_val + BotConfig.SHOP_SELL_MARGIN:
					best_score = s; best_action = ["shop_sell", "index", weakest.get("index", -1)]
	if not best_action.empty():
		var atype: String = best_action[0]
		var key: String = best_action[1]
		var ref = best_action[2]
		if atype == "shop_sell":
			for w in weapons:
				if w.get("index", -2) == ref:
					var fam = w.get("weapon_id")
					if fam != null: _session_sold_families[fam] = true
					break
		return {"type": atype, key: ref}

	# 2) Proactive combine
	if profile.auto_combine and (weapons.size() >= BotConfig.COMBINE_MIN_WEAPONS or slots_full):
		var ci = _combinable_index(weapons)
		if ci >= 0: return {"type": "shop_combine", "index": ci}

	# 2.5) Fill empty weapon slot
	if weapons.size() < slots:
		var best_w = null
		var best_w_score: float = 0.0
		for it in items:
			if it.get("category") != "weapon" or not it.get("usable", true): continue
			if not it.get("affordable") or not it.get("can_buy", true): continue
			if _session_sold_families.has(it.get("weapon_id")) or _is_off_build(it, build): continue
			var s := item_score(it, build, profile, wave)
			if s > best_w_score:
				best_w_score = s
				best_w = it
		if best_w != null:
			return {"type": "shop_buy", "slot": best_w["slot"]}

	# 3) Lock unaffordable premium
	var must_s3: Array = profile.shop_must_items
	for it in items:
		if it.get("affordable") or it.get("locked", false): continue
		if not must_s3.empty() and not must_s3.has(it.get("id")): continue
		if it.get("category") == "weapon" and not profile.lock_weapons: continue
		if (item_score(it, build, profile, wave) >= BotConfig.SHOP_PREMIUM_SCORE
			and it.get("price", 0) <= gold * BotConfig.SHOP_PREMIUM_REACH + 50):
			return {"type": "shop_lock", "slot": it["slot"]}

	# 4) Reroll when justified
	var free_reroll: bool = reroll_price <= 0
	var cap: int = BotConfig.SHOP_MAX_REROLLS_CAP if free_reroll else reroll_cap
	var budget_ok: bool = free_reroll or gold >= reroll_price * profile.reroll_gold_factor + profile.gold_reserve

	if _session_rerolls < cap and budget_ok:
		var best_here: float = -1.0
		for it in items:
			if it.get("affordable") and it.get("can_buy", true):
				var v := item_score(it, build, profile, wave)
				if v > best_here: best_here = v
		var worth: float = BotConfig.SHOP_REROLL_RICH_WORTH if (rich or free_reroll) else BotConfig.SHOP_REROLL_WORTH
		if best_here < worth or weapons.size() < slots:
			_session_rerolls += 1
			return {"type": "shop_reroll"}

	return {"type": "shop_go"}


# ─────────────────────────── decide_levelup ───────────────────────────────────

func decide_levelup(state: Dictionary, profile, build_override: Dictionary = {}) -> Dictionary:
	var options: Array = state.get("options", [])
	if options.empty():
		return {}
	var build: Dictionary = state.get("build", build_override)
	var wave: int = state.get("wave", 1)
	var forbidden: Array = profile.forbidden_stats
	var best = null
	var best_score: float = -1e30
	for opt in options:
		var effects: Array = opt.get("effects", [])
		var s: float
		var blocked := false
		if not forbidden.empty():
			for e in effects:
				if forbidden.has(e.get("key", "")):
					blocked = true; break
		if blocked:
			s = -1e9
		else:
			s = _effects_value(effects, build, wave, profile)
		if s > best_score:
			best_score = s; best = opt

	var reroll_price: int = state.get("reroll_price", 0)
	if (best_score < BotConfig.LEVELUP_REROLL_WORTH and options.size() > 1
		and reroll_price > 0
		and state.get("gold", 0) >= reroll_price * BotConfig.LEVELUP_REROLL_GOLD_FACTOR
		and state.get("reroll_count", 0) < BotConfig.LEVELUP_REROLL_CAP):
		return {"type": "levelup_reroll"}

	if best == null: return {}
	return {"type": "levelup_choose", "index": best["index"]}


# ─────────────────────────── decide_crate ─────────────────────────────────────

func decide_crate(state: Dictionary, profile, build_override: Dictionary = {}) -> Dictionary:
	var item: Dictionary = state.get("item", {})
	if item.empty(): return {"type": "crate_take"}
	if item.get("category") == "weapon":
		var wtype: String = item.get("weapon_type", "ranged")
		if wtype == "melee" and not profile.allow_melee:
			return {"type": "crate_discard"}
		return {"type": "crate_take"}
	var build: Dictionary = state.get("build", build_override)
	var wave: int = state.get("wave", 1)
	if _is_vetoed(item, build): return {"type": "crate_discard"}
	var score = _effects_value(item.get("effects", []), build, wave, profile) + _tag_score(item.get("tags", []), profile)
	return {"type": "crate_take"} if score >= BotConfig.CRATE_MIN_SCORE else {"type": "crate_discard"}
