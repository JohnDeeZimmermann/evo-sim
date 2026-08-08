package main

import "core:math/rand"
import "ecs"
import "neural"

Normalized :: distinct f32
Percentage :: distinct f32

CreatureOutputs :: struct {
	speed:  Percentage, // Percentage of max speed
	rotate: Rotation,
}

CreatureState :: struct {
	energy: f32,
	age:    Percentage,
}

NeuralGenes :: neural.Genes

Creature_Neural_Input :: enum u8 {
	Energy,
	Age,
}

Creature_Neural_Output :: enum u8 {
	Speed,
	Rotation,
}

CREATURE_NEURAL_SCHEMA :: neural.Schema {
	input_count  = 2,
	output_count = 2,
}

Creature_Neural_Inputs :: proc(energy: Normalized, age: Percentage) -> [2]f32 {
	return {f32(percentage(f32(normalized(f32(energy))))), f32(percentage(f32(age)))}
}

CreatureData :: struct {
	base_genes:   BaseGenes,
	neural_genes: NeuralGenes,
	outputs:      CreatureOutputs,
}

BaseGenes :: struct {
	size:                  f32,
	speed:                 f32,
	mutation_rate:         f32,
	mutation_intensity:    f32,
	digestion_preferences: Normalized, // between -1 and 1
	viewing_angles:        f32,
	horn_sizes:            f32,
	horn_angles:           f32,
	bite_strenght:         f32,
	armor:                 f32,
	growth_rate:           f32,
}

normalized :: proc(value: f32) -> Normalized {
	return Normalized(clamp(value, -1, 1))
}

percentage :: proc(value: f32) -> Percentage {
	return Percentage(clamp(value, 0, 1))
}

create_creatures :: proc(world: ^ecs.World) {
	positions := [5]Position{{300, 300}, {650, 450}, {1000, 300}, {500, 800}, {1100, 750}}
	rotations := [5]Rotation{0, 45, 90, 180, 270}
	sizes := [5]f32{24, 32, 20, 28, 36}

	for position, i in positions {
		velocity := Velocity{rand.float32_range(-35, 35), rand.float32_range(-35, 35)}
		size := Size(sizes[i])
		ecs.add_entity(
			world,
			position,
			rotations[i],
			velocity,
			size,
			CreatureData{base_genes = {size = sizes[i]}, neural_genes = {}},
		)
	}
}

#assert(size_of(CreatureData) <= 4 * 1024, "creature data exceeds its component budget")
