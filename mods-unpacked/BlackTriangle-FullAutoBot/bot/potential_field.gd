extends Reference
class_name BotPotentialField

const BotConfig = preload("res://mods-unpacked/BlackTriangle-FullAutoBot/bot/config.gd")

# Full-fidelity port of potential_field.py. Routes by profile:
#   * default kiter  -> _build_desire + _projectile_escape
#   * flee_mode + use_pure_repulsion_flee -> _pure_repulsion_flee (+ panic, +bull)
#   * flee_mode + use_orbital_flee        -> _orbital_flee (Beast Master)
#   * flee_mode + (neither)                -> _flee_direction (Pacifist sampling, hysteresis)
# Soldier-style stop-and-shoot supported via state.can_attack_while_moving.

var _prev_move = Vector2.ZERO


func compute_movement(state, profile) -> Vector2:
	var player = state.get("player", {})
	if player.empty():
		return Vector2.ZERO
	var pos = Vector2(player.get("x", 0.0), player.get("y", 0.0))

	var enemies = state.get("enemies", [])
	var bosses = state.get("bosses", [])
	var projectiles = state.get("projectiles", [])
	var loot = state.get("loot", [])
	var consumables = state.get("consumables", [])
	var weapons = state.get("weapons", [])
	var arena = state.get("arena", {"width": 2048.0, "height": 1536.0})
	var player_speed = float(player.get("speed", 350.0))
	var can_attack_moving = state.get("can_attack_while_moving", true)

	# FLEE-mode branches (Pacifist/Beast Master/Bull/Wounded etc).
	if profile.flee_mode:
		var desire_flee: Vector2
		var alpha_flee: float
		if profile.use_pure_repulsion_flee:
			# Pure repulsion + (optional) panic + (optional) bull cluster rush.
			var panic_dir = _panic_dodge(pos, enemies, bosses, projectiles, arena)
			if panic_dir != Vector2.ZERO:
				desire_flee = panic_dir
				alpha_flee = BotConfig.PURE_REPULSION_PANIC_SMOOTHING
			else:
				if profile.bull_mode:
					var hp_ratio = float(player.get("hp", 1)) / max(float(player.get("max_hp", 1)), 1.0)
					if hp_ratio >= BotConfig.BULL_ATTACK_HP_RATIO:
						var rush = _bull_attack_dir(pos, enemies, bosses, arena)
						if rush != Vector2.ZERO:
							desire_flee = rush
							alpha_flee = BotConfig.PURE_REPULSION_SMOOTHING
							var smoothed_bull = _prev_move * (1.0 - alpha_flee) + desire_flee * alpha_flee
							_prev_move = _normalize(smoothed_bull)
							return _prev_move
				desire_flee = _pure_repulsion_flee(pos, enemies, bosses, projectiles, arena, _prev_move)
				alpha_flee = BotConfig.PURE_REPULSION_SMOOTHING
		elif profile.use_orbital_flee:
			desire_flee = _orbital_flee(pos, enemies, bosses, projectiles, arena, _prev_move, player_speed)
			alpha_flee = BotConfig.FLEE_MOVE_SMOOTHING
		else:
			# Pacifist sampling-based flee with hysteresis.
			desire_flee = _flee_direction(pos, enemies, bosses, arena, player_speed, projectiles, _prev_move, profile)
			alpha_flee = BotConfig.FLEE_MOVE_SMOOTHING
		var smoothed_flee = _prev_move * (1.0 - alpha_flee) + desire_flee * alpha_flee
		_prev_move = _normalize(smoothed_flee)
		return _prev_move

	# Standard kiter desire field.
	var desire = _build_desire(pos, enemies, bosses, loot, consumables, weapons, arena, profile, player)

	# Projectile-escape: sample candidate directions, pick safest, blend by urgency.
	var escape_dir = Vector2.ZERO
	var urgency = 0.0
	if not projectiles.empty():
		var result = _projectile_escape(pos, projectiles, player_speed, arena, desire, enemies, bosses)
		escape_dir = result[0]
		urgency = result[1]

	# Stop-and-shoot for Soldier (or any character that can't attack while moving).
	if not can_attack_moving:
		if _should_stand(state, pos, enemies, bosses, weapons):
			_prev_move = Vector2.ZERO
			return Vector2.ZERO

	var combined: Vector2
	if urgency > 0.0 and escape_dir != Vector2.ZERO:
		combined = desire * (1.0 - urgency) + escape_dir * urgency
	else:
		combined = desire
	combined = _normalize(combined)

	var alpha = BotConfig.MOVE_SMOOTHING
	var smoothed = _prev_move * (1.0 - alpha) + combined * alpha
	_prev_move = _normalize(smoothed)
	return _prev_move


# ─────────────────────── desire field (default kiter) ─────────────────────────

