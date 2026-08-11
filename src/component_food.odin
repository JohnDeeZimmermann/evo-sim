package main

import "ecs"
import rl "vendor:raylib"

FoodType :: enum {
	MEAT,
	PLANT,
}

FoodData :: struct {
	nutrition: f32,
	hardness:  f32,
	type:      FoodType,
}

food_create_plant :: proc(world: ^ecs.World, position: Position, nutrition: f32) {
	size := Size(nutrition * 0.25)
	circle := RenderCircle {
		border_width = 0.2,
		border_color = rl.BLACK,
		inner_color  = rl.GREEN,
	}
	food_data := FoodData {
		hardness  = 0.1,
		nutrition = nutrition,
		type      = .PLANT,
	}
	ecs.add_entity(world, food_data, position, size, circle)
}
