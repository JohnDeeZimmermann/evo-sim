// Package neural provides bounded genetic feed-forward networks. Genomes contain
// only plain fixed-capacity data; runtime latch memory and random state belong
// to callers, so separate creatures can be processed concurrently.
package neural

MAX_INPUT_NODES :: 32
MAX_HIDDEN_NODES :: 32
MAX_OUTPUT_NODES :: 32
MAX_CONNECTIONS :: 128

DEFAULT_MIN_WEIGHT :: f32(-8)
DEFAULT_MAX_WEIGHT :: f32(8)

Node_Role :: enum u8 {
	Input,
	Hidden,
	Output,
}

Node_Ref :: struct {
	role:  Node_Role,
	index: u8,
}

Activation :: enum u8 {
	LIN,
	SIG,
	TANH,
	SQR,
	SIN,
	ABS,
	REL,
	GAU,
	LAT,
}

ACTIVATION_COUNT :: int(Activation.LAT) + 1

Hidden_Node_Gene :: struct {
	activation: Activation,
}

Connection_Gene :: struct {
	source:      Node_Ref,
	destination: Node_Ref,
	weight:      f32,
}

Schema :: struct {
	input_count:  u8,
	output_count: u8,
}

Genes :: struct {
	hidden_count:     u8,
	hidden_nodes:     [MAX_HIDDEN_NODES]Hidden_Node_Gene,
	connection_count: u16,
	connections:      [MAX_CONNECTIONS]Connection_Gene,
}

Runtime_State :: struct {
	latch_on:           [MAX_HIDDEN_NODES]bool,
	latch_was_positive: [MAX_HIDDEN_NODES]bool,
}

Validation_Error :: enum u8 {
	None,
	Invalid_Schema,
	Invalid_Count,
	Invalid_Endpoint,
	Illegal_Direction,
	Duplicate_Edge,
	Non_Finite_Weight,
	Weight_Out_Of_Range,
	Invalid_Activation,
	Cycle,
}

Evaluation_Status :: enum u8 {
	Success,
	Invalid_Dimensions,
	Invalid_Genome,
	Cycle,
}

Mutation_Kind :: enum u8 {
	Change_Weight,
	Remove_Weight,
	Add_Weight,
	Split_Weight,
	Remove_Hidden,
	Change_Function,
}

MUTATION_KIND_COUNT :: 6

Mutation_Status :: enum u8 {
	Applied,
	Skipped_Rate,
	No_Candidate,
	Hidden_Capacity,
	Connection_Capacity,
	Invalid_Argument,
	Invalid_Genome,
}

Mutation_Result :: struct {
	status:                 Mutation_Status,
	attempted_kind:         Mutation_Kind,
	runtime_reset_required: bool,
}

Mutation_Config :: struct {
	operation_weights:  [MUTATION_KIND_COUNT]f32,
	added_weight_min:   f32,
	added_weight_max:   f32,
	allowed_weight_min: f32,
	allowed_weight_max: f32,
}

DEFAULT_MUTATION_CONFIG :: Mutation_Config {
	operation_weights = {1, 1, 1, 1, 1, 1},
	added_weight_min = -1,
	added_weight_max = 1,
	allowed_weight_min = DEFAULT_MIN_WEIGHT,
	allowed_weight_max = DEFAULT_MAX_WEIGHT,
}

Default_Mutation_Config :: proc() -> Mutation_Config {
	return DEFAULT_MUTATION_CONFIG
}

#assert(size_of(Genes) <= 2 * 1024, "neural genes exceed the ECS component budget")
