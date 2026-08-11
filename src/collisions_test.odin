package main

import "core:testing"

@(test)
line_intersects_line_segments :: proc(t: ^testing.T) {
	horizontal := ColShapeLinePos{line = {start = {0, 1}, end = {2, 1}}}
	crossing := ColShapeLinePos{line = {start = {1, 0}, end = {1, 2}}}
	overlapping := ColShapeLinePos{line = {start = {1, 1}, end = {3, 1}}}
	touching := ColShapeLinePos{line = {start = {2, 1}, end = {3, 2}}}
	disjoint := ColShapeLinePos{line = {start = {3, 1}, end = {4, 1}}}
	parallel := ColShapeLinePos{line = {start = {0, 2}, end = {2, 2}}}
	point_line := ColShapeLinePos{line = {start = {1, 1}, end = {1, 1}}}

	testing.expect(t, shapes_intersect(horizontal, crossing))
	testing.expect(t, shapes_intersect(horizontal, overlapping))
	testing.expect(t, shapes_intersect(horizontal, touching))
	testing.expect(t, !shapes_intersect(horizontal, disjoint))
	testing.expect(t, !shapes_intersect(horizontal, parallel))
	testing.expect(t, shapes_intersect(horizontal, point_line))
}

@(test)
line_intersects_points_and_circles :: proc(t: ^testing.T) {
	line := ColShapeLinePos{line = {start = {0, 0}, end = {4, 0}}, position = {10, 5}}
	point_on_line := ColShapePointPos{position = {12, 5}}
	point_off_line := ColShapePointPos{position = {12, 5.1}}
	tangent_circle := ColShapeCirclePos{circle = {radius = 1}, position = {12, 6}}
	missed_circle := ColShapeCirclePos{circle = {radius = 0.9}, position = {12, 6}}

	testing.expect(t, shapes_intersect(line, point_on_line))
	testing.expect(t, shapes_intersect(point_on_line, line))
	testing.expect(t, !shapes_intersect(line, point_off_line))
	testing.expect(t, shapes_intersect(line, tangent_circle))
	testing.expect(t, shapes_intersect(tangent_circle, line))
	testing.expect(t, !shapes_intersect(line, missed_circle))
}

@(test)
line_intersects_rectangles :: proc(t: ^testing.T) {
	rect := ColShapeRectPos{rect = {offset = {1, 1}, dimensions = {2, 2}}}
	crossing := ColShapeLinePos{line = {start = {0, 2}, end = {4, 2}}}
	contained := ColShapeLinePos{line = {start = {1.25, 1.25}, end = {2.75, 2.75}}}
	edge := ColShapeLinePos{line = {start = {1, 1}, end = {3, 1}}}
	missed := ColShapeLinePos{line = {start = {0, 4}, end = {4, 4}}}
	rotated_rect := ColShapeRotatedRectPos {
		rotated_rect = {rect = {offset = {1, 1}, dimensions = {2, 2}}, rotation = 45},
	}
	rotated_crossing := ColShapeLinePos{line = {start = {0, 2}, end = {4, 2}}}
	rotated_missed := ColShapeLinePos{line = {start = {0, 5}, end = {4, 5}}}

	testing.expect(t, shapes_intersect(crossing, rect))
	testing.expect(t, shapes_intersect(rect, crossing))
	testing.expect(t, shapes_intersect(contained, rect))
	testing.expect(t, shapes_intersect(edge, rect))
	testing.expect(t, !shapes_intersect(missed, rect))
	testing.expect(t, shapes_intersect(rotated_crossing, rotated_rect))
	testing.expect(t, shapes_intersect(rotated_rect, rotated_crossing))
	testing.expect(t, !shapes_intersect(rotated_missed, rotated_rect))
}

@(test)
line_works_with_shape_unions :: proc(t: ^testing.T) {
	line_shape: ColShape = ColShapeLine{start = {0, 0}, end = {3, 0}}
	line := shape_with_pos_any(line_shape, {2, 2})
	circle: ColShapePos = ColShapeCirclePos{circle = {radius = 1}, position = {4, 3}}

	testing.expect(t, shapes_intersect_any(line, circle))
	testing.expect(t, shapes_intersect_any(circle, line))
}
