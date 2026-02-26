class_name CyclistPhysics
extends Object

# Pure physics module ported from CyclistPhysics.ts

const G: float = 9.80665

## Compute the forces and resulting acceleration (m/s²) for a given power and velocity.
##
## Modifiers:
## - 'powerMult': Multiplicative scaling for effective power (combined items + surge).
## - 'weightMult': Multiplicative scaling for effective mass.
## - 'crrMult': Multiplicative scaling for rolling resistance (combined surface + items).
## - 'dragReduction': Additive reduction factor for CdA (0.0 to 0.99).
static func calculate_acceleration(
	power_w: float,
	current_velocity_ms: float,
	stats: CyclistStats,
	grade: float = 0.0,
	modifiers: Dictionary = {}
) -> float:
	var cdA: float = stats.cda
	var rhoAir: float = stats.rho_air
	var crr: float = stats.crr
	var massKg: float = stats.mass_kg
	
	var power_mult: float = modifiers.get("powerMult", 1.0)
	var drag_reduction: float = modifiers.get("dragReduction", 0.0)
	var weight_mult: float = modifiers.get("weightMult", 1.0)
	var crr_mult: float = modifiers.get("crrMult", 1.0)
	
	var effective_power: float = power_w * power_mult
	var effective_cdA: float = cdA * (1.0 - drag_reduction)
	var effective_mass: float = massKg * weight_mult
	var effective_crr: float = crr * crr_mult
	
	var theta: float = atan(grade)
	var cos_theta: float = cos(theta)
	var sin_theta: float = sin(theta)
	
	# F_propulsion = P / v
	# Avoid division by zero at standstill.
	var v: float = max(current_velocity_ms, 0.1)
	var propulsion_force: float = effective_power / v
	
	# Resistance forces:
	# Drag = ½ρCdA·v²
	var aero_force: float = 0.5 * rhoAir * effective_cdA * current_velocity_ms * current_velocity_ms
	# Rolling resistance = Crr·m·g·cosθ
	var rolling_force: float = effective_crr * effective_mass * G * cos_theta
	# Gravity = m·g·sinθ
	var grade_force: float = effective_mass * G * sin_theta
	
	# F_net = F_propulsion - (F_aero + F_rolling + F_grade)
	var net_force: float = propulsion_force - (aero_force + rolling_force + grade_force)
	
	return net_force / effective_mass

## Calculates the effective grade, Crr, and CWA parameters to send to the FTMS Smart Trainer
static func get_trainer_simulation_params(stats: CyclistStats, current_grade: float) -> Dictionary:
	var assumed_trainer_mass: float = 83.0
	var mass_ratio: float = stats.mass_kg / assumed_trainer_mass
	
	return {
		"grade": current_grade * mass_ratio,
		"crr": stats.crr * mass_ratio,
		"cwa": stats.cda 
	}

static func ms_to_kmh(ms: float) -> float:
	return ms * 3.6

static func ms_to_mph(ms: float) -> float:
	return ms * 2.23694
