package main

import "core:math"
import "core:math/linalg"

ColShapePoint :: struct {
	offset: Vec2,
}

ColShapePointPos :: struct {
	using shape_point: ColShapePoint,
	position:          Vec2,
}

ColShapeLine :: struct {
	start: Vec2,
	end:   Vec2,
}

ColShapeLinePos :: struct {
	using line: ColShapeLine,
	position:   Vec2,
}

ColShapeRect :: struct {
	using shape_point: ColShapePoint,
	dimensions:        Vec2,
}

ColShapeRectPos :: struct {
	using rect: ColShapeRect,
	position:   Vec2,
}

ColShapeRotatedRect :: struct {
	using rect: ColShapeRect,
	rotation:   f32,
}

ColShapeRotatedRectPos :: struct {
	using rotated_rect: ColShapeRotatedRect,
	position:           Vec2,
}

ColShapeCircle :: struct {
	using shape_point: ColShapePoint,
	radius:            f32,
}

ColShapeCirclePos :: struct {
	using circle: ColShapeCircle,
	position:     Vec2,
}


ColShape :: union {
	ColShapeLine,
	ColShapeRect,
	ColShapeRotatedRect,
	ColShapeCircle,
	ColShapePoint,
}

ColShapePos :: union {
	ColShapeLinePos,
	ColShapeRectPos,
	ColShapeRotatedRectPos,
	ColShapeCirclePos,
	ColShapePointPos,
}

shapes_intersect :: proc {
	shapes_intersect_line_line,
	shapes_intersect_line_point,
	shapes_intersect_line_circle,
	shapes_intersect_line_rect,
	shapes_intersect_line_rotated_rect,
	shapes_intersect_point_line,
	shapes_intersect_circle_line,
	shapes_intersect_rect_line,
	shapes_intersect_rotated_rect_line,
	shapes_intersect_circle_circle,
	shapes_intersect_circle_point,
	shapes_intersect_circle_rect,
	shapes_intersect_circle_rotated_rect,
	shapes_intersect_rect_circle,
	shapes_intersect_rect_rect,
	shapes_intersect_rect_rotated_rect,
	shapes_intersect_point_rect,
	shapes_intersect_point_circle,
	shapes_intersect_point_rotated_rect,
	shapes_intersect_rect_point,
	shapes_intersect_rotated_rect_circle,
	shapes_intersect_rotated_rect_point,
	shapes_intersect_rotated_rect_rect,
	shapes_intersect_rotated_rect_rotated_rect,
}

shapes_intersect_any :: proc(first: ColShapePos, second: ColShapePos) -> bool {
	switch a in first {
	case ColShapeLinePos:
		switch b in second {
		case ColShapeLinePos:
			return shapes_intersect_line_line(a, b)
		case ColShapeRectPos:
			return shapes_intersect_line_rect(a, b)
		case ColShapeRotatedRectPos:
			return shapes_intersect_line_rotated_rect(a, b)
		case ColShapeCirclePos:
			return shapes_intersect_line_circle(a, b)
		case ColShapePointPos:
			return shapes_intersect_line_point(a, b)
		}
	case ColShapeRectPos:
		switch b in second {
		case ColShapeLinePos:
			return shapes_intersect_rect_line(a, b)
		case ColShapeRectPos:
			return shapes_intersect_rect_rect(a, b)
		case ColShapeRotatedRectPos:
			return shapes_intersect_rect_rotated_rect(a, b)
		case ColShapeCirclePos:
			return shapes_intersect_rect_circle(a, b)
		case ColShapePointPos:
			return shapes_intersect_rect_point(a, b)
		}
	case ColShapeRotatedRectPos:
		switch b in second {
		case ColShapeLinePos:
			return shapes_intersect_rotated_rect_line(a, b)
		case ColShapeRectPos:
			return shapes_intersect_rotated_rect_rect(a, b)
		case ColShapeRotatedRectPos:
			return shapes_intersect_rotated_rect_rotated_rect(a, b)
		case ColShapeCirclePos:
			return shapes_intersect_rotated_rect_circle(a, b)
		case ColShapePointPos:
			return shapes_intersect_rotated_rect_point(a, b)
		}
	case ColShapeCirclePos:
		switch b in second {
		case ColShapeLinePos:
			return shapes_intersect_circle_line(a, b)
		case ColShapeRectPos:
			return shapes_intersect_circle_rect(a, b)
		case ColShapeRotatedRectPos:
			return shapes_intersect_circle_rotated_rect(a, b)
		case ColShapeCirclePos:
			return shapes_intersect_circle_circle(a, b)
		case ColShapePointPos:
			return shapes_intersect_circle_point(a, b)
		}
	case ColShapePointPos:
		switch b in second {
		case ColShapeLinePos:
			return shapes_intersect_point_line(a, b)
		case ColShapeRectPos:
			return shapes_intersect_point_rect(a, b)
		case ColShapeRotatedRectPos:
			return shapes_intersect_point_rotated_rect(a, b)
		case ColShapeCirclePos:
			return shapes_intersect_point_circle(a, b)
		case ColShapePointPos:
			return false
		}
	}

	return false
}

