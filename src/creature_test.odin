package main

import "core:testing"
import "neural"

@(test)
creature_neural_contract_has_stable_slots_and_plain_zero_genes :: proc(t: ^testing.T) {
	testing.expect(t, int(Creature_Neural_Input.Energy) == 0)
	testing.expect(t, int(Creature_Neural_Input.Age) == 1)
	testing.expect(t, int(Creature_Neural_Output.Speed) == 0)
	testing.expect(t, int(Creature_Neural_Output.Rotation) == 1)
	testing.expect(t, CREATURE_NEURAL_SCHEMA.input_count == 2)
	testing.expect(t, CREATURE_NEURAL_SCHEMA.output_count == 2)

	inputs := Creature_Neural_Inputs(normalized(-1), percentage(2))
	testing.expect(t, inputs == [2]f32{0, 1})

	genes: NeuralGenes
	testing.expect_value(t, neural.Validate(CREATURE_NEURAL_SCHEMA, &genes), neural.Validation_Error.None)
	testing.expect(t, size_of(NeuralGenes) <= 2 * 1024)
	testing.expect(t, size_of(CreatureData) <= 4 * 1024)
}
