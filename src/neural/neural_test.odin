package neural

import "core:math"
import "core:math/rand"
import "core:reflect"
import "core:testing"
import "core:thread"

TEST_SCHEMA :: Schema{2, 2}

input_ref :: proc(index: u8) -> Node_Ref {return {.Input, index}}
hidden_ref :: proc(index: u8) -> Node_Ref {return {.Hidden, index}}
output_ref :: proc(index: u8) -> Node_Ref {return {.Output, index}}

expect_near :: proc(t: ^testing.T, actual, expected, tolerance: f32) {
	testing.expectf(
		t,
		abs(actual - expected) <= tolerance,
		"expected %.6f, got %.6f",
		expected,
		actual,
	)
}

forced_config :: proc(kind: Mutation_Kind) -> Mutation_Config {
	config := DEFAULT_MUTATION_CONFIG
	config.operation_weights = {}
	config.operation_weights[int(kind)] = 1
	return config
}

fill_direct_connections :: proc(genes: ^Genes, count: int) {
	for i in 0 ..< count {
		genes.connections[i] = {
			input_ref(u8(i / MAX_OUTPUT_NODES)),
			output_ref(u8(i % MAX_OUTPUT_NODES)),
			1,
		}
	}
	genes.connection_count = u16(count)
}

type_is_plain_value :: proc(info: ^reflect.Type_Info) -> bool {
	base_info := reflect.type_info_base(info)
	#partial switch value in base_info.variant {
	case reflect.Type_Info_String,
	     reflect.Type_Info_Any,
	     reflect.Type_Info_Pointer,
	     reflect.Type_Info_Multi_Pointer,
	     reflect.Type_Info_Procedure,
	     reflect.Type_Info_Dynamic_Array,
	     reflect.Type_Info_Slice,
	     reflect.Type_Info_Map,
	     reflect.Type_Info_Soa_Pointer,
	     reflect.Type_Info_Fixed_Capacity_Dynamic_Array:
		return false
	case reflect.Type_Info_Array:
		return type_is_plain_value(value.elem)
	case reflect.Type_Info_Enumerated_Array:
		return type_is_plain_value(value.elem)
	case reflect.Type_Info_Struct:
		for i in 0 ..< int(value.field_count) {
			if !type_is_plain_value(value.types[i]) {
				return false
			}
		}
	case reflect.Type_Info_Union:
		for variant in value.variants {
			if !type_is_plain_value(variant) {
				return false
			}
		}
	}
	return true
}

@(test)
genes_contain_only_plain_inline_values :: proc(t: ^testing.T) {
	testing.expect(t, type_is_plain_value(type_info_of(Genes)))
}

@(test)
activation_functions_are_finite_and_match_special_points :: proc(t: ^testing.T) {
	expect_near(t, Activate(.LIN, 2), 2, 0)
	expect_near(t, Activate(.SIG, 0), 0.5, 0.00001)
	expect_near(t, Activate(.TANH, 0), 0, 0.00001)
	expect_near(t, Activate(.SQR, -3), 9, 0)
	expect_near(t, Activate(.SIN, 0), 0, 0.00001)
	expect_near(t, Activate(.ABS, -3), 3, 0)
	expect_near(t, Activate(.REL, -1), 0, 0)
	expect_near(t, Activate(.GAU, 0), 1, 0.00001)
	expect_near(t, Activate(.LAT, 1), 0, 0)

	nan := transmute(f32)u32(0x7fc00000)
	positive_infinity := transmute(f32)u32(0x7f800000)
	negative_infinity := transmute(f32)u32(0xff800000)
	values := [7]f32{-100_000, -1, 0, 1, 100_000, nan, positive_infinity}
	activations := [9]Activation{.LIN, .SIG, .TANH, .SQR, .SIN, .ABS, .REL, .GAU, .LAT}
	for activation in activations {
		for value in values {
			testing.expect(t, Is_Finite(Activate(activation, value)))
		}
		testing.expect(t, Is_Finite(Activate(activation, negative_infinity)))
	}
}

