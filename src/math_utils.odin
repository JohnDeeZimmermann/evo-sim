package main

import "core:math"
import "core:math/linalg"

Vec2 :: linalg.Vector2f32

Radians :: distinct f32
Degrees :: distinct f32

Angle :: union {
	Radians,
	Degrees,
}

PolarPoint :: struct {
	angle:  Angle,
	radius: f32,
}

velocity_for_direction :: proc(direction: Vec2, distance: f32, speed: f32) -> Vec2 {
	if distance == 0 {
		return {}
	}

	return {direction.x / distance * speed, direction.y / distance * speed}
}

direction_to :: proc(position: Vec2, target: Vec2) -> Vec2 {
	return {target.x - position.x, target.y - position.y}
}

rotation_for_direction :: proc(direction: Vec2) -> f32 {
	return math.atan2_f32(direction.y, direction.x) * 180 / math.PI
}

velocity_for_rotation :: proc(rotation: f32, speed: f32) -> Vec2 {
	radians := rotation * math.PI / 180
	return {math.cos_f32(radians) * speed, math.sin_f32(radians) * speed}
}

velocity_distance_rotation_to :: proc(
	position: Vec2,
	target: Vec2,
	speed: f32,
) -> (
	velocity: Vec2,
	distance: f32,
	rotation: f32,
) {
	direction := direction_to(position, target)

	distance = linalg.distance(position, target)
	rotation = rotation_for_direction(direction)
	velocity = velocity_for_direction(direction, distance, speed)

	return velocity, distance, rotation
}

point_from_angled_radius :: proc(pos: Vec2, radius: f32, angle: f32) -> Vec2 {
	radians := linalg.to_radians(angle)
	return Vec2{pos.x + math.cos(radians) * radius, pos.y + math.sin(radians) * radius}
}

angle_to_radians :: proc(angle: Angle) -> Radians {
	switch actual in angle {
	case Radians:
		return actual
	case Degrees:
		return Radians(linalg.to_radians(actual))
	}

	assert(true, "Angle is of invalid type")
	return 0
}

point_from_polar_point :: proc(point: PolarPoint, origin: Vec2 = {}) -> Vec2 {
	radians := f32(angle_to_radians(point.angle))
	radius := point.radius
	return Vec2{origin.x + math.cos(radians) * radius, origin.y + math.sin(radians) * radius}
}
