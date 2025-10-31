extends Node3D
class_name SpiderWebGenerator

# Export variables for customization
@export var radius: float = 2.0
@export var radial_threads: int = 8
@export var spiral_rings: int = 5
@export var deformation_amount: float = 0.15
@export var thread_thickness: float = 0.01
@export var color: Color = Color(0.9, 0.9, 0.8, 0.7)
@export var regenerate: bool = false:
  set(value):
    if value:
      generate_spider_web()

# Called when the node enters the scene tree
func _ready():
  generate_spider_web()

func generate_spider_web():
  # Remove existing web if it exists
  for child in get_children():
    if child.name == "SpiderWeb":
      child.queue_free()
  
  # Create mesh instance
  var mesh_instance = MeshInstance3D.new()
  mesh_instance.name = "SpiderWeb"
  add_child(mesh_instance)
  
  # Generate the mesh
  var array_mesh = ArrayMesh.new()
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  
  var vertices := PackedVector3Array()
  var indices := PackedInt32Array()
  
  # Generate radial threads (spokes from center)
  var radial_points = []
  for i in range(radial_threads):
    var angle = (TAU / radial_threads) * i
    var end_point = Vector3(
      cos(angle) * radius,
      0,
      sin(angle) * radius
    )
    
    # Add random deformation to radial points
    end_point += Vector3(
      randf_range(-deformation_amount, deformation_amount),
      randf_range(-deformation_amount * 0.5, deformation_amount * 0.5),
      randf_range(-deformation_amount, deformation_amount)
    )
    radial_points.append(end_point)
  
  # Center point
  var center = Vector3.ZERO
  
  # Generate spiral/ring threads
  var ring_points = []
  for ring in range(1, spiral_rings + 1):
    var ring_radius = (radius / spiral_rings) * ring
    var points_in_ring = []
    
    for thread_idx in range(radial_threads):
      var angle = (TAU / radial_threads) * thread_idx
      var base_point = Vector3(
        cos(angle) * ring_radius,
        0,
        sin(angle) * ring_radius
      )
      
      # Add random deformation
      var point = base_point + Vector3(
        randf_range(-deformation_amount, deformation_amount),
        randf_range(-deformation_amount * 0.5, deformation_amount * 0.5),
        randf_range(-deformation_amount, deformation_amount)
      )
      points_in_ring.append(point)
    
    ring_points.append(points_in_ring)
  
  # Build mesh from radial threads
  for i in range(radial_threads):
    var start_idx = vertices.size()
    vertices.append(center)
    vertices.append(radial_points[i])
    
    # Create a simple line (will use lines primitive)
    # For better visibility, we'll add some thickness by duplicating vertices
    indices.append(start_idx)
    indices.append(start_idx + 1)
  
  # Build mesh from spiral rings
  for ring_idx in range(spiral_rings):
    var ring = ring_points[ring_idx]
    
    # Connect points in ring (circular connections)
    for i in range(radial_threads):
      var current_start = vertices.size()
      var next_idx = (i + 1) % radial_threads
      
      vertices.append(ring[i])
      vertices.append(ring[next_idx])
      
      indices.append(current_start)
      indices.append(current_start + 1)
    
    # Connect ring to center via radial threads
    if ring_idx == 0:
      # Connect first ring points to center
      for i in range(radial_threads):
        var current_start = vertices.size()
        vertices.append(center)
        vertices.append(ring[i])
        indices.append(current_start)
        indices.append(current_start + 1)
    else:
      # Connect current ring to previous ring
      var prev_ring = ring_points[ring_idx - 1]
      for i in range(radial_threads):
        var current_start = vertices.size()
        vertices.append(prev_ring[i])
        vertices.append(ring[i])
        indices.append(current_start)
        indices.append(current_start + 1)
  
  # Set up arrays
  arrays[Mesh.ARRAY_VERTEX] = vertices
  
  # Create surface
  array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
  
  # Assign mesh
  mesh_instance.mesh = array_mesh
  
  # Create material
  var material = StandardMaterial3D.new()
  material.albedo_color = color
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.cull_mode = BaseMaterial3D.CULL_DISABLED
  material.flags_no_depth_test = false
  
  # Add outline effect for thread visibility
  material.albedo_color = color
  material.vertex_color_use_as_albedo = true
  
  mesh_instance.material_override = material
  
  # Generate vertex colors for depth effect
  var vertex_colors := PackedColorArray()
  var vertex_count = vertices.size()
  for i in range(vertex_count):
    var vertex = vertices[i]
    var distance_from_center = vertex.length()
    var color_factor = 1.0 - (distance_from_center / radius) * 0.3
    vertex_colors.append(color * color_factor)
  
  # Recreate arrays with colors
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_COLOR] = vertex_colors
  array_mesh.clear_surfaces()
  array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
  
  print("Spider web generated with ", vertices.size(), " vertices and ", indices.size(), " indices")