@(test)
validation_accepts_dags_and_reports_each_invalid_category :: proc(t: ^testing.T) {
	zero: Genes
	testing.expect_value(t, Validate(TEST_SCHEMA, &zero), Validation_Error.None)

	dag := Genes {
		hidden_count = 3,
		hidden_nodes = {0 = {.LIN}, 1 = {.LAT}, 2 = {.GAU}},
		connection_count = 4,
		connections = {
			0 = {input_ref(0), hidden_ref(0), 1},
			1 = {hidden_ref(0), hidden_ref(1), 1},
			2 = {hidden_ref(1), hidden_ref(2), 1},
			3 = {hidden_ref(2), output_ref(0), 1},
		},
	}
	testing.expect_value(t, Validate(TEST_SCHEMA, &dag), Validation_Error.None)

	testing.expect_value(t, Validate({}, &zero), Validation_Error.Invalid_Schema)

	bad_count := zero
	bad_count.connection_count = MAX_CONNECTIONS + 1
	testing.expect_value(t, Validate(TEST_SCHEMA, &bad_count), Validation_Error.Invalid_Count)

	bad_endpoint := Genes{connection_count = 1, connections = {0 = {input_ref(2), output_ref(0), 1}}}
	testing.expect_value(t, Validate(TEST_SCHEMA, &bad_endpoint), Validation_Error.Invalid_Endpoint)

	illegal := Genes{connection_count = 1, connections = {0 = {output_ref(0), output_ref(1), 1}}}
	testing.expect_value(t, Validate(TEST_SCHEMA, &illegal), Validation_Error.Illegal_Direction)

	duplicate := Genes {
		connection_count = 2,
		connections = {
			0 = {input_ref(0), output_ref(0), 1},
			1 = {input_ref(0), output_ref(0), 2},
		},
	}
	testing.expect_value(t, Validate(TEST_SCHEMA, &duplicate), Validation_Error.Duplicate_Edge)

	nan := transmute(f32)u32(0x7fc00000)
	non_finite := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), nan}}}
	testing.expect_value(t, Validate(TEST_SCHEMA, &non_finite), Validation_Error.Non_Finite_Weight)

	out_of_range := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), 9}}}
	testing.expect_value(t, Validate(TEST_SCHEMA, &out_of_range), Validation_Error.Weight_Out_Of_Range)

	bad_activation := Genes{hidden_count = 1, hidden_nodes = {0 = {Activation(255)}}}
	testing.expect_value(t, Validate(TEST_SCHEMA, &bad_activation), Validation_Error.Invalid_Activation)

	cycle := Genes {
		hidden_count = 2,
		hidden_nodes = {0 = {.LIN}, 1 = {.LAT}},
		connection_count = 2,
		connections = {
			0 = {hidden_ref(0), hidden_ref(1), 1},
			1 = {hidden_ref(1), hidden_ref(0), 1},
		},
	}
	testing.expect_value(t, Validate(TEST_SCHEMA, &cycle), Validation_Error.Cycle)
}

@(test)
evaluator_handles_direct_multilayer_and_fan_in_networks :: proc(t: ^testing.T) {
	evaluator := Default_Evaluator()
	state: Runtime_State
	inputs := [2]f32{2, 3}
	outputs: [2]f32

	direct := Genes {
		connection_count = 3,
		connections = {
			0 = {input_ref(0), output_ref(0), 2},
			1 = {input_ref(1), output_ref(0), -1},
			2 = {input_ref(1), output_ref(1), 0.5},
		},
	}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &direct, &state, inputs[:], outputs[:]), Evaluation_Status.Success)
	expect_near(t, outputs[0], 1, 0.00001)
	expect_near(t, outputs[1], 1.5, 0.00001)

	multilayer := Genes {
		hidden_count = 3,
		hidden_nodes = {0 = {.LIN}, 1 = {.REL}, 2 = {.LIN}},
		connection_count = 6,
		connections = {
			0 = {hidden_ref(2), output_ref(0), 2},
			1 = {input_ref(1), hidden_ref(1), -2},
			2 = {hidden_ref(0), hidden_ref(2), 1},
			3 = {input_ref(0), hidden_ref(0), 3},
			4 = {hidden_ref(1), hidden_ref(2), 7},
			5 = {input_ref(1), hidden_ref(0), 1},
		},
	}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &multilayer, &state, inputs[:], outputs[:]), Evaluation_Status.Success)
	expect_near(t, outputs[0], 18, 0.00001)
	expect_near(t, outputs[1], 0, 0)

	disconnected := Genes{hidden_count = 2, hidden_nodes = {0 = {.SIG}, 1 = {.GAU}}}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &disconnected, &state, inputs[:], outputs[:]), Evaluation_Status.Success)
	testing.expect(t, outputs == [2]f32{})
}