func _build_desire(pos, enemies, bosses, loot, consumables, weapons, arena, profile, player) -> Vector2:
	var engage = _engage_distance(profile, player, weapons)
	var force = _enemy_engagement_force(pos, enemies, bosses, engage, profile, false)
	if force.length() > 0.01:
		var perp = Vector2(-force.y, force.x)
		force += perp * BotConfig.CIRCLING_STRENGTH
	force += _loot_attraction(pos, enemies, bosses, loot)
	force += _consumable_attraction(pos, consumables, player, enemies, bosses)
	force += _wall_repulsion(pos, arena)
	force += _center_pull(pos, arena, enemies, bosses)
	return _normalize(force)


func _engage_distance(profile, player, weapons) -> float:
	if profile.fixed_engage_distance != null:
		return float(profile.fixed_engage_distance) * profile.engage_scale
	var ranges := []
	for w in weapons:
		var r = w.get("max_range", 0)
		if r != null and r > 0:
			ranges.append(float(r))
	if ranges.empty():
		return BotConfig.DEFAULT_ENGAGE_DISTANCE * profile.engage_scale
	var min_r: float = ranges[0]
	var max_r: float = ranges[0]
	for r in ranges:
		if r < min_r: min_r = r
		if r > max_r: max_r = r
	var aggressive: float = max(min_r * 0.85, BotConfig.MIN_ENGAGE_DISTANCE)
	var safe: float = max(max_r, BotConfig.SAFE_FALLBACK_DISTANCE)
	var hp = float(player.get("hp", 1))
	var mhp = max(float(player.get("max_hp", 1)), 1.0)
	var hp_ratio = hp / mhp
	var span = BotConfig.ENGAGE_HP_HIGH - BotConfig.ENGAGE_HP_LOW
	var t = (hp_ratio - BotConfig.ENGAGE_HP_LOW) / span if span > 0.0 else 1.0
	t = clamp(t, 0.0, 1.0)
	return (aggressive * t + safe * (1.0 - t)) * profile.engage_scale


func _enemy_engagement_force(pos, enemies, bosses, engage, profile, flee_only) -> Vector2:
	var force = Vector2.ZERO
	var nearest_d = INF
	var nearest_target = Vector2.ZERO
	var threats = []
	for e in enemies:
		threats.append([e, 1.0])
	for b in bosses:
		threats.append([b, BotConfig.BOSS_WEIGHT])

	if flee_only:
		var flee_range = max(engage, BotConfig.FLEE_REPEL_RANGE)
		for entry in threats:
			var target = _closest_approach(pos, entry[0])
			var diff = pos - target
			var d = max(diff.length(), 1.0)
			if d < flee_range:
				force += (diff / d) * (flee_range - d) * BotConfig.FLEE_REPEL_K * entry[1]
			if d < BotConfig.CONTACT_DANGER:
				force += (diff / d) * BotConfig.CONTACT_REPULSION * entry[1] / (d * d)
		return force

	for entry in threats:
		var target = _closest_approach(pos, entry[0])
		var diff = pos - target
		var d = max(diff.length(), 1.0)
		var dir_away = diff / d
		if d < engage:
			force += dir_away * (engage - d) * BotConfig.ENGAGE_SPRING_K * entry[1]
		if d < BotConfig.CONTACT_DANGER:
			force += dir_away * BotConfig.CONTACT_REPULSION * entry[1] / (d * d)
		if d < nearest_d:
			nearest_d = d
			nearest_target = target

	if profile.pursue_enemies and nearest_d != INF and nearest_d > engage * BotConfig.ENGAGE_PULL_THRESHOLD:
		force += (nearest_target - pos) / nearest_d * BotConfig.ENGAGE_PULL
	return force


func _closest_approach(pos, obj) -> Vector2:
	var o_pos = Vector2(obj.get("x", 0.0), obj.get("y", 0.0))
	var speed = float(obj.get("speed", 0.0))
	if speed <= 0.0:
		return o_pos
	var to_player = pos - o_pos
	var dist = to_player.length()
	if dist < 0.001:
		return o_pos
	return o_pos + to_player.normalized() * speed * BotConfig.ENEMY_LOOKAHEAD


# ─────────────────────── projectile escape (default kiter dodge) ──────────────

