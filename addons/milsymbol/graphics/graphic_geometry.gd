extends RefCounted
## Geometry helpers for MilGraphic: polylines, offsets, decorations, label placement, hatching.
## Plane coordinates: x right, y down (screen). "Left" of a direction d is (d.y, -d.x).


static func left_normal(direction: Vector2) -> Vector2:
	return Vector2(direction.y, -direction.x)


static func length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Point at `distance` along the polyline and the index of the segment it lies on.
static func point_at(points: PackedVector2Array, distance: float) -> Dictionary:
	var travelled := 0.0
	for i in range(1, points.size()):
		var segment := points[i - 1].distance_to(points[i])
		if travelled + segment >= distance or i == points.size() - 1:
			var t := clampf((distance - travelled) / segment, 0.0, 1.0) if segment > 0.0 else 0.0
			return {"point": points[i - 1].lerp(points[i], t), "segment": i - 1}
		travelled += segment
	return {"point": points[0] if not points.is_empty() else Vector2.ZERO, "segment": 0}


static func bounds_center(points: PackedVector2Array) -> Vector2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box.get_center()


## Twice the signed area; positive when the polygon runs clockwise on screen (y down).
static func signed_area2(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return area


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if result.size() > 1 and not result[0].is_equal_approx(result[result.size() - 1]):
		result.append(result[0])
	return result


## Removes consecutive duplicate points (they have no direction).
static func clean(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		if result.is_empty() or result[result.size() - 1].distance_to(p) > 0.001:
			result.append(p)
	return result


## Parallel polyline at `distance` to the left (negative: right), with mitred joins (limited to 4x).
static func offset(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := points.size()
	for i in n:
		var normal: Vector2
		if i == 0:
			normal = left_normal((points[1] - points[0]).normalized())
		elif i == n - 1:
			normal = left_normal((points[i] - points[i - 1]).normalized())
		else:
			var n1 := left_normal((points[i] - points[i - 1]).normalized())
			var n2 := left_normal((points[i + 1] - points[i]).normalized())
			var miter := (n1 + n2).normalized()
			var scale := 1.0 / maxf(miter.dot(n1), 0.25)
			normal = miter * scale
		result.append(points[i] + normal * distance)
	return result


## Polyline with a row of triangles on one side: teeth of `base` width and `height`, one per `period`.
## `side` is 1 for the left of the travel direction, -1 for the right.
static func teeth(points: PackedVector2Array, period: float, base: float, height: float, side: float,
		closed_shape: bool = false) -> PackedVector2Array:
	var path := closed(points) if closed_shape else points
	var result := PackedVector2Array([path[0]])
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var segment := a.distance_to(b)
		var count := floori(segment / period)
		if count > 0:
			var direction := (b - a) / segment
			var normal := left_normal(direction) * side
			var step := segment / count
			var half := minf(base, step * 0.8) / 2.0
			for k in count:
				var middle := a + direction * step * (k + 0.5)
				result.append(middle - direction * half)
				result.append(middle + normal * height)
				result.append(middle + direction * half)
		result.append(b)
	return result


## Polyline drawn as semicircles bulging to the left of the travel direction (FLOT).
static func scallops(points: PackedVector2Array, cell: float, steps: int = 10) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var segment := a.distance_to(b)
		var count := floori(segment / cell)
		if count == 0:
			result.append(b)
			continue
		var direction := (b - a) / segment
		var normal := left_normal(direction)
		var size := segment / count
		var radius := size / 2.0
		for k in count:
			var center := a + direction * size * (k + 0.5)
			for s in range(1, steps + 1):
				var angle := PI * s / steps
				result.append(center - direction * radius * cos(angle) + normal * radius * sin(angle))
	return result


## Open "V" arrowhead at `tip` pointing along `direction`.
static func arrowhead(tip: Vector2, direction: Vector2, head_length: float, half_width: float) -> PackedVector2Array:
	var back := tip - direction * head_length
	var normal := left_normal(direction)
	return PackedVector2Array([back + normal * half_width, tip, back - normal * half_width])


## Small cross ("X") marks along a polyline, one per `period`.
static func crosses(points: PackedVector2Array, period: float, size: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var total := length(points)
	var count := floori(total / period)
	for k in count:
		var p: Vector2 = point_at(points, period * (k + 0.5)).point
		var d := Vector2(size, size) / 2.0
		result.append(PackedVector2Array([p - d, p + d]))
		result.append(PackedVector2Array([p + Vector2(-d.x, d.y), p + Vector2(d.x, -d.y)]))
	return result


## Hatch lines ("/" on screen) clipped to a polygon, `spacing` apart.
static func hatch(polygon: PackedVector2Array, spacing: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var ring := polygon.duplicate()
	if ring.size() > 1 and ring[0].is_equal_approx(ring[ring.size() - 1]):
		ring.remove_at(ring.size() - 1)
	if ring.size() < 3 or spacing <= 0.0:
		return result
	# Lines x + y = c run from bottom-left to top-right.
	var lo := INF
	var hi := -INF
	for p in ring:
		lo = minf(lo, p.x + p.y)
		hi = maxf(hi, p.x + p.y)
	var step := spacing * sqrt(2.0)
	var c := ceilf(lo / step) * step
	while c < hi:
		var xs: Array[float] = []
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			var sa := a.x + a.y
			var sb := b.x + b.y
			if (sa <= c and c < sb) or (sb <= c and c < sa):
				var t := (c - sa) / (sb - sa)
				xs.append(lerpf(a.x, b.x, t))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			result.append(PackedVector2Array([Vector2(xs[k], c - xs[k]), Vector2(xs[k + 1], c - xs[k + 1])]))
		c += step
	return result


## Angle of a direction, turned so that text along it reads left to right.
static func upright(angle: float) -> float:
	angle = wrapf(angle, -PI, PI)
	if angle > PI / 2.0 + 0.0001:
		angle -= PI
	elif angle <= -PI / 2.0 - 0.0001:
		angle += PI
	return angle


## Unit vector pointing "up" for text drawn at `angle`.
static func text_up(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


static func circle(center: Vector2, radius: float, steps: int = 48) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		result.append(center + Vector2(cos(a), sin(a)) * radius)
	return result