@(test)
evaluator_latch_uses_positive_edges_and_reset :: proc(t: ^testing.T) {
	genes := Genes {
		hidden_count = 1,
		hidden_nodes = {0 = {.LAT}},
		connection_count = 2,
		connections = {
			0 = {input_ref(0), hidden_ref(0), 1},
			1 = {hidden_ref(0), output_ref(0), 1},
		},
	}
	evaluator := Default_Evaluator()
	state: Runtime_State
	outputs: [2]f32

	sequence := [6]f32{1, 1, 0, 1, -1, 1}
	expected := [6]f32{1, 1, 1, 0, 0, 1}
	for input, i in sequence {
		inputs := [2]f32{input, 0}
		testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &genes, &state, inputs[:], outputs[:]), Evaluation_Status.Success)
		expect_near(t, outputs[0], expected[i], 0)
	}

	evaluator.reset(&state)
	testing.expect(t, state == Runtime_State{})
	inputs := [2]f32{1, 0}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &genes, &state, inputs[:], outputs[:]), Evaluation_Status.Success)
	expect_near(t, outputs[0], 1, 0)
}

@(test)
evaluator_rejects_bad_inputs_without_mutating_genes_or_cyclic_latches :: proc(t: ^testing.T) {
	evaluator := Default_Evaluator()
	state: Runtime_State
	outputs := [2]f32{9, 9}
	inputs := [2]f32{1, 1}
	genes := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), 1}}}
	before := genes

	short_inputs := [1]f32{1}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &genes, &state, short_inputs[:], outputs[:]), Evaluation_Status.Invalid_Dimensions)
	testing.expect(t, genes == before)

	invalid := Genes{connection_count = 1, connections = {0 = {output_ref(0), output_ref(1), 1}}}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &invalid, &state, inputs[:], outputs[:]), Evaluation_Status.Invalid_Genome)
	testing.expect(t, outputs == [2]f32{})

	cycle := Genes {
		hidden_count = 2,
		hidden_nodes = {0 = {.LAT}, 1 = {.LIN}},
		connection_count = 2,
		connections = {
			0 = {hidden_ref(0), hidden_ref(1), 1},
			1 = {hidden_ref(1), hidden_ref(0), 1},
		},
	}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &cycle, &state, inputs[:], outputs[:]), Evaluation_Status.Cycle)
	testing.expect(t, state == Runtime_State{})

	nan := transmute(f32)u32(0x7fc00000)
	extreme := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), 8}}}
	extreme_inputs := [2]f32{nan, 0}
	testing.expect_value(t, evaluator.evaluate(TEST_SCHEMA, &extreme, &state, extreme_inputs[:], outputs[:]), Evaluation_Status.Success)
	testing.expect(t, outputs[0] == 0 && Is_Finite(outputs[0]))
}