func _projectile_escape(pos, projectiles, player_speed, arena, desire, enemies, bosses) -> Array:
	var reach = player_speed * BotConfig.ESCAPE_HORIZON
	var threats = _threatening_bullets(pos, projectiles, reach)
	if threats.empty():
		return [Vector2.ZERO, 0.0]
	var T = BotConfig.ESCAPE_TIME_SAMPLES
	var horizon = BotConfig.ESCAPE_HORIZON
	var times = []
	for i in range(T):
		var t = (float(i) / max(T - 1, 1)) * horizon
		times.append(t)
	var bullets_t = []
	for ti in range(T):
		var ts = times[ti]
		var row = []
		for tr in threats:
			row.append(tr[0] + tr[1] * ts)
		bullets_t.append(row)
	var enemy_pts = []
	for e in enemies:
		enemy_pts.append(Vector2(e.get("x", 0.0), e.get("y", 0.0)))
	for b in bosses:
		enemy_pts.append(Vector2(b.get("x", 0.0), b.get("y", 0.0)))
	var n_dirs = BotConfig.ESCAPE_DIRECTIONS
	var best_dir = Vector2.ZERO
	var best_score = -1.0e18
	for k in range(n_dirs):
		var ang = (TAU * k) / float(n_dirs)
		var d = Vector2(cos(ang), sin(ang))
		var clearance = _dir_clearance(pos, d, player_speed, bullets_t, times, arena)
		var align = 0.0
		if desire.length() > 0:
			align = d.dot(desire)
		var penalty = _enemy_path_penalty(pos, d, player_speed, times, enemy_pts)
		var score = clearance + BotConfig.ESCAPE_ALIGN_BONUS * align - penalty
		if score > best_score:
			best_score = score
			best_dir = d
	var default_d = desire if desire.length() > 0 else Vector2.ZERO
	var default_clear = _dir_clearance(pos, default_d, player_speed, bullets_t, times, arena)
	var safe = BotConfig.ESCAPE_SAFE_CLEARANCE
	var panic = BotConfig.ESCAPE_PANIC_CLEARANCE
	var urgency: float
	if default_clear >= safe:
		urgency = 0.0
	elif default_clear <= panic:
		urgency = 1.0
	else:
		urgency = (safe - default_clear) / max(safe - panic, 1.0)
	return [best_dir, urgency]


func _threatening_bullets(pos, projectiles, reach) -> Array:
	var margin = BotConfig.PROJ_THREAT_RADIUS + reach
	var horizon = BotConfig.ESCAPE_HORIZON
	var out = []
	for p in projectiles:
		var p_pos = Vector2(p.get("x", 0.0), p.get("y", 0.0))
		var p_vel = Vector2(p.get("vx", 0.0), p.get("vy", 0.0))
		var speed_sq = p_vel.x * p_vel.x + p_vel.y * p_vel.y
		var rel = pos - p_pos
		if speed_sq < 1.0:
			if rel.length() < margin:
				out.append([p_pos, p_vel])
			continue
		var t = rel.dot(p_vel) / speed_sq
		t = clamp(t, 0.0, horizon)
		var closest = p_pos + p_vel * t
		if (pos - closest).length() < margin:
			out.append([p_pos, p_vel])
	return out


func _dir_clearance(pos, d, player_speed, bullets_t, times, arena) -> float:
	var min_d = INF
	for ti in range(times.size()):
		var p_t = pos + d * (player_speed * times[ti])
		for bullet_pt in bullets_t[ti]:
			var dist = (p_t - bullet_pt).length()
			if dist < min_d:
				min_d = dist
	var clearance = min_d
	if d.length() > 0:
		var horizon_t = times[times.size() - 1]
		var end_pt = pos + d * (player_speed * horizon_t)
		var m = BotConfig.ESCAPE_WALL_MARGIN
		var w = arena.get("width", 2048.0)
		var h = arena.get("height", 1536.0)
		if end_pt.x < m or end_pt.x > w - m or end_pt.y < m or end_pt.y > h - m:
			clearance -= BotConfig.ESCAPE_WALL_PENALTY
	return clearance


func _enemy_path_penalty(pos, d, player_speed, times, enemy_pts) -> float:
	if enemy_pts.empty():
		return 0.0
	var nearest = INF
	for ti in range(times.size()):
		var p_t = pos + d * (player_speed * times[ti])
		for ep in enemy_pts:
			var dist = (p_t - ep).length()
			if dist < nearest:
				nearest = dist
	if nearest >= BotConfig.ENEMY_AVOID_DIST:
		return 0.0
	return (BotConfig.ENEMY_AVOID_DIST - nearest) * BotConfig.ENEMY_AVOID_PENALTY


# ─────────────────────── panic dodge (used by pure_repulsion) ─────────────────

