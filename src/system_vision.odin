package main

import "ecs"

FilterTargetType :: enum {
	FOOD,
	ANYTHING,
	CREATURE,
}

FilterTargetScale :: enum {
	FIT,
	HARDNESS,
	DISTANCE,
}

FilterTarget :: struct {
	type:  FilterTargetType,
	scale: FilterTargetScale,
}

EyeRay :: struct {
	angle:    Percentage,
	distance: Percentage,
	target:   FilterTarget,
}

Vision :: struct {
	eye_angle: Angle,
	rays:      [dynamic; 16]EyeRay,
}

system_vision :: proc(
	world: ^ecs.World,
	dt: f32,
	tick: Tick,
	result: ^SystemResult,
) -> (
	ok: bool,
) {

	return true
}