@(test)
exact_weight_mutations_are_atomic_and_bounded :: proc(t: ^testing.T) {
	genes := Genes {
		connection_count = 2,
		connections = {
			0 = {input_ref(0), output_ref(0), 1},
			1 = {input_ref(1), output_ref(1), -1},
		},
	}
	result := Change_Weight(TEST_SCHEMA, &genes, 0, 100)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	testing.expect(t, result.runtime_reset_required)
	expect_near(t, genes.connections[0].weight, 8, 0)
	testing.expect_value(t, Validate(TEST_SCHEMA, &genes), Validation_Error.None)

	before := genes
	result = Change_Weight(TEST_SCHEMA, &genes, 99, 1)
	testing.expect_value(t, result.status, Mutation_Status.Invalid_Argument)
	testing.expect(t, genes == before && !result.runtime_reset_required)

	result = Remove_Weight(TEST_SCHEMA, &genes, 0)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	testing.expect(t, genes.connection_count == 1)
	testing.expect(t, genes.connections[0].source == input_ref(1))
	testing.expect(t, genes.connections[1] == Connection_Gene{})
	testing.expect_value(t, Validate(TEST_SCHEMA, &genes), Validation_Error.None)
}

@(test)
add_and_split_weight_enforce_legality_and_capacity_atomically :: proc(t: ^testing.T) {
	genes := Genes{hidden_count = 2, hidden_nodes = {0 = {.LIN}, 1 = {.LIN}}}
	result := Add_Weight(TEST_SCHEMA, &genes, input_ref(0), hidden_ref(0), 0.25)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	result = Add_Weight(TEST_SCHEMA, &genes, hidden_ref(0), hidden_ref(1), 0.5)
	testing.expect_value(t, result.status, Mutation_Status.Applied)

	before := genes
	result = Add_Weight(TEST_SCHEMA, &genes, hidden_ref(1), hidden_ref(0), 1)
	testing.expect_value(t, result.status, Mutation_Status.Invalid_Argument)
	testing.expect(t, genes == before)
	result = Add_Weight(TEST_SCHEMA, &genes, input_ref(0), hidden_ref(0), 1)
	testing.expect_value(t, result.status, Mutation_Status.Invalid_Argument)
	testing.expect(t, genes == before)

	split := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), 3}}}
	result = Split_Weight(TEST_SCHEMA, &split, 0)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	testing.expect(t, split.hidden_count == 1 && split.connection_count == 2)
	testing.expect(t, split.hidden_nodes[0].activation == .LIN)
	testing.expect(t, split.connections[0] == Connection_Gene{hidden_ref(0), output_ref(0), 3})
	testing.expect(t, split.connections[1] == Connection_Gene{input_ref(0), hidden_ref(0), 1})
	testing.expect_value(t, Validate(TEST_SCHEMA, &split), Validation_Error.None)

	hidden_full := Genes{hidden_count = MAX_HIDDEN_NODES, connection_count = 1}
	for &node in hidden_full.hidden_nodes {
		node.activation = .LIN
	}
	hidden_full.connections[0] = {input_ref(0), output_ref(0), 1}
	before_full := hidden_full
	result = Split_Weight(TEST_SCHEMA, &hidden_full, 0)
	testing.expect_value(t, result.status, Mutation_Status.Hidden_Capacity)
	testing.expect(t, hidden_full == before_full)

	connection_full: Genes
	full_schema := Schema{MAX_INPUT_NODES, MAX_OUTPUT_NODES}
	fill_direct_connections(&connection_full, MAX_CONNECTIONS)
	before_full = connection_full
	result = Split_Weight(full_schema, &connection_full, 0)
	testing.expect_value(t, result.status, Mutation_Status.Connection_Capacity)
	testing.expect(t, connection_full == before_full)
}