func _panic_dodge(pos, enemies, bosses, projectiles, arena) -> Vector2:
	# Returns ZERO when no panic; otherwise a unit-length direction.
	var panic = Vector2.ZERO
	var fired = false
	var body_r = BotConfig.PANIC_BODY_REACH
	var bullet_r = BotConfig.PANIC_BULLET_REACH
	var threats = []
	for e in enemies:
		threats.append(e)
	for b in bosses:
		threats.append(b)
	for e in threats:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		var diff = pos - ep
		var d = diff.length()
		if d < body_r and d > 1.0:
			panic += (diff / d) * (body_r - d)
			fired = true
	for p in projectiles:
		var pp = Vector2(p.get("x", 0.0), p.get("y", 0.0))
		var diff = pos - pp
		var d = diff.length()
		if d < bullet_r and d > 1.0:
			var pv = Vector2(p.get("vx", 0.0), p.get("vy", 0.0))
			var pv_mag = pv.length()
			if pv_mag > 1.0:
				var perp = Vector2(-pv.y, pv.x) / pv_mag
				var sign_v = 1.0 if diff.dot(perp) > 0 else -1.0
				panic += perp * sign_v * (bullet_r - d) * 1.5
			else:
				panic += (diff / d) * (bullet_r - d) * 1.5
			fired = true
	if not fired:
		return Vector2.ZERO
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var margin = BotConfig.REPULSION_WALL_MARGIN
	var wk = BotConfig.PANIC_WALL_K
	if pos.x < margin:
		panic.x += wk * (margin - pos.x) / margin
	if pos.x > w - margin:
		panic.x -= wk * (pos.x - (w - margin)) / margin
	if pos.y < margin:
		panic.y += wk * (margin - pos.y) / margin
	if pos.y > h - margin:
		panic.y -= wk * (pos.y - (h - margin)) / margin
	var m = panic.length()
	if m > BotConfig.PANIC_MIN_MAGNITUDE:
		return panic / m
	# Forces cancelled (mirror-bullet trap). Pick a direction perpendicular
	# to the threat axis so the bot SLIPS BETWEEN them instead of stalling.
	# This is the missing piece that caused trembling for Wounded/Pacifist
	# when two projectiles approached head-on at the player.
	var threat_axis = _threat_principal_axis(pos, enemies, bosses, projectiles,
		BotConfig.PANIC_BODY_REACH, BotConfig.PANIC_BULLET_REACH)
	if threat_axis.length() > 0.01:
		return _perpendicular_escape(threat_axis, pos, arena)
	# Final fallback: tangent along the dominant wall (original behaviour).
	var near_x_min = pos.x < margin
	var near_x_max = pos.x > w - margin
	var near_y_min = pos.y < margin
	var near_y_max = pos.y > h - margin
	if near_x_min or near_x_max or near_y_min or near_y_max:
		var tangent = Vector2.ZERO
		if near_x_min or near_x_max:
			tangent.y = 1.0 if pos.y < h * 0.5 else -1.0
		if near_y_min or near_y_max:
			tangent.x = 1.0 if pos.x < w * 0.5 else -1.0
		if tangent.length() > 0:
			return tangent.normalized()
	return Vector2.ZERO


# Returns the dominant direction along which nearby threats lie. For two
# bullets approaching head-on (player between), this returns roughly the
# axis connecting them — and we step perpendicular to it to slip out.
func _threat_principal_axis(pos, enemies, bosses, projectiles, body_r, bullet_r) -> Vector2:
	# Sum of (threat_pos - player) for nearby threats, plus second-moment
	# axis when sums cancel. For mirrored threats, sum is zero; we fall back
	# to picking the longest displacement vector.
	var dirs = []
	for e in enemies:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		var d = (ep - pos).length()
		if d < body_r and d > 1.0:
			dirs.append(ep - pos)
	for b in bosses:
		var bp = Vector2(b.get("x", 0.0), b.get("y", 0.0))
		var d = (bp - pos).length()
		if d < body_r and d > 1.0:
			dirs.append(bp - pos)
	for p in projectiles:
		var pp = Vector2(p.get("x", 0.0), p.get("y", 0.0))
		var d = (pp - pos).length()
		if d < bullet_r and d > 1.0:
			dirs.append(pp - pos)
	if dirs.empty():
		return Vector2.ZERO
	# When threats mirror each other, the sum cancels. Pick the LINE that
	# best fits them: use the first vector's direction (or longest).
	var sum_vec = Vector2.ZERO
	for v in dirs:
		sum_vec += v
	if sum_vec.length() > 1.0:
		return sum_vec.normalized()
	# Sum cancelled — pick the longest single displacement.
	var longest = dirs[0]
	for v in dirs:
		if v.length() > longest.length():
			longest = v
	return longest.normalized()


# Given a threat axis, return a unit vector perpendicular to it. Pick the
# perpendicular side that aims toward arena center (more room to manoeuvre).
func _perpendicular_escape(axis, pos, arena) -> Vector2:
	var perp = Vector2(-axis.y, axis.x)
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var center = Vector2(w * 0.5, h * 0.5)
	var to_center = center - pos
	# Choose the perpendicular sign that points toward the center.
	if to_center.dot(perp) < 0:
		perp = -perp
	return perp.normalized()


# ─────────────────────── bull cluster rush ────────────────────────────────────

func _bull_attack_dir(pos, enemies, bosses, arena) -> Vector2:
	var threats = []
	for e in enemies:
		threats.append(e)
	for b in bosses:
		threats.append(b)
	if threats.size() < BotConfig.BULL_CLUSTER_MIN:
		return Vector2.ZERO
	var centroid = Vector2.ZERO
	for e in threats:
		centroid += Vector2(e.get("x", 0.0), e.get("y", 0.0))
	centroid /= float(threats.size())
	var inside = 0
	for e in threats:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		if (ep - centroid).length() < BotConfig.BULL_CLUSTER_RADIUS:
			inside += 1
	if inside < BotConfig.BULL_CLUSTER_MIN:
		return Vector2.ZERO
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var m = BotConfig.REPULSION_WALL_MARGIN
	if (centroid.x < m or centroid.x > w - m or centroid.y < m or centroid.y > h - m):
		return Vector2.ZERO
	var to = centroid - pos
	if to.length() < 1.0:
		return Vector2.ZERO
	return to.normalized()


# ─────────────────────── pure repulsion (Bull/Wounded/Beast Master baseline) ──

