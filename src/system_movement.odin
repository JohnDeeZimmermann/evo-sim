package main

import "ecs"

SystemMovement :: SystemDefinition {
	run = movement_system,
}

movement_system :: proc(world: ^ecs.World, dt: f32, result: ^SystemResult) -> (ok: bool) {
	for archetype in ecs.query(world, {Position, Velocity}) {
		positions := ecs.get_table(world, archetype, Position)
		velocities := ecs.get_table(world, archetype, Velocity)

		for i in 0 ..< len(positions) {
			positions[i].x += velocities[i].x * dt
			positions[i].y += velocities[i].y * dt
		}
	}

	return true
}