@(test)
remove_hidden_deletes_incident_edges_and_repairs_moved_index :: proc(t: ^testing.T) {
	genes := Genes {
		hidden_count = 3,
		hidden_nodes = {0 = {.SIG}, 1 = {.REL}, 2 = {.GAU}},
		connection_count = 5,
		connections = {
			0 = {input_ref(0), hidden_ref(0), 1},
			1 = {hidden_ref(0), output_ref(0), 1},
			2 = {input_ref(0), hidden_ref(2), 2},
			3 = {hidden_ref(2), output_ref(1), 3},
			4 = {input_ref(1), hidden_ref(1), 4},
		},
	}
	result := Remove_Hidden(TEST_SCHEMA, &genes, 0)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	testing.expect(t, genes.hidden_count == 2 && genes.connection_count == 3)
	testing.expect(t, genes.hidden_nodes[0].activation == .GAU)
	testing.expect(t, genes.hidden_nodes[2] == Hidden_Node_Gene{})
	testing.expect(t, genes.connections[0] == Connection_Gene{input_ref(0), hidden_ref(0), 2})
	testing.expect(t, genes.connections[1] == Connection_Gene{hidden_ref(0), output_ref(1), 3})
	testing.expect(t, genes.connections[2] == Connection_Gene{input_ref(1), hidden_ref(1), 4})
	testing.expect_value(t, Validate(TEST_SCHEMA, &genes), Validation_Error.None)

	result = Change_Function(TEST_SCHEMA, &genes, 0, .LAT)
	testing.expect_value(t, result.status, Mutation_Status.Applied)
	testing.expect(t, genes.hidden_nodes[0].activation == .LAT)
	before := genes
	result = Change_Function(TEST_SCHEMA, &genes, 0, .LAT)
	testing.expect_value(t, result.status, Mutation_Status.No_Candidate)
	testing.expect(t, genes == before && !result.runtime_reset_required)
}

@(test)
seeded_mutation_obeys_rate_kind_and_no_substitution :: proc(t: ^testing.T) {
	genes := Genes{connection_count = 1, connections = {0 = {input_ref(0), output_ref(0), 1}}}
	state := rand.create(u64(100))
	generator := rand.default_random_generator(&state)
	before := genes
	result := Mutate(TEST_SCHEMA, &genes, generator, 0, 1)
	testing.expect_value(t, result.status, Mutation_Status.Skipped_Rate)
	testing.expect(t, genes == before)

	state_a := rand.create(u64(42))
	state_b := rand.create(u64(42))
	genes_a, genes_b := genes, genes
	result_a := Mutate(TEST_SCHEMA, &genes_a, rand.default_random_generator(&state_a), 1, 0.5, forced_config(.Change_Weight))
	result_b := Mutate(TEST_SCHEMA, &genes_b, rand.default_random_generator(&state_b), 1, 0.5, forced_config(.Change_Weight))
	testing.expect(t, result_a == result_b && genes_a == genes_b)
	testing.expect_value(t, result_a.attempted_kind, Mutation_Kind.Change_Weight)

	zero_intensity := genes
	state = rand.create(u64(99))
	result = Mutate(
		TEST_SCHEMA,
		&zero_intensity,
		rand.default_random_generator(&state),
		1,
		0,
		forced_config(.Change_Weight),
	)
	testing.expect_value(t, result.status, Mutation_Status.No_Candidate)
	testing.expect(t, zero_intensity == genes && !result.runtime_reset_required)

	empty: Genes
	state = rand.create(u64(7))
	result = Mutate(TEST_SCHEMA, &empty, rand.default_random_generator(&state), 1, 1, forced_config(.Remove_Weight))
	testing.expect_value(t, result.status, Mutation_Status.No_Candidate)
	testing.expect_value(t, result.attempted_kind, Mutation_Kind.Remove_Weight)
	testing.expect(t, empty == Genes{})

	forced_kinds := [5]Mutation_Kind{.Remove_Weight, .Add_Weight, .Split_Weight, .Remove_Hidden, .Change_Function}
	for kind, i in forced_kinds {
		candidate := Genes {
			hidden_count = 1,
			hidden_nodes = {0 = {.LIN}},
			connection_count = 1,
			connections = {0 = {input_ref(0), output_ref(0), 1}},
		}
		state = rand.create(u64(1000 + i))
		result = Mutate(TEST_SCHEMA, &candidate, rand.default_random_generator(&state), 1, 1, forced_config(kind))
		testing.expect_value(t, result.attempted_kind, kind)
		testing.expect_value(t, result.status, Mutation_Status.Applied)
		testing.expect(t, result.runtime_reset_required)
		testing.expect_value(t, Validate(TEST_SCHEMA, &candidate), Validation_Error.None)
	}
}