shape_with_pos_line :: proc(line: ColShapeLine, position: Vec2) -> ColShapeLinePos {
	return {line = line, position = position}
}

shape_with_pos_rect :: proc(rect: ColShapeRect, position: Vec2) -> ColShapeRectPos {
	return {rect = rect, position = position}
}

shape_with_pos_circle :: proc(circle: ColShapeCircle, position: Vec2) -> ColShapeCirclePos {
	return {circle = circle, position = position}
}

shape_with_pos_point :: proc(point: ColShapePoint, position: Vec2) -> ColShapePointPos {
	return {offset = point.offset, position = position}
}

shape_with_pos_rotated_rect :: proc(
	rect: ColShapeRotatedRect,
	position: Vec2,
	rotation: f32,
) -> ColShapeRotatedRectPos {
	return {
		rotated_rect = {rect = rect.rect, rotation = rect.rotation + rotation},
		position = position,
	}
}

shape_with_pos_any :: proc(shape: ColShape, position: Vec2) -> ColShapePos {
	switch s in shape {
	case ColShapeLine:
		return shape_with_pos_line(s, position)
	case ColShapeRect:
		return shape_with_pos_rect(s, position)
	case ColShapeRotatedRect:
		return shape_with_pos_rotated_rect(s, position, 0)
	case ColShapeCircle:
		return shape_with_pos_circle(s, position)
	case ColShapePoint:
		return shape_with_pos_point(s, position)
	}

	return nil
}

line_points :: proc(line: ColShapeLinePos) -> (start, end: Vec2) {
	return line.position + line.start, line.position + line.end
}

rotated_rect_center :: proc(rect: ColShapeRotatedRectPos) -> Vec2 {
	return rect.position + rect.offset + rect.dimensions / 2
}

rotate_vec2 :: proc(v: Vec2, rotation: f32) -> Vec2 {
	radians := rotation * math.PI / 180
	cos := math.cos_f32(radians)
	sin := math.sin_f32(radians)

	return {v.x * cos - v.y * sin, v.x * sin + v.y * cos}
}

rotated_rect_corners :: proc(rect: ColShapeRotatedRectPos) -> [4]Vec2 {
	center := rotated_rect_center(rect)
	half := rect.dimensions / 2

	return {
		center + rotate_vec2({-half.x, -half.y}, rect.rotation),
		center + rotate_vec2({half.x, -half.y}, rect.rotation),
		center + rotate_vec2({half.x, half.y}, rect.rotation),
		center + rotate_vec2({-half.x, half.y}, rect.rotation),
	}
}

