@tool
extends Node3D

@export_range(3, 64, 1)
var radial_count: int = 16:
	set(value):
		radial_count = max(value, 3)
		_queue_regenerate()

@export_range(2, 32, 1)
var ring_count: int = 8:
	set(value):
		ring_count = max(value, 2)
		_queue_regenerate()

@export_range(0.5, 128.0, 0.1)
var web_radius: float = 4.0:
	set(value):
		web_radius = max(value, 0.5)
		_queue_regenerate()

@export_range(0.0, 1.5, 0.01)
var radial_jitter: float = 0.25:
	set(value):
		radial_jitter = clamp(value, 0.0, 1.5)
		_queue_regenerate()

@export_range(0.0, 0.9, 0.01)
var ring_radius_variation: float = 0.35:
	set(value):
		ring_radius_variation = clamp(value, 0.0, 0.9)
		_queue_regenerate()

@export_range(0.005, 0.5, 0.005)
var strand_radius: float = 0.03:
	set(value):
		strand_radius = clamp(value, 0.005, 0.5)
		_queue_regenerate()

@export_range(3, 64, 1)
var strand_sides: int = 12:
	set(value):
		strand_sides = clamp(value, 3, 64)
		_queue_regenerate()

@export var add_junction_spheres: bool = true:
	set(value):
		add_junction_spheres = value
		_queue_regenerate()

@export_range(0.75, 2.0, 0.05)
var junction_sphere_scale: float = 1.0:
	set(value):
		junction_sphere_scale = clamp(value, 0.75, 2.0)
		_queue_regenerate()

@export_range(4, 32, 1)
var junction_sphere_lats: int = 8:
	set(value):
		junction_sphere_lats = clamp(value, 4, 32)
		_queue_regenerate()

@export_range(8, 96, 1)
var junction_sphere_lons: int = 16:
	set(value):
		junction_sphere_lons = clamp(value, 8, 96)
		_queue_regenerate()

@export var web_material: StandardMaterial3D:
	set(value):
		web_material = value
		_queue_regenerate()

@export var use_seed: bool = false:
	set(value):
		use_seed = value
		_queue_regenerate(true)

@export var seed: int = 0:
	set(value):
		seed = value
		if use_seed:
			_queue_regenerate(true)

@export var regenerate: bool = false:
	set(value):
		regenerate = false
		_queue_regenerate(true)

var _web_mesh_instance: MeshInstance3D
var _web_collision_body: StaticBody3D
var _default_material: StandardMaterial3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_regenerate: bool = false

func _ready() -> void:
	# Only generate mesh in editor, not in game
	if Engine.is_editor_hint():
		call_deferred("_generate_web")

func _queue_regenerate(force_seed := false) -> void:
	if Engine.is_editor_hint():
		if force_seed and use_seed:
			_rng.seed = seed
		if not _pending_regenerate:
			_pending_regenerate = true
			call_deferred("_generate_web")

func _generate_web() -> void:
	if get_child(1) != null:
		return 
	_pending_regenerate = false
	if not is_inside_tree():
		return

	# Only generate in editor
	if not Engine.is_editor_hint():
		return

	if use_seed:
		_rng.seed = seed
	else:
		_rng.randomize()

	# Remove existing mesh and collision
	if _web_mesh_instance and is_instance_valid(_web_mesh_instance):
		_web_mesh_instance.queue_free()
	if _web_collision_body and is_instance_valid(_web_collision_body):
		_web_collision_body.queue_free()

	# Create mesh
	var web_mesh := _build_web_mesh()
	
	_web_mesh_instance = MeshInstance3D.new()
	_web_mesh_instance.name = "SpiderWeb"
	_web_mesh_instance.mesh = web_mesh
	var material := web_material if web_material else _get_default_material()
	if material:
		_web_mesh_instance.material_override = material

	add_child(_web_mesh_instance, false)
	
	# Create StaticBody3D with CollisionShape3D
	_web_collision_body = StaticBody3D.new()
	_web_collision_body.name = "SpiderWebCollision"
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var trimesh_shape := mesh_to_trimesh_shape(web_mesh)
	collision_shape.shape = trimesh_shape
	
	_web_collision_body.add_child(collision_shape, false)
	add_child(_web_collision_body, false)
	
	var root := get_tree().edited_scene_root
	if root:
		_web_mesh_instance.owner = root
		_web_collision_body.owner = root
		collision_shape.owner = root

func _build_web_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var radial_angles: Array[float] = []
	radial_angles.resize(radial_count)
	for i in radial_angles.size():
		var base_angle := TAU * float(i) / float(radial_count)
		var jitter := radial_jitter * _rng.randf_range(-1.0, 1.0)
		radial_angles[i] = base_angle + jitter

	var ring_points: Array[Array] = []
	ring_points.resize(ring_count)

	for ring_index in range(ring_count):
		var base_radius := web_radius * float(ring_index + 1) / float(ring_count)
		var points_for_ring: Array[Vector3] = []
		points_for_ring.resize(radial_count)
		for radial_index in range(radial_count):
			var radius_variation := base_radius * ring_radius_variation * _rng.randf_range(-1.0, 1.0)
			var radius := base_radius + radius_variation
			radius = max(radius, 0.05)
			var angle := radial_angles[radial_index]
			var point := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			points_for_ring[radial_index] = point
		ring_points[ring_index] = points_for_ring

	var node_positions: Array[Vector3] = []
	node_positions.append(Vector3.ZERO)
	for ring_index in range(ring_count):
		var points_for_ring: Array[Vector3] = ring_points[ring_index]
		for radial_index in range(radial_count):
			node_positions.append(points_for_ring[radial_index])

	for radial_index in range(radial_count):
		var previous_point := Vector3.ZERO
		for ring_index in range(ring_count):
			var current_point: Vector3 = ring_points[ring_index][radial_index]
			_add_tube_segment(st, previous_point, current_point, strand_radius, strand_sides)
			previous_point = current_point

	for ring_index in range(ring_count):
		var points_for_ring: Array[Vector3] = ring_points[ring_index]
		for radial_index in range(radial_count):
			var start_point: Vector3 = points_for_ring[radial_index]
			var end_point: Vector3 = points_for_ring[(radial_index + 1) % radial_count]
			_add_tube_segment(st, start_point, end_point, strand_radius, strand_sides)

	if add_junction_spheres:
		var r := strand_radius * junction_sphere_scale
		for p in node_positions:
			_add_uv_sphere(st, p, r, junction_sphere_lats, junction_sphere_lons)

	return st.commit()