func _pure_repulsion_flee(pos, enemies, bosses, projectiles, arena, prev_dir) -> Vector2:
	# Panic is handled in compute_movement before we get here.
	var flee = Vector2.ZERO

	# 1) Centroid flee.
	var nearby = []
	var reach = BotConfig.REPULSION_CENTROID_REACH
	for e in enemies:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		if (ep - pos).length() < reach:
			nearby.append(ep)
	for b in bosses:
		var bp = Vector2(b.get("x", 0.0), b.get("y", 0.0))
		if (bp - pos).length() < reach:
			nearby.append(bp)
	if not nearby.empty():
		var centroid = Vector2.ZERO
		for n in nearby:
			centroid += n
		centroid /= float(nearby.size())
		var away = pos - centroid
		var ad = away.length()
		if ad > 1.0:
			flee += (away / ad) * BotConfig.REPULSION_CENTROID_K
	elif prev_dir.length() > 0.5:
		flee += prev_dir * BotConfig.REPULSION_CENTROID_K * 0.5

	# 2) Wall repulsion.
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var margin = BotConfig.REPULSION_WALL_MARGIN
	var wk = BotConfig.REPULSION_WALL_K
	if pos.x < margin:
		flee.x += wk * (margin - pos.x) / margin
	if pos.x > w - margin:
		flee.x -= wk * (pos.x - (w - margin)) / margin
	if pos.y < margin:
		flee.y += wk * (margin - pos.y) / margin
	if pos.y > h - margin:
		flee.y -= wk * (pos.y - (h - margin)) / margin

	# 3) Center pull (mild).
	var center = Vector2(w * 0.5, h * 0.5)
	var to_c = center - pos
	var cd = to_c.length()
	if cd > BotConfig.REPULSION_CENTER_INNER:
		var pull = min(1.0, (cd - BotConfig.REPULSION_CENTER_INNER) / BotConfig.REPULSION_CENTER_SPAN)
		flee += (to_c / cd) * BotConfig.REPULSION_CENTER_K * pull

	# 4) Projectile dodge — perpendicular sidestep.
	for p in projectiles:
		var pp = Vector2(p.get("x", 0.0), p.get("y", 0.0))
		var diff = pp - pos
		var d = diff.length()
		if d > BotConfig.REPULSION_BULLET_REACH or d < 1.0:
			continue
		var pv = Vector2(p.get("vx", 0.0), p.get("vy", 0.0))
		var pv_mag = pv.length()
		if pv_mag > 1.0:
			var perp = Vector2(-pv.y, pv.x) / pv_mag
			var sign_v = 1.0 if (pos - pp).dot(perp) > 0 else -1.0
			flee += perp * sign_v * BotConfig.REPULSION_BULLET_K * (BotConfig.REPULSION_BULLET_REACH - d) / BotConfig.REPULSION_BULLET_REACH
		else:
			flee += (-diff / d) * BotConfig.REPULSION_BULLET_K * (BotConfig.REPULSION_BULLET_REACH - d) / BotConfig.REPULSION_BULLET_REACH

	# Detect cancellation (mirror-bullet trap): when summed forces are tiny
	# despite obvious threats nearby, pick a perpendicular escape direction
	# instead of returning prev_dir (which often points STRAIGHT INTO a
	# bullet on its path). This is the trembling Pacifist/Wounded user saw.
	var mag = flee.length()
	if mag < BotConfig.PANIC_MIN_MAGNITUDE:
		var threat_axis = _threat_principal_axis(pos, enemies, bosses, projectiles,
			BotConfig.REPULSION_CENTROID_REACH, BotConfig.REPULSION_BULLET_REACH)
		if threat_axis.length() > 0.01:
			return _perpendicular_escape(threat_axis, pos, arena)
	if mag > 0:
		return flee / mag
	if prev_dir.length() > 0.5:
		return prev_dir.normalized()
	return Vector2(1.0, 0.0)


# ─────────────────────── orbital flee (Beast Master) ──────────────────────────