rect_as_rotated_rect :: proc(rect: ColShapeRectPos, rotation: f32 = 0) -> ColShapeRotatedRectPos {
	return {rotated_rect = {rect = rect.rect, rotation = rotation}, position = rect.position}
}

project_corners :: proc(corners: [4]Vec2, axis: Vec2) -> (min, max: f32) {
	min = linalg.dot(corners[0], axis)
	max = min

	for i in 1 ..< 4 {
		projection := linalg.dot(corners[i], axis)
		if projection < min {
			min = projection
		} else if projection > max {
			max = projection
		}
	}

	return
}

projection_overlaps :: proc(first_corners: [4]Vec2, second_corners: [4]Vec2, axis: Vec2) -> bool {
	first_min, first_max := project_corners(first_corners, axis)
	second_min, second_max := project_corners(second_corners, axis)

	return first_max >= second_min && second_max >= first_min
}

point_in_rotated_rect_space :: proc(point: Vec2, rect: ColShapeRotatedRectPos) -> Vec2 {
	return rotate_vec2(point - rotated_rect_center(rect), -rect.rotation)
}

rotated_rect_contains_local_point :: proc(
	local_point: Vec2,
	rect: ColShapeRotatedRectPos,
) -> bool {
	half := rect.dimensions / 2

	return(
		local_point.x >= -half.x &&
		local_point.x <= half.x &&
		local_point.y >= -half.y &&
		local_point.y <= half.y \
	)
}

cross_vec2 :: proc(first, second: Vec2) -> f32 {
	return first.x * second.y - first.y * second.x
}

point_on_line_segment :: proc(point, start, end: Vec2) -> bool {
	EPSILON :: f32(0.000001)
	segment := end - start
	to_point := point - start
	length_squared := linalg.dot(segment, segment)

	if length_squared <= EPSILON * EPSILON {
		return linalg.dot(to_point, to_point) <= EPSILON * EPSILON
	}

	cross := cross_vec2(segment, to_point)
	if cross * cross > EPSILON * EPSILON * length_squared {
		return false
	}

	projection := linalg.dot(to_point, segment) / length_squared
	return projection >= -EPSILON && projection <= 1 + EPSILON
}

line_segments_intersect :: proc(first_start, first_end, second_start, second_end: Vec2) -> bool {
	EPSILON :: f32(0.000001)
	first_direction := first_end - first_start
	second_direction := second_end - second_start
	between_starts := second_start - first_start
	cross_directions := cross_vec2(first_direction, second_direction)
	parallel_threshold_squared :=
		EPSILON * EPSILON * linalg.dot(first_direction, first_direction) *
		linalg.dot(second_direction, second_direction)

	if cross_directions * cross_directions <= parallel_threshold_squared {
		return point_on_line_segment(first_start, second_start, second_end) ||
		       point_on_line_segment(first_end, second_start, second_end) ||
		       point_on_line_segment(second_start, first_start, first_end) ||
		       point_on_line_segment(second_end, first_start, first_end)
	}

	first_distance := cross_vec2(between_starts, second_direction) / cross_directions
	second_distance := cross_vec2(between_starts, first_direction) / cross_directions
	return(
		first_distance >= -EPSILON && first_distance <= 1 + EPSILON &&
		second_distance >= -EPSILON && second_distance <= 1 + EPSILON \
	)
}

line_segment_intersects_rect :: proc(start, end, min, max: Vec2) -> bool {
	if start.x >= min.x && start.x <= max.x && start.y >= min.y && start.y <= max.y {
		return true
	}

	return(
		line_segments_intersect(start, end, min, {max.x, min.y}) ||
		line_segments_intersect(start, end, {max.x, min.y}, max) ||
		line_segments_intersect(start, end, max, {min.x, max.y}) ||
		line_segments_intersect(start, end, {min.x, max.y}, min) \
	)
}

