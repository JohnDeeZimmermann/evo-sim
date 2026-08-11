package main

import "ecs"

CreatureIsDead :: struct {
	time_of_death:  Tick,
	decay_ticks:    int,
	will_decay_at:  int,
	nutrition_left: f32,
	armor_left:     f32,
}

creature_kill :: proc(
	world: ^ecs.World,
	creature: ^CreatureData,
	entity: ecs.EntityID,
	tick: Tick,
) {
	ecs.add_component(world, entity, CreatureIsDead{})
}