func _orbital_flee(pos, enemies, bosses, projectiles, arena, prev_dir, player_speed) -> Vector2:
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var center = Vector2(w * 0.5, h * 0.5)
	var radial = pos - center
	var rad_dist = radial.length()
	var target_radius = min(w, h) * BotConfig.ORBIT_RADIUS_FRACTION
	if rad_dist < 1.0:
		if prev_dir.length() > 0.5:
			return prev_dir.normalized()
		return Vector2(1.0, 0.0)
	var radial_unit = radial / rad_dist
	# Screen-clockwise tangent (Y-down): (-y, x)
	var tangent = Vector2(-radial_unit.y, radial_unit.x)
	var drift = abs(rad_dist - target_radius) / target_radius
	var radial_sign: float
	if rad_dist > target_radius:
		radial_sign = -1.0
	elif rad_dist < target_radius * BotConfig.ORBIT_INNER_FRACTION:
		radial_sign = 1.0
		drift = (target_radius * BotConfig.ORBIT_INNER_FRACTION - rad_dist) / (target_radius * BotConfig.ORBIT_INNER_FRACTION)
	else:
		radial_sign = 0.0
		drift = 0.0
	var radial_weight = min(BotConfig.ORBIT_RADIAL_MIX_MAX,
		BotConfig.ORBIT_RADIAL_MIX_BASE + drift * BotConfig.ORBIT_RADIAL_MIX_GAIN)
	var direction = tangent * (1.0 - radial_weight) + radial_unit * radial_sign * radial_weight
	var nrm = direction.length()
	if nrm > 0:
		direction /= nrm

	# Threat veer.
	var threats_pos = []
	var threats_vel = []
	var safety = BotConfig.FLEE_ENEMY_SPEED_SAFETY
	for e in enemies:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		threats_pos.append(ep)
		threats_vel.append(_enemy_velocity(pos, ep, float(e.get("speed", 0.0)) * safety))
	for b in bosses:
		var bp = Vector2(b.get("x", 0.0), b.get("y", 0.0))
		threats_pos.append(bp)
		threats_vel.append(_enemy_velocity(pos, bp, float(b.get("speed", 0.0)) * safety))
	for p in projectiles:
		threats_pos.append(Vector2(p.get("x", 0.0), p.get("y", 0.0)))
		threats_vel.append(Vector2(p.get("vx", 0.0), p.get("vy", 0.0)))

	if not threats_pos.empty():
		var veer = Vector2.ZERO
		var min_d_overall = INF
		var horizon = BotConfig.ORBIT_VEER_HORIZON
		var n_steps = BotConfig.ORBIT_VEER_STEPS
		var dt = horizon / float(n_steps)
		var bot_pred = pos
		var threats_pred = []
		for tp in threats_pos:
			threats_pred.append(tp)
		for step in range(n_steps):
			bot_pred += direction * player_speed * dt
			for i in range(threats_vel.size()):
				threats_pred[i] += threats_vel[i] * dt
				var diff = bot_pred - threats_pred[i]
				var d = diff.length()
				if d < min_d_overall:
					min_d_overall = d
				if d < BotConfig.ORBIT_VEER_DIST:
					var away = diff / max(d, 1.0)
					var weight = (BotConfig.ORBIT_VEER_DIST - d) / BotConfig.ORBIT_VEER_DIST
					veer += away * weight
		if min_d_overall < BotConfig.ORBIT_CRITICAL_DIST and veer.length() < 0.5:
			veer = radial_unit * BotConfig.ORBIT_CRITICAL_RADIAL
		if veer.length() > 0:
			veer = veer.normalized()
			direction = direction * (1.0 - BotConfig.ORBIT_VEER_STRENGTH) + veer * BotConfig.ORBIT_VEER_STRENGTH
			var n2 = direction.length()
			if n2 > 0:
				direction /= n2

	# Enforce strict CW: at least ORBIT_MIN_TANGENT in the CW direction.
	var cw_component = direction.dot(tangent)
	if cw_component < BotConfig.ORBIT_MIN_TANGENT:
		var radial_component = direction.dot(radial_unit)
		if abs(radial_component) < 0.05:
			radial_component = BotConfig.ORBIT_TANGENT_BLOCK_RADIAL_NUDGE
		direction = tangent * BotConfig.ORBIT_MIN_TANGENT + radial_unit * radial_component
		var n3 = direction.length()
		if n3 > 0:
			direction /= n3
		else:
			direction = tangent
	return direction


# ─────────────────────── Pacifist sampling flee ──────────────────────────────

