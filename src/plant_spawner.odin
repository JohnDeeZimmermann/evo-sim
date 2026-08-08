package main

import "ecs"

import "core:math/rand"

PlantSpawner :: struct {
	spawnChance:   f32,
	min_nutrition: f32,
	max_nutrition: f32,
	radius:        f32,
}

SystemPlantSpawner :: SystemDefinition {
	run = plant_spawner_system,
}

plant_spawner_system :: proc(
	world: ^ecs.World,
	dt: f32,
	tick: Tick,
	result: ^SystemResult,
) -> (
	ok: bool,
) {

	for arch in ecs.query(world, {PlantSpawner, Position}) {
		positions := ecs.get_table(world, arch, Position)
		plant_spawners := ecs.get_table(world, arch, PlantSpawner)

		for position, idx in positions {
			spawner := plant_spawners[idx]
			if rand.float32() < spawner.spawnChance {
				nutrition :=
					spawner.min_nutrition +
					f32(spawner.max_nutrition - spawner.min_nutrition) * rand.float32()

				random_angle := rand.float32() * 360
				random_radius := rand.float32() * spawner.radius

				random_pos := point_from_angled_radius(Vec2(position), random_radius, random_angle)
				food_create_plant(world, Position(random_pos), nutrition)
			}

		}
	}

	return true
}

plant_spawner_create_random :: proc(
	world: ^ecs.World,
	min_pos: Vec2,
	max_pos: Vec2,
) -> ecs.EntityID {
	position := Position {
		rand.float32_range(min_pos.x, max_pos.x),
		rand.float32_range(min_pos.y, max_pos.y),
	}

	return ecs.add_entity(
		world,
		position,
		PlantSpawner{spawnChance = 0.002, min_nutrition = 5, max_nutrition = 100, radius = 100},
	)
}
