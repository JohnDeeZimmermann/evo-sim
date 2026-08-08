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
	ColShapeRect,
	ColShapeRotatedRect,
	ColShapeCircle,
	ColShapePoint,
}

ColShapePos :: union {
	ColShapeRectPos,
	ColShapeRotatedRectPos,
	ColShapeCirclePos,
	ColShapePointPos,
}

shapes_intersect :: proc {
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
	case ColShapeRectPos:
		switch b in second {
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