func _flee_direction(pos, enemies, bosses, arena, player_speed, projectiles, prev_dir, profile) -> Vector2:
	var threats = []
	for e in enemies:
		threats.append(e)
	for b in bosses:
		threats.append(b)
	var T = BotConfig.FLEE_TIME_SAMPLES
	var horizon = BotConfig.FLEE_HORIZON
	var times = []
	for i in range(T):
		times.append((float(i) / max(T - 1, 1)) * horizon)

	# Enemy trajectories.
	var enemies_t = []  # T entries, each an Array of Vector2 (one per enemy)
	if not threats.empty():
		var e_pos = []
		var e_vel = []
		var safety = BotConfig.FLEE_ENEMY_SPEED_SAFETY
		for e in threats:
			var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
			e_pos.append(ep)
			e_vel.append(_enemy_velocity(pos, ep, float(e.get("speed", 0.0)) * safety))
		for ti in range(T):
			var row = []
			for i in range(e_pos.size()):
				row.append(e_pos[i] + e_vel[i] * times[ti])
			enemies_t.append(row)
	# Projectile trajectories.
	var proj_t = []
	if not projectiles.empty():
		var p_pos = []
		var p_vel = []
		for p in projectiles:
			p_pos.append(Vector2(p.get("x", 0.0), p.get("y", 0.0)))
			p_vel.append(Vector2(p.get("vx", 0.0), p.get("vy", 0.0)))
		for ti in range(T):
			var row = []
			for i in range(p_pos.size()):
				row.append(p_pos[i] + p_vel[i] * times[ti])
			proj_t.append(row)
	if enemies_t.empty() and proj_t.empty():
		return Vector2.ZERO

	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var margin = BotConfig.FLEE_WALL_MARGIN
	var center = Vector2(w * 0.5, h * 0.5)
	var to_center = center - pos
	var to_center_norm = to_center.length()
	var center_dir = to_center / to_center_norm if to_center_norm > 1.0 else Vector2.ZERO
	var wall_proximity = min(min(pos.x, w - pos.x), min(pos.y, h - pos.y))
	var stuck_mult = BotConfig.FLEE_STUCK_CENTER_MULT if wall_proximity < BotConfig.FLEE_STUCK_DIST else 1.0
	var body_pen_mult: float = profile.body_pen_multiplier

	var best_dir = Vector2.ZERO
	var best_score = -1.0e18
	var n_dirs = BotConfig.FLEE_DIRECTIONS
	for k in range(n_dirs):
		var ang = (TAU * k) / float(n_dirs)
		var d = Vector2(cos(ang), sin(ang))
		var player_t = []
		for ti in range(T):
			player_t.append(pos + d * (player_speed * times[ti]))

		# Enemy clearance + crowd penalty.
		var min_e = INF
		var crowd_pen = 0.0
		if not enemies_t.empty():
			for ti in range(T):
				for ep in enemies_t[ti]:
					var dist = (player_t[ti] - ep).length()
					if dist < min_e:
						min_e = dist
					if dist < BotConfig.FLEE_CROWD_RADIUS:
						crowd_pen += (BotConfig.FLEE_CROWD_RADIUS - dist) * BotConfig.FLEE_CROWD_K

		# Projectile clearance.
		var min_p = INF
		if not proj_t.empty():
			for ti in range(T):
				for pp in proj_t[ti]:
					var dist = (player_t[ti] - pp).length()
					if dist < min_p:
						min_p = dist

		var min_d = min(min_e, min_p)
		var bullet_pen = 0.0
		if min_p < BotConfig.FLEE_BULLET_DANGER:
			bullet_pen = (BotConfig.FLEE_BULLET_DANGER - min_p) * BotConfig.FLEE_BULLET_K
		var body_pen = 0.0
		if body_pen_mult > 0 and min_e < BotConfig.FLEE_BODY_DANGER:
			var gap = BotConfig.FLEE_BODY_DANGER - min_e
			body_pen = gap * gap * BotConfig.FLEE_BODY_K * body_pen_mult

		# Wall penalty (averaged across path).
		var wall_pen = 0.0
		for pt in player_t:
			if pt.x < margin:
				wall_pen += BotConfig.FLEE_WALL_PENALTY * (margin - pt.x) / margin
			if pt.x > w - margin:
				wall_pen += BotConfig.FLEE_WALL_PENALTY * (pt.x - (w - margin)) / margin
			if pt.y < margin:
				wall_pen += BotConfig.FLEE_WALL_PENALTY * (margin - pt.y) / margin
			if pt.y > h - margin:
				wall_pen += BotConfig.FLEE_WALL_PENALTY * (pt.y - (h - margin)) / margin
		wall_pen /= float(player_t.size())

		var center_align = d.dot(center_dir) if to_center_norm > 1.0 else 0.0
		var center_factor = min(1.0, to_center_norm / max(w, h) * 2.0)
		var center_bonus = BotConfig.FLEE_CENTER_BIAS * center_align * center_factor * stuck_mult
		if center_align < 0:
			center_bonus -= BotConfig.FLEE_AWAY_PENALTY * (-center_align) * center_factor * center_factor

		# Hysteresis.
		var hyst = 0.0
		if prev_dir.length() > 0.5:
			var dot_v = d.dot(prev_dir)
			hyst = BotConfig.FLEE_HYSTERESIS_BONUS * dot_v
			if dot_v < 0:
				hyst -= BotConfig.FLEE_REVERSE_PENALTY * (-dot_v)

		var score = min_d - crowd_pen - wall_pen - bullet_pen - body_pen + center_bonus + hyst
		if score > best_score:
			best_score = score
			best_dir = d
	# Tie-breaker: when every direction scored very badly (all paths walk into
	# a bullet or body), the sampler returns the "least bad" one — often
	# diagonally INTO a hazard. If best score is below a panic threshold,
	# slip perpendicular to the dominant threat axis instead.
	if best_score < -BotConfig.FLEE_BULLET_K * BotConfig.FLEE_BULLET_DANGER * 0.5:
		var axis = _threat_principal_axis(pos, enemies, bosses, projectiles,
			BotConfig.FLEE_BODY_DANGER * 2.0, BotConfig.FLEE_BULLET_DANGER * 2.0)
		if axis.length() > 0.01:
			return _perpendicular_escape(axis, pos, arena)
	return best_dir


# ─────────────────────── Soldier stop-and-shoot ───────────────────────────────