shapes_intersect_line_line :: proc(first: ColShapeLinePos, second: ColShapeLinePos) -> bool {
	first_start, first_end := line_points(first)
	second_start, second_end := line_points(second)
	return line_segments_intersect(first_start, first_end, second_start, second_end)
}

shapes_intersect_line_point :: proc(line: ColShapeLinePos, point: ColShapePointPos) -> bool {
	start, end := line_points(line)
	return point_on_line_segment(point.position + point.offset, start, end)
}

shapes_intersect_point_line :: proc(point: ColShapePointPos, line: ColShapeLinePos) -> bool {
	return shapes_intersect_line_point(line, point)
}

shapes_intersect_line_circle :: proc(line: ColShapeLinePos, circle: ColShapeCirclePos) -> bool {
	start, end := line_points(line)
	center := circle.position + circle.offset
	segment := end - start
	length_squared := linalg.dot(segment, segment)
	closest := start

	if length_squared > 0 {
		distance := math.clamp(linalg.dot(center - start, segment) / length_squared, 0, 1)
		closest = start + segment * distance
	}

	to_center := center - closest
	return linalg.dot(to_center, to_center) <= circle.radius * circle.radius
}

shapes_intersect_circle_line :: proc(circle: ColShapeCirclePos, line: ColShapeLinePos) -> bool {
	return shapes_intersect_line_circle(line, circle)
}

shapes_intersect_line_rect :: proc(line: ColShapeLinePos, rect: ColShapeRectPos) -> bool {
	start, end := line_points(line)
	min := rect.position + rect.offset
	return line_segment_intersects_rect(start, end, min, min + rect.dimensions)
}

shapes_intersect_rect_line :: proc(rect: ColShapeRectPos, line: ColShapeLinePos) -> bool {
	return shapes_intersect_line_rect(line, rect)
}

shapes_intersect_line_rotated_rect :: proc(
	line: ColShapeLinePos,
	rotated_rect: ColShapeRotatedRectPos,
) -> bool {
	start, end := line_points(line)
	local_start := point_in_rotated_rect_space(start, rotated_rect)
	local_end := point_in_rotated_rect_space(end, rotated_rect)
	half := rotated_rect.dimensions / 2
	return line_segment_intersects_rect(local_start, local_end, -half, half)
}

shapes_intersect_rotated_rect_line :: proc(
	rotated_rect: ColShapeRotatedRectPos,
	line: ColShapeLinePos,
) -> bool {
	return shapes_intersect_line_rotated_rect(line, rotated_rect)
}

shapes_intersect_rect_rect :: proc(first: ColShapeRectPos, second: ColShapeRectPos) -> bool {
	p1 := first.position + first.offset
	p2 := second.position + second.offset

	return(
		p1.x + first.dimensions.x >= p2.x &&
		p1.x <= p2.x + second.dimensions.x &&
		p1.y + first.dimensions.y >= p2.y &&
		p1.y <= p2.y + second.dimensions.y \
	)
}

shapes_intersect_point_rect :: proc(point: ColShapePointPos, rect: ColShapeRectPos) -> bool {
	p1 := point.position + point.offset
	p2 := rect.position + rect.offset

	return(
		p1.x >= p2.x &&
		p1.x <= p2.x + rect.dimensions.x &&
		p1.y >= p2.y &&
		p1.y <= p2.y + rect.dimensions.y \
	)
}


shapes_intersect_rect_point :: proc(rect: ColShapeRectPos, point: ColShapePointPos) -> bool {
	return shapes_intersect_point_rect(point, rect)
}

shapes_intersect_point_circle :: proc(point: ColShapePointPos, circle: ColShapeCirclePos) -> bool {
	return(
		linalg.distance(point.offset + point.position, circle.offset + circle.position) <=
		circle.radius \
	)
}

shapes_intersect_circle_point :: proc(circle: ColShapeCirclePos, point: ColShapePointPos) -> bool {
	return shapes_intersect_point_circle(point, circle)
}

