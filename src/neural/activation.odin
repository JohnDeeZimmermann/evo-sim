package neural

import "core:math"

Is_Finite :: proc(value: f32) -> bool {
	return !math.is_nan(value) && !math.is_inf(value)
}

Sanitize :: proc(value: f32) -> f32 {
	if !Is_Finite(value) {
		return 0
	}
	return value
}

Is_Activation_Valid :: proc(activation: Activation) -> bool {
	switch activation {
	case .LIN, .SIG, .TANH, .SQR, .SIN, .ABS, .REL, .GAU, .LAT:
		return true
	}
	return false
}

Activate :: proc(activation: Activation, raw_value: f32) -> f32 {
	x := Sanitize(raw_value)
	value: f32

	switch activation {
	case .LIN:
		value = x
	case .SIG:
		if x >= 0 {
			value = 1 / (1 + math.exp(-x))
		} else {
			ex := math.exp(x)
			value = ex / (1 + ex)
		}
	case .TANH:
		value = math.tanh(x)
	case .SQR:
		value = x * x
	case .SIN:
		value = math.sin(x)
	case .ABS:
		value = abs(x)
	case .REL:
		value = max(f32(0), x)
	case .GAU:
		value = math.exp(-(x * x))
	case .LAT:
		// Latches are stateful and are evaluated by the evaluator.
		value = 0
	case:
		value = 0
	}

	return Sanitize(value)
}