@(test)
custom_weight_bounds_apply_to_every_mutation_primitive :: proc(t: ^testing.T) {
	config := DEFAULT_MUTATION_CONFIG
	config.allowed_weight_min = -10
	config.allowed_weight_max = 10
	config.added_weight_min = -10
	config.added_weight_max = 10

	kinds := [4]Mutation_Kind{.Remove_Weight, .Split_Weight, .Remove_Hidden, .Change_Function}
	for kind, i in kinds {
		genes := Genes {
			hidden_count = 1,
			hidden_nodes = {0 = {.LIN}},
			connection_count = 1,
			connections = {0 = {input_ref(0), hidden_ref(0), 9}},
		}
		if kind == .Remove_Weight || kind == .Split_Weight {
			genes.connections[0].destination = output_ref(0)
		}
		config.operation_weights = {}
		config.operation_weights[int(kind)] = 1
		state := rand.create(u64(400 + i))
		result := Mutate(
			TEST_SCHEMA,
			&genes,
			rand.default_random_generator(&state),
			1,
			1,
			config,
		)
		testing.expect_value(t, result.status, Mutation_Status.Applied)
		testing.expect_value(t, result.attempted_kind, kind)
		testing.expect_value(t, Validate(TEST_SCHEMA, &genes, -10, 10), Validation_Error.None)
	}
}

@(test)
long_seeded_mutation_sequences_preserve_valid_graphs :: proc(t: ^testing.T) {
	for seed in 1 ..= 16 {
		genes: Genes
		state := rand.create(u64(seed))
		generator := rand.default_random_generator(&state)
		for _ in 0 ..< 300 {
			_ = Mutate(TEST_SCHEMA, &genes, generator, 1, 0.75)
			testing.expect_value(t, Validate(TEST_SCHEMA, &genes), Validation_Error.None)
		}
	}
}

Parallel_Work :: struct {
	genes:    Genes,
	state:    Runtime_State,
	outputs:  [2]f32,
	mutation: Mutation_Result,
	seed:     u64,
}

run_parallel_work :: proc(work: ^Parallel_Work) {
	inputs := [2]f32{0.75, 0.25}
	evaluator := Default_Evaluator()
	_ = evaluator.evaluate(TEST_SCHEMA, &work.genes, &work.state, inputs[:], work.outputs[:])
	random_state := rand.create(work.seed)
	work.mutation = Mutate(
		TEST_SCHEMA,
		&work.genes,
		rand.default_random_generator(&random_state),
		1,
		0.5,
	)
}

parallel_worker :: proc(worker: ^thread.Thread) {
	run_parallel_work((^Parallel_Work)(worker.data))
}

@(test)
independent_creatures_match_between_serial_and_parallel_execution :: proc(t: ^testing.T) {
	when !thread.IS_SUPPORTED {
		return
	}
	serial, parallel: [4]Parallel_Work
	for i in 0 ..< len(serial) {
		work := Parallel_Work {
			genes = {
				hidden_count = 1,
				hidden_nodes = {0 = {.TANH}},
				connection_count = 2,
				connections = {
					0 = {input_ref(0), hidden_ref(0), f32(i + 1)},
					1 = {hidden_ref(0), output_ref(0), 1},
				},
			},
			seed = u64(900 + i),
		}
		serial[i] = work
		parallel[i] = work
		run_parallel_work(&serial[i])
	}

	workers: [len(parallel)]^thread.Thread
	for i in 0 ..< len(parallel) {
		workers[i] = thread.create(parallel_worker)
		workers[i].data = &parallel[i]
		thread.start(workers[i])
	}
	for worker in workers {
		thread.join(worker)
		thread.destroy(worker)
	}

	for i in 0 ..< len(serial) {
		testing.expect(t, serial[i] == parallel[i])
	}
}