shapes_intersect_circle_circle :: proc(
	first: ColShapeCirclePos,
	second: ColShapeCirclePos,
) -> bool {
	return(
		linalg.distance(first.offset + first.position, second.offset + second.position) <=
		first.radius + second.radius \
	)
}

shapes_intersect_circle_rect :: proc(circle: ColShapeCirclePos, rect: ColShapeRectPos) -> bool {
	rp := rect.position + rect.offset
	cp := circle.position + circle.offset

	corner: Vec2 = cp

	if (cp.x < rp.x) {
		corner.x = rp.x
	} else if (cp.x > rp.x + rect.dimensions.x) {
		corner.x = rp.x + rect.dimensions.x
	}

	if (cp.y < rp.y) {
		corner.y = rp.y
	} else if (cp.y > rp.y + rect.dimensions.y) {
		corner.y = rp.y + rect.dimensions.y
	}

	return linalg.distance(corner, cp) <= circle.radius
}

shapes_intersect_rect_circle :: proc(rect: ColShapeRectPos, circle: ColShapeCirclePos) -> bool {
	return shapes_intersect_circle_rect(circle, rect)
}

shapes_intersect_rotated_rect_rotated_rect :: proc(
	first: ColShapeRotatedRectPos,
	second: ColShapeRotatedRectPos,
) -> bool {
	first_corners := rotated_rect_corners(first)
	second_corners := rotated_rect_corners(second)
	first_x_axis := rotate_vec2({1, 0}, first.rotation)
	first_y_axis := rotate_vec2({0, 1}, first.rotation)
	second_x_axis := rotate_vec2({1, 0}, second.rotation)
	second_y_axis := rotate_vec2({0, 1}, second.rotation)

	return(
		projection_overlaps(first_corners, second_corners, first_x_axis) &&
		projection_overlaps(first_corners, second_corners, first_y_axis) &&
		projection_overlaps(first_corners, second_corners, second_x_axis) &&
		projection_overlaps(first_corners, second_corners, second_y_axis) \
	)
}

shapes_intersect_rotated_rect_rect :: proc(
	rotated_rect: ColShapeRotatedRectPos,
	rect: ColShapeRectPos,
) -> bool {
	return shapes_intersect_rotated_rect_rotated_rect(rotated_rect, rect_as_rotated_rect(rect))
}

shapes_intersect_rect_rotated_rect :: proc(
	rect: ColShapeRectPos,
	rotated_rect: ColShapeRotatedRectPos,
) -> bool {
	return shapes_intersect_rotated_rect_rect(rotated_rect, rect)
}

shapes_intersect_point_rotated_rect :: proc(
	point: ColShapePointPos,
	rotated_rect: ColShapeRotatedRectPos,
) -> bool {
	local_point := point_in_rotated_rect_space(point.position + point.offset, rotated_rect)
	return rotated_rect_contains_local_point(local_point, rotated_rect)
}

shapes_intersect_rotated_rect_point :: proc(
	rotated_rect: ColShapeRotatedRectPos,
	point: ColShapePointPos,
) -> bool {
	return shapes_intersect_point_rotated_rect(point, rotated_rect)
}

shapes_intersect_circle_rotated_rect :: proc(
	circle: ColShapeCirclePos,
	rotated_rect: ColShapeRotatedRectPos,
) -> bool {
	local_circle := point_in_rotated_rect_space(circle.position + circle.offset, rotated_rect)
	half := rotated_rect.dimensions / 2
	closest := Vec2 {
		math.clamp(local_circle.x, -half.x, half.x),
		math.clamp(local_circle.y, -half.y, half.y),
	}

	return linalg.distance(local_circle, closest) <= circle.radius
}

shapes_intersect_rotated_rect_circle :: proc(
	rotated_rect: ColShapeRotatedRectPos,
	circle: ColShapeCirclePos,
) -> bool {
	return shapes_intersect_circle_rotated_rect(circle, rotated_rect)
}