func _get_default_material() -> StandardMaterial3D:
	if _default_material:
		return _default_material

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 1.0, 0.8)
	material.flags_unshaded = false
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.2
	_default_material = material
	return _default_material

# Builds a cylindrical tube segment between start and end with smooth normals.
func _add_tube_segment(st: SurfaceTool, start: Vector3, end: Vector3, radius: float, sides: int) -> void:
	var axis: Vector3 = end - start
	var length := axis.length()
	if length < 0.0001:
		return
	var tangent: Vector3 = axis / length

	var arbitrary := Vector3.UP
	if abs(tangent.dot(arbitrary)) > 0.95:
		arbitrary = Vector3.FORWARD

	var normal0 := tangent.cross(arbitrary).normalized()
	var binormal0 := tangent.cross(normal0).normalized()

	var ring_dirs: Array[Vector3] = []
	ring_dirs.resize(sides)
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		ring_dirs[i] = (normal0 * cos(a) + binormal0 * sin(a)).normalized()

	for i in range(sides):
		var i_next := (i + 1) % sides
		var dir_i: Vector3 = ring_dirs[i]
		var dir_n: Vector3 = ring_dirs[i_next]

		var v0 := start + dir_i * radius
		var v1 := end + dir_i * radius
		var v2 := end + dir_n * radius
		var v3 := start + dir_n * radius

		st.set_normal(dir_i)
		st.add_vertex(v0)
		st.set_normal(dir_i)
		st.add_vertex(v1)
		st.set_normal(dir_n)
		st.add_vertex(v2)

		st.set_normal(dir_i)
		st.add_vertex(v0)
		st.set_normal(dir_n)
		st.add_vertex(v2)
		st.set_normal(dir_n)
		st.add_vertex(v3)

# Adds a UV sphere at center with given radius and segments, with smooth normals.
func _add_uv_sphere(st: SurfaceTool, center: Vector3, radius: float, lats: int, lons: int) -> void:
	var lat_count: int = max(lats, 2)
	var lon_count: int = max(lons, 3)

	for lat in range(lat_count):
		var theta1 := PI * float(lat) / float(lat_count)
		var theta2 := PI * float(lat + 1) / float(lat_count)

		var y1 := cos(theta1)
		var r1 := sin(theta1)
		var y2 := cos(theta2)
		var r2 := sin(theta2)

		for lon in range(lon_count):
			var phi1 := TAU * float(lon) / float(lon_count)
			var phi2 := TAU * float((lon + 1) % lon_count) / float(lon_count)

			var nA := Vector3(r1 * cos(phi1), y1, r1 * sin(phi1))
			var nB := Vector3(r2 * cos(phi1), y2, r2 * sin(phi1))
			var nC := Vector3(r2 * cos(phi2), y2, r2 * sin(phi2))
			var nD := Vector3(r1 * cos(phi2), y1, r1 * sin(phi2))

			var vA := center + nA * radius
			var vB := center + nB * radius
			var vC := center + nC * radius
			var vD := center + nD * radius

			st.set_normal(nA)
			st.add_vertex(vA)
			st.set_normal(nB)
			st.add_vertex(vB)
			st.set_normal(nC)
			st.add_vertex(vC)

			st.set_normal(nA)
			st.add_vertex(vA)
			st.set_normal(nC)
			st.add_vertex(vC)
			st.set_normal(nD)
			st.add_vertex(vD)

# Converts an ArrayMesh to a ConcavePolygonShape3D for collision
func mesh_to_trimesh_shape(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	
	for surface_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_idx)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		
		if vertices.is_empty():
			continue
		
		# Check if indices exist, if not generate triangles from vertex order
		var indices: PackedInt32Array
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		
		if not indices.is_empty():
			# Use indexed triangles
			for i in range(0, indices.size(), 3):
				if i + 2 < indices.size():
					var idx0 := indices[i]
					var idx1 := indices[i + 1]
					var idx2 := indices[i + 2]
					if idx0 < vertices.size() and idx1 < vertices.size() and idx2 < vertices.size():
						faces.append(vertices[idx0])
						faces.append(vertices[idx1])
						faces.append(vertices[idx2])
		else:
			# No indices - assume vertices are in triangle order (3 vertices per triangle)
			for i in range(0, vertices.size(), 3):
				if i + 2 < vertices.size():
					faces.append(vertices[i])
					faces.append(vertices[i + 1])
					faces.append(vertices[i + 2])
	
	if faces.is_empty():
		# Fallback: create a simple shape if no faces were extracted
		push_warning("SpiderWebGenerator: Could not generate collision shape from mesh")
		return shape
	
	shape.set_faces(faces)
	return shape
