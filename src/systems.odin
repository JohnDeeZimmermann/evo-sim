package main

import "core:fmt"
import "ecs"

SystemDefinition :: struct {
	run: proc(world: ^ecs.World, dt: f32, result: ^SystemResult) -> (ok: bool),
}

run_systems :: proc(
	systems: []SystemDefinition,
	world: ^ecs.World,
	result: ^SystemResult,
	dt: f32,
) -> (
	ok: bool,
) {
	clear_dynamic_array(result)

	for system, idx in systems {
		if !system.run(world, dt, result) {
			fmt.eprintln("Failed running system: ", idx)
			return false
		}
	}

	system_results_perform(world, result^) or_return
	return true
}