func _should_stand(state, pos, enemies, bosses, weapons) -> bool:
	# Stand still to fire only when safe AND an enemy is in firing range.
	for p in state.get("projectiles", []):
		if _bullet_threatens_point(pos, p, BotConfig.PROJ_MAX_HORIZON, BotConfig.STAND_BULLET_CLEAR):
			return false
	var nearest = _nearest_threat_dist(pos, enemies, bosses)
	if nearest < BotConfig.STAND_DANGER_DIST:
		return false
	var max_range = BotConfig.DEFAULT_ENGAGE_DISTANCE
	for w in weapons:
		var r = w.get("max_range", 0)
		if r != null and r > max_range:
			max_range = float(r)
	if nearest > max_range:
		return false
	return true


func _bullet_threatens_point(pos, p, horizon, radius) -> bool:
	# Would this bullet pass within `radius` of a stationary player within `horizon`?
	var p_pos = Vector2(p.get("x", 0.0), p.get("y", 0.0))
	var p_vel = Vector2(p.get("vx", 0.0), p.get("vy", 0.0))
	var speed_sq = p_vel.x * p_vel.x + p_vel.y * p_vel.y
	var rel = pos - p_pos
	if speed_sq < 1.0:
		return rel.length() < radius
	var t = rel.dot(p_vel) / speed_sq
	t = clamp(t, 0.0, horizon)
	var closest = p_pos + p_vel * t
	return (pos - closest).length() < radius


# ─────────────────────── helpers ──────────────────────────────────────────────

func _normalize(v) -> Vector2:
	var m = v.length()
	if m < 0.001:
		return Vector2.ZERO
	return v / m


func _enemy_velocity(pos, e_pos, speed) -> Vector2:
	if speed <= 0.0:
		return Vector2.ZERO
	var toward = pos - e_pos
	var d = toward.length()
	if d < 1.0:
		return Vector2.ZERO
	return (toward / d) * speed


func _wall_repulsion(pos, arena) -> Vector2:
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var f = Vector2.ZERO
	var margin = BotConfig.WALL_MARGIN
	var k = BotConfig.WALL_REPULSION
	if pos.x < margin:
		f.x += k / sqrt(max(pos.x, 1.0))
	if pos.x > w - margin:
		f.x -= k / sqrt(max(w - pos.x, 1.0))
	if pos.y < margin:
		f.y += k / sqrt(max(pos.y, 1.0))
	if pos.y > h - margin:
		f.y -= k / sqrt(max(h - pos.y, 1.0))
	return f


func _center_pull(pos, arena, enemies, bosses) -> Vector2:
	var w = arena.get("width", 2048.0)
	var h = arena.get("height", 1536.0)
	var center = Vector2(w * 0.5, h * 0.5)
	var margin = BotConfig.WALL_MARGIN * 2.0
	var near_wall = (pos.x < margin or pos.x > w - margin
		or pos.y < margin or pos.y > h - margin)
	if not near_wall:
		return Vector2.ZERO
	var threat_dist = _nearest_threat_dist(pos, enemies, bosses)
	if threat_dist > BotConfig.SAFETY_DISTANCE * 2.0:
		return Vector2.ZERO
	var diff = center - pos
	var dist = max(diff.length(), 1.0)
	return (diff / dist) * 200.0


func _nearest_threat_dist(pos, enemies, bosses) -> float:
	var min_d = INF
	for e in enemies:
		var ep = Vector2(e.get("x", 0.0), e.get("y", 0.0))
		var d = (ep - pos).length()
		if d < min_d:
			min_d = d
	for b in bosses:
		var bp = Vector2(b.get("x", 0.0), b.get("y", 0.0))
		var d = (bp - pos).length()
		if d < min_d:
			min_d = d
	return min_d


func _loot_attraction(pos, enemies, bosses, loot) -> Vector2:
	if loot.empty():
		return Vector2.ZERO
	var threat_dist = _nearest_threat_dist(pos, enemies, bosses)
	var safety_raw = min(1.0, threat_dist / BotConfig.SAFETY_DISTANCE)
	var safety = safety_raw * safety_raw
	var force = Vector2.ZERO
	for item in loot:
		var ip = Vector2(item.get("x", 0.0), item.get("y", 0.0))
		var diff = ip - pos
		var dist = max(diff.length(), 1.0)
		force += (diff / dist) * BotConfig.LOOT_ATTRACTION * safety / dist
	return force


func _consumable_attraction(pos, consumables, player, enemies, bosses) -> Vector2:
	if consumables.empty():
		return Vector2.ZERO
	var hp = float(player.get("hp", 1))
	var max_hp = max(float(player.get("max_hp", 1)), 1.0)
	var hp_ratio = hp / max_hp
	var urgency = max(0.3, 1.0 - hp_ratio)
	var threat_dist = _nearest_threat_dist(pos, enemies, bosses)
	var safety = min(1.0, threat_dist / BotConfig.SAFETY_DISTANCE)
	var force = Vector2.ZERO
	for c in consumables:
		var cp = Vector2(c.get("x", 0.0), c.get("y", 0.0))
		var diff = cp - pos
		var dist = max(diff.length(), 1.0)
		force += (diff / dist) * BotConfig.CONSUMABLE_ATTRACTION * urgency * safety / dist
	return force
