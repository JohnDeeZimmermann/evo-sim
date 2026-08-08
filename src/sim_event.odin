package main

import "ecs"

SimEvent :: union {}

SystemResult :: [dynamic]SimEvent

system_results_perform :: proc(world: ^ecs.World, result: SystemResult) -> (ok: bool) {
	for event in result {
		switch _ in event {}
	}

	return true
}
