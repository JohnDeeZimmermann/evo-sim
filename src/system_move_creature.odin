package main

import "core:math"
import "ecs"

SystemCreatureMovement :: SystemDefinition {
	run = creature_movement_system,
}

creature_movement_system :: proc(
	world: ^ecs.World,
	dt: f32,
	tick: Tick,
	result: ^SystemResult,
) -> (
	ok: bool,
) {
	for archetype in ecs.query(
		world,
		{ecs.and(Rotation, Velocity, CreatureData), ecs.not(CreatureIsDead)},
	) {
		rotations := ecs.get_table(world, archetype, Rotation)
		velocities := ecs.get_table(world, archetype, Velocity)
		creatures := ecs.get_table(world, archetype, CreatureData)

		for i in 0 ..< len(archetype.entities) {
			rotation := &rotations[i]
			vel := &velocities[i]
			creature := creatures[i]
			rotation^ += math.mod((dt * creature.outputs.rotate * 360), 360)

			speed := creature.base_genes.speed * f32(creature.outputs.speed)

			vel^ = Velocity(velocity_for_rotation(rotation^, 15))
		}
	}

	return true
}
