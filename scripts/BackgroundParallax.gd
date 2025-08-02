extends Node2D

# References to other systems
var game_manager: Node
var obstacle_generator: Node

# Shape generator
var shape_generator: RefCounted

# Background and foreground layers
var parallax_layers: Array[Node2D] = []
var foreground_layer: Node2D

var star_layer: Node2D
var planet_layer: Node2D

# Object pooling system
var object_pool_manager: Node

# Color system - SIMPLIFIED
var background_color: Color = Color.BLACK
var base_object_color: Color = Color.WHITE  # Base color for all debris
var ship_color: Color = Color.WHITE  # Opposite color for ship

# Performance optimization
@export var base_speed: float = 100.0

# Multiple parallax layers with different speeds and depths
var layer_speeds: Array = [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15, 0.1, 0.05]  # 20 layers for extreme density - FIXED: Closest layers move fastest

# Performance optimization
var screen_size: Vector2
var layer_width: float
var world_position: float = 0.0  # Track world movement for infinite generation
var camera: Camera2D  # Reference to the camera for proper viewport coordinates

# Foreground layer management
var foreground_object_count: int = 12  # Increased from 8 - more initial objects
var max_foreground_objects: int = 40  # Increased from 25 - more maximum objects
var foreground_growth_rate: float = 0.25  # Increased from 0.15 - faster growth
var time_elapsed: float = 0.0
var foreground_spawn_timer: float = 0.0  # Timer for individual foreground object spawning
var foreground_spawn_interval: float = 2.0  # Spawn one object every 2 seconds


# Progressive difficulty system
var max_parallax_objects_per_layer: int = 8  # Maximum objects per parallax layer
var parallax_density_growth_time: float = 600.0  # 10 minutes for max density
var speed_increase_time: float = 1800.0  # 30 minutes for max speed
var max_speed_multiplier: float = 2.5  # Maximum speed increase
var initial_base_speed: float = 100.0  # Store initial speed for calculations
var just_reset: bool = false  # Flag to prevent immediate spawning after reset

# Remove old shake variables
# (camera_shake_timer, camera_shake_duration, camera_shake_intensity, camera_shake_frequency, original_layer_positions)
# Add new camera shake variables
var cam_shake_timer: float = 0.0
var cam_shake_duration: float = 0.0
var cam_shake_intensity: float = 0.0
var cam_shake_frequency: float = 0.0
var cam_shake_seed: float = 0.0

# Distant planet and star system
var star_position: Vector2
var planet_radius: float = 400.0
var planet_center: Vector2

# Shadow overlay system
var shadow_overlay: ColorRect
var shadow_active: bool = false
var shadow_intensity: float = 0.0
var shadow_fade_speed: float = 2.0
var shadow_detection_radius: float = 700.0  # Reduced from 800.0 - shadow starts closer to planet
var debug_label: Label  # Debug label to show shadow status

# Physics constants for background objects
const BG_MIN_ROTATION_SPEED: float = 0.1  # Slower minimum for variety
const BG_MAX_ROTATION_SPEED: float = 3.5  # Much faster maximum for dynamic spinning
const BG_DRAG: float = 0.999  # Nearly no drag in space
const BG_COLLISION_DAMPING: float = 0.98  # Nearly perfect elasticity for space collisions



func _ready():
	screen_size = get_viewport().get_visible_rect().size
	layer_width = screen_size.x * 2  # Make layers wider for smoother infinite scrolling
	
	# Get camera reference for proper viewport coordinates
	camera = get_node_or_null("/root/Main/GameWorld/Camera2D")
	if not camera:
		# Try alternative camera paths
		camera = get_node_or_null("/root/Main/Camera2D")
	
	# Get references to other systems
	game_manager = get_node_or_null("/root/GameManager")
	obstacle_generator = get_node_or_null("/root/Main/GameWorld/ObstacleGenerator")
	if not obstacle_generator:
		# Try alternative paths
		obstacle_generator = get_node_or_null("/root/GameManager/ObstacleGenerator")
	

	
	# Store initial base speed for progressive difficulty calculations
	initial_base_speed = base_speed
	
	# Create a black background that covers the entire screen
	create_black_background()
	
	# Create distant planet and star system
	create_distant_planet_and_star()
	
	# Create shadow overlay system
	create_shadow_overlay()
	
	# SIMPLIFIED: Generate initial colors
	generate_new_colors()
	
	# Create foreground blurry layer (moves faster than background, slower than obstacles)
	foreground_layer = Node2D.new()
	foreground_layer.z_index = 0  # Foreground layer (moved closer to camera)
	foreground_layer.name = "ForegroundLayer"
	add_child(foreground_layer)
	
	# Apply blur effect to foreground layer
	apply_blur_to_foreground()
	

	
	# Create parallax background layers
	for i in range(layer_speeds.size()):
		var layer = Node2D.new()
		layer.name = "ParallaxLayer" + str(i)
		layer.position.x = 0
		layer.z_index = -3 - i  # Parallax layers start at -3 and go deeper
		add_child(layer)
		parallax_layers.append(layer)
		
	
	
	# Initialize object pool manager
	object_pool_manager = Node.new()
	object_pool_manager.set_script(load("res://scripts/systems/background/ObjectPoolManager.gd"))
	add_child(object_pool_manager)
	object_pool_manager.initialize_object_pools()
	
	# Initialize shape generator
	shape_generator = load("res://scripts/systems/background/DebrisShapeGenerator.gd").new()
	
	# Colors are set when objects are created, no initial update needed

func create_black_background():
	# Create a black ColorRect that covers the entire screen
	var background_rect = ColorRect.new()
	background_rect.name = "BlackBackground"
	background_rect.color = Color.BLACK
	background_rect.size = screen_size
	background_rect.position = Vector2.ZERO
	background_rect.z_index = -100  # Black background (farthest from camera)
	add_child(background_rect)



# Foreground object color update function removed



func apply_blur_to_foreground():
	# Create a CanvasLayer for the foreground layer (without blur)
	var foreground_canvas = CanvasLayer.new()
	foreground_canvas.name = "ForegroundCanvas"
	foreground_canvas.layer = 10  # High layer to render on top
	add_child(foreground_canvas)
	
	# Remove foreground layer from current parent and add to canvas layer
	if foreground_layer.get_parent():
		foreground_layer.get_parent().remove_child(foreground_layer)
	foreground_canvas.add_child(foreground_layer)
	foreground_layer.position = Vector2.ZERO



func create_random_objects(layer: Node2D, layer_index: int):
	# Much more objects in closer layers, fewer in distant layers
	var object_count = 25 + layer_index * 8  # 25-185 objects per layer for extreme density
	
	for i in range(object_count):
		var object = create_random_object(layer_index)
		object.position = Vector2(
			randf_range(0, screen_size.x),  # Spread across screen width
			randf_range(0, screen_size.y)
		)
		# Add random rotation to objects
		object.rotation = randf_range(-PI, PI)
		layer.add_child(object)

func get_object_from_pool(layer_index: int) -> Node2D:
	return object_pool_manager.get_object_from_pool(layer_index)



func return_object_to_pool(object: Node2D, layer_index: int):
	object_pool_manager.return_object_to_pool(object, layer_index)

func create_random_object(layer_index: int) -> Node2D:
	var object = Area2D.new()  # Use Area2D for collision detection
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	object.add_child(collision_shape)
	
	# Add visual polygon
	var visual_polygon = Polygon2D.new()
	object.add_child(visual_polygon)
	
	# Physics variables
	object.set_meta("velocity", Vector2.ZERO)
	object.set_meta("angular_velocity", 0.0)
	object.set_meta("mass", 1.0)
	object.set_meta("size", Vector2.ZERO)
	object.set_meta("layer_index", layer_index)
	
	# SIMPLIFIED: Use the base object color with layer-based brightness
	var color = base_object_color
	# Calculate brightness based on layer depth (darker for farther layers)
	var brightness_factor = 1.0 - (float(layer_index) / float(layer_speeds.size())) * 0.3
	color.r = clamp(base_object_color.r * brightness_factor, 0.0, 1.0)
	color.g = clamp(base_object_color.g * brightness_factor, 0.0, 1.0)
	color.b = clamp(base_object_color.b * brightness_factor, 0.0, 1.0)
	
	# Create varied shapes - size gets MUCH LARGER for closer layers
	var base_size = 12.0  # Reduced from 20.0 for smaller debris
	var size_multiplier = 1.0 + (1.0 - float(layer_index) / float(layer_speeds.size())) * 1.2  # Reduced from 2.0 for smaller debris
	var max_size = base_size * size_multiplier
	
	# Generate varied shapes for background objects - ALL AVAILABLE SHAPES
	var shape_type = randi() % 30  # 30 different shapes total
	var polygon_points = PackedVector2Array()
	var object_size = Vector2.ZERO
	
	match shape_type:
		0:  # Simple Rectangle
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
		1:  # Simple Triangle
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(0, -half_size.y),
				Vector2(-half_size.x, half_size.y),
				Vector2(half_size.x, half_size.y)
			])
		2:  # Simple Diamond
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(0, -half_size.y),
				Vector2(half_size.x, 0),
				Vector2(0, half_size.y),
				Vector2(-half_size.x, 0)
			])
		3:  # Simple Cross
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			var cross_width = half_size.x * 0.3
			var cross_height = half_size.y * 0.3
			polygon_points = PackedVector2Array([
				# Vertical part
				Vector2(-cross_width, -half_size.y),
				Vector2(cross_width, -half_size.y),
				Vector2(cross_width, -cross_height),
				Vector2(half_size.x, -cross_height),
				Vector2(half_size.x, cross_height),
				Vector2(cross_width, cross_height),
				Vector2(cross_width, half_size.y),
				Vector2(-cross_width, half_size.y),
				Vector2(-cross_width, cross_height),
				Vector2(-half_size.x, cross_height),
				Vector2(-half_size.x, -cross_height),
				Vector2(-cross_width, -cross_height)
			])
		4:  # FRACTURED RECTANGLE - Shattered panel with jagged edges
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			var jagged_factor = 0.15
			polygon_points = PackedVector2Array([
				Vector2(-half_size.x + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y),
				Vector2(half_size.x * 0.3 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y * 0.7 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x, half_size.y * 0.4 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x * 0.6 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x * 0.2 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y),
				Vector2(-half_size.x, half_size.y * 0.6 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x * 0.8 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y * 0.2 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x, -half_size.y * 0.3 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y))
			])
		5:  # FRACTURED RECTANGLE - Broken structural beam with missing chunks
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x * 0.4, -half_size.y),
				Vector2(half_size.x * 0.4, -half_size.y * 0.3),
				Vector2(half_size.x * 0.7, -half_size.y * 0.3),
				Vector2(half_size.x * 0.7, -half_size.y * 0.1),
				Vector2(half_size.x, -half_size.y * 0.1),
				Vector2(half_size.x, half_size.y * 0.2),
				Vector2(half_size.x * 0.8, half_size.y * 0.2),
				Vector2(half_size.x * 0.8, half_size.y * 0.6),
				Vector2(half_size.x, half_size.y * 0.6),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x * 0.3, half_size.y),
				Vector2(-half_size.x * 0.3, half_size.y * 0.7),
				Vector2(-half_size.x, half_size.y * 0.7),
				Vector2(-half_size.x, half_size.y * 0.4),
				Vector2(-half_size.x * 0.6, half_size.y * 0.4),
				Vector2(-half_size.x * 0.6, -half_size.y * 0.2),
				Vector2(-half_size.x, -half_size.y * 0.2)
			])
		6:  # FRACTURED RECTANGLE - Exploded equipment with irregular holes
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x * 0.2, -half_size.y),
				Vector2(half_size.x * 0.2, -half_size.y * 0.6),
				Vector2(half_size.x * 0.5, -half_size.y * 0.6),
				Vector2(half_size.x * 0.5, -half_size.y * 0.8),
				Vector2(half_size.x * 0.8, -half_size.y * 0.8),
				Vector2(half_size.x * 0.8, -half_size.y * 0.4),
				Vector2(half_size.x, -half_size.y * 0.4),
				Vector2(half_size.x, half_size.y * 0.3),
				Vector2(half_size.x * 0.7, half_size.y * 0.3),
				Vector2(half_size.x * 0.7, half_size.y * 0.7),
				Vector2(half_size.x, half_size.y * 0.7),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x * 0.4, half_size.y),
				Vector2(-half_size.x * 0.4, half_size.y * 0.5),
				Vector2(-half_size.x * 0.7, half_size.y * 0.5),
				Vector2(-half_size.x * 0.7, half_size.y * 0.2),
				Vector2(-half_size.x * 0.8, half_size.y * 0.2),
				Vector2(-half_size.x * 0.8, -half_size.y * 0.4),
				Vector2(-half_size.x * 0.6, -half_size.y * 0.4),
				Vector2(-half_size.x * 0.6, -half_size.y)
			])
		7:  # FRACTURED RECTANGLE - Severed pipe with jagged break
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x * 0.3, -half_size.y),
				Vector2(half_size.x * 0.3, -half_size.y * 0.4),
				Vector2(half_size.x * 0.6, -half_size.y * 0.4),
				Vector2(half_size.x * 0.6, -half_size.y * 0.2),
				Vector2(half_size.x, -half_size.y * 0.2),
				Vector2(half_size.x, half_size.y * 0.1),
				Vector2(half_size.x * 0.8, half_size.y * 0.1),
				Vector2(half_size.x * 0.8, half_size.y * 0.4),
				Vector2(half_size.x * 0.5, half_size.y * 0.4),
				Vector2(half_size.x * 0.5, half_size.y * 0.6),
				Vector2(half_size.x * 0.8, half_size.y * 0.6),
				Vector2(half_size.x * 0.8, half_size.y),
				Vector2(-half_size.x * 0.2, half_size.y),
				Vector2(-half_size.x * 0.2, half_size.y * 0.7),
				Vector2(-half_size.x * 0.5, half_size.y * 0.7),
				Vector2(-half_size.x * 0.5, half_size.y * 0.3),
				Vector2(-half_size.x * 0.8, half_size.y * 0.3),
				Vector2(-half_size.x * 0.8, -half_size.y * 0.1),
				Vector2(-half_size.x, -half_size.y * 0.1)
			])
		8:  # Shattered panel with protruding fragments
			object_size = Vector2(randf_range(4, max_size), randf_range(3, max_size * 0.8))
			var panel_half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-panel_half_size.x * 1.2, -panel_half_size.y * 0.8),  # Protruding left
				Vector2(-panel_half_size.x * 0.7, -panel_half_size.y * 1.1),  # Jagged top left
				Vector2(-panel_half_size.x * 0.2, -panel_half_size.y * 0.9),
				Vector2(panel_half_size.x * 0.4, -panel_half_size.y * 1.3),   # Protruding top
				Vector2(panel_half_size.x * 0.9, -panel_half_size.y * 0.7),
				Vector2(panel_half_size.x * 1.4, -panel_half_size.y * 0.3),   # Protruding right
				Vector2(panel_half_size.x * 0.8, panel_half_size.y * 0.2),
				Vector2(panel_half_size.x * 0.3, panel_half_size.y * 0.8),
				Vector2(-panel_half_size.x * 0.1, panel_half_size.y * 1.2),   # Protruding bottom
				Vector2(-panel_half_size.x * 0.6, panel_half_size.y * 0.6),
				Vector2(-panel_half_size.x * 1.1, panel_half_size.y * 0.1)    # Back to start
			])
		9:  # Twisted structural beam with multiple bends
			var beam_length = randf_range(6, max_size * 1.5)
			var beam_width = randf_range(2, max_size * 0.3)
			object_size = Vector2(beam_length, beam_width * 2)
			polygon_points = PackedVector2Array([
				Vector2(-beam_length * 0.6, -beam_width * 0.8),   # Bent left end
				Vector2(-beam_length * 0.3, -beam_width * 1.5),   # Protruding top
				Vector2(beam_length * 0.1, -beam_width * 0.9),
				Vector2(beam_length * 0.4, -beam_width * 1.8),    # Major protrusion
				Vector2(beam_length * 0.7, -beam_width * 0.4),
				Vector2(beam_length * 0.9, beam_width * 0.6),     # Bent right
				Vector2(beam_length * 0.5, beam_width * 1.4),     # Bottom protrusion
				Vector2(beam_length * 0.2, beam_width * 0.8),
				Vector2(-beam_length * 0.2, beam_width * 1.6),    # Another protrusion
				Vector2(-beam_length * 0.5, beam_width * 0.3),
				Vector2(-beam_length * 0.8, beam_width * 0.9)     # Back to start
			])
		10:  # Exploded equipment with scattered fragments
			var equip_size = randf_range(4, max_size)
			object_size = Vector2(equip_size * 1.4, equip_size * 1.2)
			polygon_points = PackedVector2Array([
				Vector2(-equip_size * 0.8, -equip_size * 0.6),    # Main body
				Vector2(-equip_size * 0.3, -equip_size * 1.1),    # Top fragment
				Vector2(equip_size * 0.2, -equip_size * 0.8),
				Vector2(equip_size * 0.7, -equip_size * 1.3),     # Large top protrusion
				Vector2(equip_size * 1.2, -equip_size * 0.4),     # Right fragment
				Vector2(equip_size * 0.9, equip_size * 0.3),
				Vector2(equip_size * 0.4, equip_size * 0.9),      # Bottom right
				Vector2(-equip_size * 0.1, equip_size * 1.4),     # Bottom protrusion
				Vector2(-equip_size * 0.6, equip_size * 0.7),
				Vector2(-equip_size * 1.1, equip_size * 0.2),     # Left fragment
				Vector2(-equip_size * 0.9, -equip_size * 0.1)     # Back to start
			])
		11:  # Severed pipe with jagged ends and bends
			var pipe_radius = randf_range(2, max_size * 0.6)
			object_size = Vector2(pipe_radius * 3.5, pipe_radius * 2.5)
			var num_points = 16
			for i in range(num_points):
				var angle = (i * 2 * PI) / num_points
				var radius = pipe_radius
				# Create jagged, irregular pipe shape
				if i < 4:  # Top jagged end
					radius *= randf_range(0.3, 1.8)
				elif i < 8:  # Right side with protrusions
					radius *= randf_range(0.7, 1.4)
				elif i < 12:  # Bottom jagged end
					radius *= randf_range(0.2, 1.6)
				else:  # Left side with bends
					radius *= randf_range(0.5, 1.3)
				var point = Vector2(cos(angle) * radius, sin(angle) * radius)
				polygon_points.append(point)
		12:  # Fractured solar panel with broken cells
			var panel_size = randf_range(5, max_size)
			object_size = Vector2(panel_size * 1.3, panel_size * 0.4)
			var solar_half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-solar_half_size.x * 1.1, -solar_half_size.y * 0.8),  # Jagged left edge
				Vector2(-solar_half_size.x * 0.6, -solar_half_size.y * 1.2),  # Top protrusion
				Vector2(-solar_half_size.x * 0.1, -solar_half_size.y * 0.9),
				Vector2(solar_half_size.x * 0.3, -solar_half_size.y * 1.4),   # Major top fragment
				Vector2(solar_half_size.x * 0.8, -solar_half_size.y * 0.7),
				Vector2(solar_half_size.x * 1.3, -solar_half_size.y * 0.2),   # Right protrusion
				Vector2(solar_half_size.x * 0.9, solar_half_size.y * 0.5),    # Right jagged
				Vector2(solar_half_size.x * 0.4, solar_half_size.y * 1.1),    # Bottom fragment
				Vector2(-solar_half_size.x * 0.1, solar_half_size.y * 0.8),
				Vector2(-solar_half_size.x * 0.7, solar_half_size.y * 0.3),   # Bottom left
				Vector2(-solar_half_size.x * 1.2, solar_half_size.y * 0.6)    # Back to start
			])
		13:  # Shattered circuit board with components
			var board_size = randf_range(3, max_size * 0.8)
			object_size = Vector2(board_size * 1.6, board_size * 1.3)
			polygon_points = PackedVector2Array([
				Vector2(-board_size * 0.9, -board_size * 0.5),    # Main board
				Vector2(-board_size * 0.4, -board_size * 0.9),    # Top component
				Vector2(board_size * 0.1, -board_size * 0.7),
				Vector2(board_size * 0.6, -board_size * 1.2),     # Large component
				Vector2(board_size * 1.1, -board_size * 0.4),     # Right edge
				Vector2(board_size * 0.8, board_size * 0.6),      # Right component
				Vector2(board_size * 0.3, board_size * 1.1),      # Bottom right
				Vector2(-board_size * 0.2, board_size * 0.9),     # Bottom component
				Vector2(-board_size * 0.7, board_size * 0.4),     # Bottom left
				Vector2(-board_size * 1.2, board_size * 0.1),     # Left edge
				Vector2(-board_size * 0.8, -board_size * 0.2)     # Back to start
			])
		14:  # Crushed hull plating with massive dents
			var hull_size = randf_range(4, max_size)
			object_size = Vector2(hull_size * 1.2, hull_size * 1.1)
			var hull_half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-hull_half_size.x * 1.1, -hull_half_size.y * 0.7),  # Crushed left
				Vector2(-hull_half_size.x * 0.5, -hull_half_size.y * 1.3),  # Major dent
				Vector2(hull_half_size.x * 0.2, -hull_half_size.y * 0.8),
				Vector2(hull_half_size.x * 0.7, -hull_half_size.y * 1.5),   # Deep dent
				Vector2(hull_half_size.x * 1.2, -hull_half_size.y * 0.3),   # Protruding right
				Vector2(hull_half_size.x * 0.9, hull_half_size.y * 0.6),    # Right dent
				Vector2(hull_half_size.x * 0.4, hull_half_size.y * 1.2),    # Bottom dent
				Vector2(-hull_half_size.x * 0.1, hull_half_size.y * 0.9),
				Vector2(-hull_half_size.x * 0.6, hull_half_size.y * 1.4),   # Bottom left dent
				Vector2(-hull_half_size.x * 1.0, hull_half_size.y * 0.5),   # Left dent
				Vector2(-hull_half_size.x * 0.8, -hull_half_size.y * 0.1)   # Back to start
			])
		15:  # Exploded thruster with scattered pieces
			var nozzle_size = randf_range(3, max_size * 0.7)
			object_size = Vector2(nozzle_size * 2.5, nozzle_size * 1.8)
			var num_points = 14
			for i in range(num_points):
				var angle = (i * 2 * PI) / num_points
				var radius = nozzle_size
				# Create exploded nozzle shape
				if i < 3:  # Top explosion
					radius *= randf_range(0.2, 2.1)
				elif i < 7:  # Right explosion
					radius *= randf_range(0.4, 1.9)
				elif i < 10:  # Bottom explosion
					radius *= randf_range(0.3, 2.0)
				else:  # Left explosion
					radius *= randf_range(0.5, 1.7)
				var point = Vector2(cos(angle) * radius, sin(angle) * radius)
				polygon_points.append(point)
		16:  # Destroyed life support with exposed internals
			var life_size = randf_range(4, max_size)
			object_size = Vector2(life_size * 1.3, life_size * 0.9)
			var life_half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-life_half_size.x * 1.0, -life_half_size.y * 0.5),  # Main body
				Vector2(-life_half_size.x * 0.4, -life_half_size.y * 1.1),  # Top damage
				Vector2(life_half_size.x * 0.2, -life_half_size.y * 0.8),
				Vector2(life_half_size.x * 0.7, -life_half_size.y * 1.4),   # Major breach
				Vector2(life_half_size.x * 1.2, -life_half_size.y * 0.3),   # Right damage
				Vector2(life_half_size.x * 0.8, life_half_size.y * 0.7),    # Internal exposure
				Vector2(life_half_size.x * 0.3, life_half_size.y * 1.3),    # Bottom breach
				Vector2(-life_half_size.x * 0.2, life_half_size.y * 0.9),
				Vector2(-life_half_size.x * 0.7, life_half_size.y * 1.5),   # Left breach
				Vector2(-life_half_size.x * 1.1, life_half_size.y * 0.4),   # Left damage
				Vector2(-life_half_size.x * 0.9, -life_half_size.y * 0.1)   # Back to start
			])
		17:  # Snapped antenna with multiple breaks
			var antenna_length = randf_range(6, max_size * 1.3)
			var antenna_width = randf_range(1, max_size * 0.2)
			object_size = Vector2(antenna_length * 1.4, antenna_width * 4)
			polygon_points = PackedVector2Array([
				Vector2(-antenna_length * 0.7, -antenna_width * 0.8),  # Base
				Vector2(-antenna_length * 0.3, -antenna_width * 1.8),  # First break
				Vector2(antenna_length * 0.1, -antenna_width * 0.9),
				Vector2(antenna_length * 0.5, -antenna_width * 2.1),   # Second break
				Vector2(antenna_length * 0.9, -antenna_width * 0.4),   # Third break
				Vector2(antenna_length * 1.3, antenna_width * 0.8),    # Tip
				Vector2(antenna_length * 0.8, antenna_width * 2.2),    # Bottom breaks
				Vector2(antenna_length * 0.4, antenna_width * 1.1),
				Vector2(antenna_length * 0.0, antenna_width * 2.0),
				Vector2(-antenna_length * 0.4, antenna_width * 0.9),
				Vector2(-antenna_length * 0.8, antenna_width * 1.9)    # Back to start
			])
		18:  # Ruptured storage container with contents
			var container_size = randf_range(4, max_size)
			object_size = Vector2(container_size * 1.2, container_size * 1.0)
			var container_half_size = object_size / 2
			polygon_points = PackedVector2Array([
				Vector2(-container_half_size.x * 1.1, -container_half_size.y * 0.6),  # Ruptured left
				Vector2(-container_half_size.x * 0.5, -container_half_size.y * 1.2),  # Top rupture
				Vector2(container_half_size.x * 0.2, -container_half_size.y * 0.9),
				Vector2(container_half_size.x * 0.7, -container_half_size.y * 1.4),   # Major rupture
				Vector2(container_half_size.x * 1.2, -container_half_size.y * 0.2),   # Right rupture
				Vector2(container_half_size.x * 0.9, container_half_size.y * 0.8),    # Contents spilling
				Vector2(container_half_size.x * 0.4, container_half_size.y * 1.3),    # Bottom rupture
				Vector2(-container_half_size.x * 0.1, container_half_size.y * 1.0),
				Vector2(-container_half_size.x * 0.6, container_half_size.y * 1.5),   # Left rupture
				Vector2(-container_half_size.x * 1.0, container_half_size.y * 0.7),   # Left damage
				Vector2(-container_half_size.x * 0.8, -container_half_size.y * 0.2)   # Back to start
			])
		19:  # Severed power conduit with exposed wiring
			var conduit_length = randf_range(5, max_size * 1.2)
			var conduit_width = randf_range(2, max_size * 0.4)
			polygon_points = PackedVector2Array([
				Vector2(-conduit_length * 0.7, -conduit_width * 0.7),  # Severed end
				Vector2(-conduit_length * 0.2, -conduit_width * 1.8),  # Exposed wiring
				Vector2(conduit_length * 0.2, -conduit_width * 0.9),
				Vector2(conduit_length * 0.6, -conduit_width * 2.0),   # Major exposure
				Vector2(conduit_length * 1.1, -conduit_width * 0.3),   # Other severed end
				Vector2(conduit_length * 0.7, conduit_width * 0.9),    # Bottom exposure
				Vector2(conduit_length * 0.3, conduit_width * 2.1),    # Wiring bundle
				Vector2(-conduit_length * 0.2, conduit_width * 1.2),
				Vector2(-conduit_length * 0.6, conduit_width * 2.2),   # More wiring
				Vector2(-conduit_length * 0.9, conduit_width * 0.6),   # Base damage
				Vector2(-conduit_length * 0.5, -conduit_width * 0.2)   # Back to start
			])
		20:  # Exploded reactor core with scattered fragments
			var reactor_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-reactor_size * 0.8, -reactor_size * 0.6),    # Core housing
				Vector2(-reactor_size * 0.3, -reactor_size * 1.2),    # Top explosion
				Vector2(reactor_size * 0.2, -reactor_size * 0.9),
				Vector2(reactor_size * 0.7, -reactor_size * 1.5),     # Major breach
				Vector2(reactor_size * 1.3, -reactor_size * 0.4),     # Right explosion
				Vector2(reactor_size * 0.9, reactor_size * 0.5),
				Vector2(reactor_size * 0.4, reactor_size * 1.1),      # Bottom breach
				Vector2(-reactor_size * 0.1, reactor_size * 1.6),     # Core fragments
				Vector2(-reactor_size * 0.6, reactor_size * 0.8),
				Vector2(-reactor_size * 1.2, reactor_size * 0.3),     # Left explosion
				Vector2(-reactor_size * 0.8, -reactor_size * 0.1)     # Back to start
			])
		21:  # Shattered navigation array with broken sensors
			var nav_size = randf_range(5, max_size * 1.1)
			polygon_points = PackedVector2Array([
				Vector2(-nav_size * 0.9, -nav_size * 0.5),    # Main array
				Vector2(-nav_size * 0.4, -nav_size * 1.1),    # Top sensor
				Vector2(nav_size * 0.1, -nav_size * 0.8),
				Vector2(nav_size * 0.6, -nav_size * 1.3),     # Broken sensor
				Vector2(nav_size * 1.1, -nav_size * 0.3),     # Right sensor
				Vector2(nav_size * 0.8, nav_size * 0.7),      # Side sensor
				Vector2(nav_size * 0.3, nav_size * 1.2),      # Bottom sensor
				Vector2(-nav_size * 0.2, nav_size * 0.9),
				Vector2(-nav_size * 0.7, nav_size * 1.4),     # Left sensor
				Vector2(-nav_size * 1.1, nav_size * 0.6),     # Damaged sensor
				Vector2(-nav_size * 0.9, -nav_size * 0.2)     # Back to start
			])
		22:  # Ruptured fuel tank with leaking contents
			var tank_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-tank_size * 1.0, -tank_size * 0.7),  # Tank body
				Vector2(-tank_size * 0.5, -tank_size * 1.3),  # Top rupture
				Vector2(tank_size * 0.2, -tank_size * 0.9),
				Vector2(tank_size * 0.7, -tank_size * 1.5),   # Major leak
				Vector2(tank_size * 1.2, -tank_size * 0.2),   # Right rupture
				Vector2(tank_size * 0.9, tank_size * 0.9),    # Fuel spill
				Vector2(tank_size * 0.4, tank_size * 1.4),    # Bottom leak
				Vector2(-tank_size * 0.1, tank_size * 1.0),
				Vector2(-tank_size * 0.6, tank_size * 1.5),   # Left rupture
				Vector2(-tank_size * 1.0, tank_size * 0.8),   # Tank damage
				Vector2(-tank_size * 0.8, -tank_size * 0.3)   # Back to start
			])
		23:  # Destroyed communication dish with bent antennae
			var dish_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-dish_size * 0.8, -dish_size * 0.6),  # Dish base
				Vector2(-dish_size * 0.3, -dish_size * 1.2),  # Bent antenna
				Vector2(dish_size * 0.2, -dish_size * 0.9),
				Vector2(dish_size * 0.7, -dish_size * 1.4),   # Broken dish
				Vector2(dish_size * 1.2, -dish_size * 0.3),   # Right antenna
				Vector2(dish_size * 0.8, dish_size * 0.6),    # Side damage
				Vector2(dish_size * 0.3, dish_size * 1.1),    # Bottom antenna
				Vector2(-dish_size * 0.2, dish_size * 0.8),
				Vector2(-dish_size * 0.7, dish_size * 1.3),   # Left antenna
				Vector2(-dish_size * 1.1, dish_size * 0.5),   # Dish damage
				Vector2(-dish_size * 0.9, -dish_size * 0.1)   # Back to start
			])
		24:  # Exploded cargo bay with scattered debris
			var cargo_size = randf_range(5, max_size * 1.2)
			polygon_points = PackedVector2Array([
				Vector2(-cargo_size * 0.9, -cargo_size * 0.5),    # Bay structure
				Vector2(-cargo_size * 0.4, -cargo_size * 1.1),    # Top explosion
				Vector2(cargo_size * 0.1, -cargo_size * 0.8),
				Vector2(cargo_size * 0.6, -cargo_size * 1.3),     # Major breach
				Vector2(cargo_size * 1.1, -cargo_size * 0.4),     # Right explosion
				Vector2(cargo_size * 0.8, cargo_size * 0.6),      # Cargo spill
				Vector2(cargo_size * 0.3, cargo_size * 1.2),      # Bottom breach
				Vector2(-cargo_size * 0.2, cargo_size * 0.9),
				Vector2(-cargo_size * 0.7, cargo_size * 1.4),     # Left explosion
				Vector2(-cargo_size * 1.2, cargo_size * 0.7),     # Bay damage
				Vector2(-cargo_size * 0.8, -cargo_size * 0.2)     # Back to start
			])
		25:  # Shattered observation window with glass fragments
			var window_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-window_size * 0.8, -window_size * 0.6),  # Window frame
				Vector2(-window_size * 0.3, -window_size * 1.2),  # Top glass
				Vector2(window_size * 0.2, -window_size * 0.9),
				Vector2(window_size * 0.7, -window_size * 1.4),   # Shattered glass
				Vector2(window_size * 1.2, -window_size * 0.3),   # Right frame
				Vector2(window_size * 0.8, window_size * 0.7),    # Side damage
				Vector2(window_size * 0.3, window_size * 1.1),    # Bottom glass
				Vector2(-window_size * 0.2, window_size * 0.8),
				Vector2(-window_size * 0.7, window_size * 1.3),   # Left frame
				Vector2(-window_size * 1.1, window_size * 0.6),   # Glass fragments
				Vector2(-window_size * 0.9, -window_size * 0.1)   # Back to start
			])
		26:  # Ruptured airlock with bent doors
			var airlock_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-airlock_size * 0.9, -airlock_size * 0.5),    # Airlock frame
				Vector2(-airlock_size * 0.4, -airlock_size * 1.1),    # Top door
				Vector2(airlock_size * 0.1, -airlock_size * 0.8),
				Vector2(airlock_size * 0.6, -airlock_size * 1.3),     # Bent door
				Vector2(airlock_size * 1.1, -airlock_size * 0.4),     # Right frame
				Vector2(airlock_size * 0.8, airlock_size * 0.6),      # Side damage
				Vector2(airlock_size * 0.3, airlock_size * 1.2),      # Bottom door
				Vector2(-airlock_size * 0.2, airlock_size * 0.9),
				Vector2(-airlock_size * 0.7, airlock_size * 1.4),     # Left frame
				Vector2(-airlock_size * 1.2, airlock_size * 0.7),     # Door damage
				Vector2(-airlock_size * 0.8, -airlock_size * 0.2)     # Back to start
			])
		27:  # Destroyed medical bay with scattered equipment
			var med_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-med_size * 0.8, -med_size * 0.6),  # Bay structure
				Vector2(-med_size * 0.3, -med_size * 1.2),  # Top equipment
				Vector2(med_size * 0.2, -med_size * 0.9),
				Vector2(med_size * 0.7, -med_size * 1.4),   # Broken equipment
				Vector2(med_size * 1.2, -med_size * 0.3),   # Right damage
				Vector2(med_size * 0.8, med_size * 0.7),    # Scattered parts
				Vector2(med_size * 0.3, med_size * 1.1),    # Bottom equipment
				Vector2(-med_size * 0.2, med_size * 0.8),
				Vector2(-med_size * 0.7, med_size * 1.3),   # Left damage
				Vector2(-med_size * 1.1, med_size * 0.5),   # Equipment debris
				Vector2(-med_size * 0.9, -med_size * 0.1)   # Back to start
			])
		28:  # Exploded engine nacelle with twisted metal
			var nacelle_size = randf_range(5, max_size * 1.3)
			polygon_points = PackedVector2Array([
				Vector2(-nacelle_size * 0.8, -nacelle_size * 0.5),    # Nacelle body
				Vector2(-nacelle_size * 0.3, -nacelle_size * 1.1),    # Top explosion
				Vector2(nacelle_size * 0.1, -nacelle_size * 0.8),
				Vector2(nacelle_size * 0.6, -nacelle_size * 1.3),     # Major breach
				Vector2(nacelle_size * 1.1, -nacelle_size * 0.4),     # Right explosion
				Vector2(nacelle_size * 0.8, nacelle_size * 0.6),      # Twisted metal
				Vector2(nacelle_size * 0.3, nacelle_size * 1.2),      # Bottom breach
				Vector2(-nacelle_size * 0.2, nacelle_size * 0.9),
				Vector2(-nacelle_size * 0.7, nacelle_size * 1.4),     # Left explosion
				Vector2(-nacelle_size * 1.2, nacelle_size * 0.7),     # Engine debris
				Vector2(-nacelle_size * 0.8, -nacelle_size * 0.2)     # Back to start
			])
		29:  # Shattered bridge console with exposed electronics
			var console_size = randf_range(4, max_size)
			polygon_points = PackedVector2Array([
				Vector2(-console_size * 0.9, -console_size * 0.5),    # Console base
				Vector2(-console_size * 0.4, -console_size * 1.1),    # Top screen
				Vector2(console_size * 0.1, -console_size * 0.8),
				Vector2(console_size * 0.6, -console_size * 1.3),     # Broken screen
				Vector2(console_size * 1.1, -console_size * 0.4),     # Right panel
				Vector2(console_size * 0.8, console_size * 0.7),      # Exposed circuits
				Vector2(console_size * 0.3, console_size * 1.1),      # Bottom panel
				Vector2(-console_size * 0.2, console_size * 0.8),
				Vector2(-console_size * 0.7, console_size * 1.3),     # Left panel
				Vector2(-console_size * 1.2, console_size * 0.6),     # Electronics
				Vector2(-console_size * 0.8, -console_size * 0.2)     # Back to start
			])
	
	object.set_meta("size", object_size)
	
	# Set up collision shape - use ConcavePolygonShape2D for complex shapes
	var polygon_shape = ConcavePolygonShape2D.new()
	# Convert polygon points to segments (pairs of consecutive points)
	var segments = PackedVector2Array()
	for i in range(polygon_points.size()):
		segments.append(polygon_points[i])
		segments.append(polygon_points[(i + 1) % polygon_points.size()])
	polygon_shape.segments = segments
	collision_shape.shape = polygon_shape
	
	# Set up visual polygon
	visual_polygon.polygon = polygon_points
	visual_polygon.color = color
	
	# Calculate mass based on size
	var size = object.get_meta("size")
	object.set_meta("mass", size.x * size.y / 50.0)  # Normalize mass
	
	# Initialize random rotation speed (increased for more dynamic movement)
	var angular_velocity = randf_range(0.1, 4.0)  # Much wider range for dynamic spinning
	if randf() < 0.5:
		angular_velocity = -angular_velocity
	object.set_meta("angular_velocity", angular_velocity)
	
	# Add 15% speed variation for leftward movement
	var speed_variation = randf_range(0.85, 1.15)  # 15% variation
	object.set_meta("speed_variation", speed_variation)
	
	# Add small random velocity
	object.set_meta("velocity", Vector2(randf_range(-5, 5), randf_range(-5, 5)))
	
	# No collisions for decorative debris - they are just visual
	object.set_collision_layer(0)  # No collision layer
	object.set_collision_mask(0)   # No collision mask
	
	# No collision signals for decorative debris
	
	return object

# Collision handling functions removed - no collisions for decorative debris



func create_foreground_object() -> Node2D:
	var object = Area2D.new()  # Use Area2D for collision detection
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	object.add_child(collision_shape)
	
	# Create a container for all the visual elements
	var visual_container = Node2D.new()
	visual_container.name = "VisualContainer"
	object.add_child(visual_container)
	
	# Physics variables
	object.set_meta("velocity", Vector2.ZERO)
	object.set_meta("angular_velocity", 0.0)
	object.set_meta("mass", 1.0)
	object.set_meta("size", Vector2.ZERO)
	object.set_meta("is_foreground", true)
	
	# SIMPLIFIED: Use base color with foreground brightness (darker)
	var foreground_color = base_object_color
	foreground_color.r = clamp(base_object_color.r * 0.7, 0.0, 1.0)  # 70% brightness for foreground
	foreground_color.g = clamp(base_object_color.g * 0.7, 0.0, 1.0)
	foreground_color.b = clamp(base_object_color.b * 0.7, 0.0, 1.0)
	
	# Create larger foreground objects with much more varied shapes and sizes
	var base_size = randf_range(30, 180)  # Much wider base size range
	var length_factor = randf_range(0.3, 2.5)  # Length variation (elongated to compact)
	var thickness_factor = randf_range(0.4, 1.8)  # Thickness variation (thin to thick)
	
	# Apply random orientation (some pieces longer horizontally, others vertically)
	var is_horizontal = randf() < 0.6  # 60% chance for horizontal orientation
	var size = Vector2.ZERO
	if is_horizontal:
		size = Vector2(base_size * length_factor, base_size * thickness_factor)
	else:
		size = Vector2(base_size * thickness_factor, base_size * length_factor)
	
	# Generate varied shapes for foreground objects - ALL AVAILABLE SHAPES
	var shape_type = randi() % 30  # 30 different shapes total
	var polygon_points = PackedVector2Array()
	
	# Use shared shape generation function
	polygon_points = shape_generator.generate_complex_shape(shape_type, size)  # regular foreground
	
	# Set up collision shape - use rectangle that matches the actual size
	var rectangle_shape = RectangleShape2D.new()
	var rect_size = size * 0.8  # Collision shape slightly smaller than visual for better gameplay
	rect_size = Vector2(max(rect_size.x, 15), max(rect_size.y, 15))  # Minimum collision size
	rectangle_shape.size = rect_size
	collision_shape.shape = rectangle_shape
	
	# Create fuzzy/blurry effect with multiple overlapping polygons
	create_fuzzy_shape(visual_container, polygon_points, foreground_color)
	
	# Calculate mass based on size
	object.set_meta("size", size)
	object.set_meta("mass", size.x * size.y / 30.0)  # Heavier than background objects
	
	# Initialize random rotation speed (increased for more dynamic movement)
	var angular_velocity = randf_range(0.1, 4.0)  # Much wider range for dynamic spinning
	if randf() < 0.5:
		angular_velocity = -angular_velocity
	object.set_meta("angular_velocity", angular_velocity)
	
	# Add 15% speed variation for leftward movement
	var speed_variation = randf_range(0.85, 1.15)  # 15% variation
	object.set_meta("speed_variation", speed_variation)
	
	# Add more dynamic random velocity
	object.set_meta("velocity", Vector2(randf_range(-15, 15), randf_range(-15, 15)))
	
	# No collisions for decorative foreground debris - they are just visual
	object.set_collision_layer(0)  # No collision layer
	object.set_collision_mask(0)   # No collision mask
	
	# Set up lighting - make foreground debris visible to Light2D
	object.light_mask = 2  # Match the spotlight's light mask
	
	# Also set light mask on all visual elements
	for child in object.get_children():
		if child is Polygon2D:
			child.light_mask = 2
		elif child.name == "VisualContainer":
			# Set light mask on all visual elements in the container
			for visual_child in child.get_children():
				if visual_child is Polygon2D:
					visual_child.light_mask = 2
	
	# No collision signals for decorative debris
	
	return object

func create_fuzzy_shape(container: Node2D, base_points: PackedVector2Array, base_color: Color):
	# Create a simple, clean blur effect with few layers
	var num_layers = 6  # Fewer layers for cleaner effect
	
	for i in range(num_layers):
		var polygon = Polygon2D.new()
		container.add_child(polygon)
		
		# Simple linear expansion
		var expansion_factor = 1.0 + (i * 0.1)  # Each layer is 10% larger
		
		# Create expanded points for this layer
		var expanded_points = PackedVector2Array()
		for point in base_points:
			expanded_points.append(point * expansion_factor)
		
		polygon.polygon = expanded_points
		
		# Simple linear opacity falloff
		var opacity = 1.0 - (i * 0.15)  # Each layer is 15% more transparent
		opacity = clamp(opacity, 0.0, 1.0)
		
		# Set color with calculated opacity
		var layer_color = base_color
		layer_color.a = opacity
		polygon.color = layer_color
		
		# All layers of the same object should have the same z-index to avoid depth issues
		polygon.z_index = 0

func _process(delta):
	_process_camera_shake(delta)
	
	# Update time elapsed for foreground growth
	time_elapsed += delta
	
	# Difficulty-based color changes removed
	
	# Update world position (how far the world has moved)
	world_position += base_speed * delta
	
	# Handle planet layer (moves very slowly - distant parallax)
	if planet_layer:
		var planet_speed = base_speed * 0.1  # Very slow movement (10% of base speed)
		planet_layer.position.x -= planet_speed * delta
		
		# Planet center position is relative to planet_layer, so it moves with the layer automatically
		
		# Update shadow position to follow star-planet line
		update_planet_shadow()
		
		# Update shadow overlay system
		update_shadow_overlay()
		
		# Apply shadow effects to debris
		apply_shadow_to_debris()
		
		# Reset planet position when the entire planet is off screen to the left
		# Planet radius is 400, so we need to wait until the entire planet is completely off screen
		# The planet's world position is planet_layer.position + planet_center
		# We need the planet's right edge (world position + radius) to be off the left side of the screen
		var planet_world_x = planet_layer.position.x + planet_center.x
		if planet_world_x + planet_radius < -screen_size.x:
			# Spawn planet much further to the right to account for atmosphere visibility
			# Only move the layer position since planet_center is relative to the layer
			planet_layer.position.x += screen_size.x * 25.0  # Increased from 3.5 to 5.0
	
	# FOREGROUND LAYER IS NOW STATIONARY - only objects move left
	# Apply physics to foreground objects (they move left individually)
	apply_layer_physics(foreground_layer, delta)
	
	# Clean up foreground objects that have moved off-screen to the left
	for i in range(int(foreground_layer.get_child_count() - 1), -1, -1):
		var object = foreground_layer.get_child(i)
		
		# DESPAWN WHEN COMPLETELY OFF-SCREEN LEFT - fixed coordinates
		if object.position.x < -300:  # 300 pixels outside left edge
			foreground_layer.remove_child(object)
			return_object_to_pool(object, 0)  # Foreground uses pool index 0
	
	# Infinite generation for foreground layer - spawn new objects over time
	foreground_spawn_timer += delta
	
	# Check if we need more objects on the right side
	var rightmost_object_x = -1000  # Default to far left
	for object in foreground_layer.get_children():
		rightmost_object_x = max(rightmost_object_x, object.position.x)
	
	# Spawn one object at a time when timer is ready
	# Fixed spawn area - always spawn when timer is ready, regardless of object positions
	if foreground_spawn_timer >= foreground_spawn_interval:
		add_single_foreground_object()
		foreground_spawn_timer = 0.0  # Reset timer
	

	
	# PARALLAX LAYERS ARE NOW STATIONARY - only objects move left
	# Apply physics to all objects in each layer (they move left individually)
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		
		# Apply physics to all objects in this layer
		apply_layer_physics(layer, delta)
		
		# Clean up objects that have moved off-screen behind the player
		for j in range(int(layer.get_child_count() - 1), -1, -1):
			var object = layer.get_child(j)
			
			# DESPAWN WHEN COMPLETELY OFF-SCREEN LEFT - fixed coordinates
			if object.position.x < -300:  # 300 pixels outside left edge
				layer.remove_child(object)
				return_object_to_pool(object, i + 1)  # Background layers use pool indices 1+
		
		# Infinite generation - spawn new objects when needed
		# Check if we need more objects on the right side
		var layer_rightmost_x = -1000  # Default to far left
		for object in layer.get_children():
			layer_rightmost_x = max(layer_rightmost_x, object.position.x)
		
		# If the rightmost object is getting close to the camera view, spawn more
		# Start spawning immediately if no objects exist
		if layer_rightmost_x < screen_size.x + 100 or layer.get_child_count() == 0:  # Spawn when rightmost object is getting close
			add_new_objects_to_layer(layer, i)

func apply_layer_physics(layer: Node2D, delta: float):
	# Apply physics to all objects in the layer
	for object in layer.get_children():
		if object.has_meta("velocity") and object.has_meta("angular_velocity"):
			# Get current velocity
			var velocity = object.get_meta("velocity")
			
			# Apply constant leftward force based on layer depth
			var layer_index = object.get_meta("layer_index", 0)
			var layer_speed_multiplier = 1.0
			
			# Foreground objects move fastest (closest to camera)
			if layer == foreground_layer:
				layer_speed_multiplier = 6.0  # Faster than absolute foreground (was 3.5)
				# Apply additional difficulty scaling for collision debris
				var difficulty_factor = 1.0 + (time_elapsed / 60.0)  # Faster progression for collision debris
				layer_speed_multiplier *= difficulty_factor

			else:
				# Background layers move slower (farther from camera)
				# Clamp layer_index to valid range to prevent array index errors
				var clamped_layer_index = min(layer_index, layer_speeds.size() - 1)
				layer_speed_multiplier = layer_speeds[clamped_layer_index]
			
			# Calculate constant leftward velocity that increases over time (not acceleration)
			var current_base_speed = base_speed * (1.0 + time_elapsed / 120.0)  # Speed increases over time
			var leftward_velocity = current_base_speed * layer_speed_multiplier
			leftward_velocity = max(leftward_velocity, base_speed * layer_speed_multiplier * 0.5)  # Minimum velocity
			
			# Apply 15% speed variation to each object
			var speed_variation = object.get_meta("speed_variation", 1.0)
			leftward_velocity *= speed_variation
			
			# Set constant leftward velocity (not acceleration)
			velocity.x = -leftward_velocity
			
			# Apply velocity to position
			object.position += velocity * delta
			
			# Apply angular velocity
			var angular_velocity = object.get_meta("angular_velocity")
			object.rotation += angular_velocity * delta
			
			# Apply 3D flip effect by scaling both X and Y axes with random variations
			if not object.has_meta("flip_timer"):
				object.set_meta("flip_timer", 0.0)
				# Most debris should flip slowly, only a few percent should be fast
				var x_speed_roll = randf()
				var y_speed_roll = randf()
				
				# 80% slow (0.1-0.5), 15% medium (0.5-1.0), 5% fast (1.0-1.8)
				var x_flip_speed = 0.0
				if x_speed_roll < 0.8:
					x_flip_speed = randf_range(0.1, 0.5)  # Slow
				elif x_speed_roll < 0.95:
					x_flip_speed = randf_range(0.5, 1.0)  # Medium
				else:
					x_flip_speed = randf_range(1.0, 1.8)  # Fast
				
				var y_flip_speed = 0.0
				if y_speed_roll < 0.8:
					y_flip_speed = randf_range(0.1, 0.5)  # Slow
				elif y_speed_roll < 0.95:
					y_flip_speed = randf_range(0.5, 1.0)  # Medium
				else:
					y_flip_speed = randf_range(1.0, 1.8)  # Fast
				
				object.set_meta("x_flip_speed", x_flip_speed)
				object.set_meta("y_flip_speed", y_flip_speed)
				object.set_meta("x_flip_enabled", randf() < 0.7)  # 70% chance for X flip
				object.set_meta("y_flip_enabled", randf() < 0.7)  # 70% chance for Y flip
				object.set_meta("x_flip_phase", randf_range(0.0, PI * 2))  # Random phase offset for X
				object.set_meta("y_flip_phase", randf_range(0.0, PI * 2))  # Random phase offset for Y
				object.set_meta("x_flip_range", 1.0 if randf() < 0.5 else -1.0)  # Random direction for X
				object.set_meta("y_flip_range", 1.0 if randf() < 0.5 else -1.0)  # Random direction for Y
			
			var flip_timer = object.get_meta("flip_timer")
			flip_timer += delta
			object.set_meta("flip_timer", flip_timer)
			
			# Calculate X-axis flip scale with individual speed
			var x_flip_enabled = object.get_meta("x_flip_enabled")
			var current_x_flip_speed = object.get_meta("x_flip_speed")
			var x_flip_phase = object.get_meta("x_flip_phase")
			var x_flip_range = object.get_meta("x_flip_range")
			var x_scale = 1.0
			if x_flip_enabled:
				var x_flip_scale = sin(flip_timer * PI * current_x_flip_speed + x_flip_phase)  # Individual X speed
				# Apply power function to spend more time in intermediate range
				x_flip_scale = sign(x_flip_scale) * pow(abs(x_flip_scale), 0.3)  # Power function for time distribution
				x_scale = x_flip_scale * x_flip_range  # Apply direction
			
			# Calculate Y-axis flip scale with individual speed
			var y_flip_enabled = object.get_meta("y_flip_enabled")
			var current_y_flip_speed = object.get_meta("y_flip_speed")
			var y_flip_phase = object.get_meta("y_flip_phase")
			var y_flip_range = object.get_meta("y_flip_range")
			var y_scale = 1.0
			if y_flip_enabled:
				var y_flip_scale = sin(flip_timer * PI * current_y_flip_speed + y_flip_phase)  # Individual Y speed
				# Apply power function to spend more time in intermediate range
				y_flip_scale = sign(y_flip_scale) * pow(abs(y_flip_scale), 0.3)  # Power function for time distribution
				y_scale = y_flip_scale * y_flip_range  # Apply direction
			
			# Apply the flip scales to both axes
			object.scale.x = x_scale
			object.scale.y = y_scale
			
			# Apply brightness variation based on flip orientation (lighting effect)
			var brightness_variation = 0.0
			if x_flip_enabled or y_flip_enabled:
				# Calculate brightness based on how "face-on" the object is to the viewer
				# When scale is close to 1.0, object is face-on (bright)
				# When scale is close to -1.0, object is edge-on (dark)
				# Use the actual scale values to allow proper flipping
				var x_brightness = x_scale if x_flip_enabled else 1.0
				var y_brightness = y_scale if y_flip_enabled else 1.0
				var face_on_factor = (x_brightness + y_brightness) / 2.0  # Average of both axes
				
				# Convert to brightness variation: 1.0 = bright, 0.1 = dark (stronger contrast)
				# Map from -1 to +1 range to 0.1 to 1.0 range
				brightness_variation = 0.1 + ((face_on_factor + 1.0) * 0.45)  # Range: 0.1 to 1.0
			
			# Apply brightness to all visual elements of the object
			apply_brightness_to_object(object, brightness_variation)
			
			# Apply minimal drag to Y velocity only (preserve leftward movement)
			velocity.y *= BG_DRAG  # Only apply drag to Y velocity
			# No angular drag in space - rotations should maintain momentum
			
			# Ensure minimum leftward velocity to prevent objects from stopping
			if velocity.x > -20.0:
				velocity.x = -20.0
			
			# Update meta data
			object.set_meta("velocity", velocity)
			object.set_meta("angular_velocity", angular_velocity)
			
			# Keep rotation within reasonable bounds
			if object.rotation > PI * 4:
				object.rotation -= PI * 2
			elif object.rotation < -PI * 4:
				object.rotation += PI * 2

func apply_brightness_to_object(object: Node2D, brightness_factor: float):
	# Apply brightness variation to all visual elements of the object
	# This function now works with the shadow system by applying brightness on top of shadow effects
	if object.has_method("get_child") and object.get_child_count() > 1:
		var layer_index = object.get_meta("layer_index", 0)
		
		if layer_index == 0:  # Foreground layer
			# Foreground objects have Polygon2D children directly starting from index 1
			for i in range(1, object.get_child_count()):
				var child = object.get_child(i)
				if child is Polygon2D:
					apply_brightness_to_polygon(child, brightness_factor)
		else:  # Background layers
			# Background objects have a single visual polygon
			var visual_polygon = object.get_child(1)
			if visual_polygon is Polygon2D:
				apply_brightness_to_polygon(visual_polygon, brightness_factor)

func apply_brightness_to_polygon(polygon: Polygon2D, brightness_factor: float):
	# Apply brightness variation while preserving shadow effects
	# Get the base color (original color without any effects)
	var base_color = polygon.get_meta("base_color", polygon.color)
	if not polygon.has_meta("base_color"):
		polygon.set_meta("base_color", polygon.color)
		base_color = polygon.color
	
	# Store the current brightness factor for the shadow system
	polygon.set_meta("current_brightness_factor", brightness_factor)
	
	# Get the current shadow factor (if any shadow is applied)
	var shadow_factor = polygon.get_meta("current_shadow_factor", 1.0)
	
	# Calculate final color: base_color * shadow_factor * brightness_factor
	var final_color = base_color
	final_color.r = clamp(base_color.r * shadow_factor * brightness_factor, 0.0, 1.0)
	final_color.g = clamp(base_color.g * shadow_factor * brightness_factor, 0.0, 1.0)
	final_color.b = clamp(base_color.b * shadow_factor * brightness_factor, 0.0, 1.0)
	
	polygon.color = final_color

func add_new_objects_to_layer(layer: Node2D, layer_index: int):
	# Add new objects to the right side of the screen with progressive difficulty
	var base_object_count = get_current_parallax_objects_per_layer()
	var object_count = base_object_count + layer_index  # More objects for deeper layers
	
	# SPAWN OUTSIDE CAMERA VIEW ON THE RIGHT - fixed world coordinates
	var spawn_start_x = 2000  # Fixed world position 2000 pixels from origin
	var spawn_end_x = 2300    # Fixed world position 2300 pixels from origin
	
	for i in range(object_count):
		var object = get_object_from_pool(layer_index + 1)  # Background layers use pool indices 1+
		
		# Fix the layer_index to match the actual layer (not the pool index)
		object.set_meta("layer_index", layer_index + 1)  # Background layers should have layer_index 1+
		
		# Spread objects across the spawn area
		var spawn_x = spawn_start_x + (i * (spawn_end_x - spawn_start_x) / max(1, object_count - 1)) + randf_range(-50, 50)
		spawn_x = clamp(spawn_x, spawn_start_x, spawn_end_x)
		
		object.position = Vector2(
			spawn_x,  # Spread across spawn area
			randf_range(0, screen_size.y)
		)
		
		# Initialize physics for new object
		if object.has_meta("velocity"):
			object.set_meta("velocity", Vector2(randf_range(-3, 3), randf_range(-3, 3)))
		if object.has_meta("angular_velocity"):
			var angular_velocity = randf_range(BG_MIN_ROTATION_SPEED, BG_MAX_ROTATION_SPEED)
			if randf() < 0.5:
				angular_velocity = -angular_velocity
			object.set_meta("angular_velocity", angular_velocity)
		
		# Add 15% speed variation for leftward movement
		var speed_variation = randf_range(0.85, 1.15)  # 15% variation
		object.set_meta("speed_variation", speed_variation)
		
		# Add random rotation
		object.rotation = randf_range(-PI, PI)
		
		layer.add_child(object)



func add_single_foreground_object():
	# Spawn a single foreground object at a fixed world position
	# Use a large fixed X coordinate that's always off-screen to the right
	var fixed_spawn_x = 2000 + randf_range(0, 300)  # Fixed world position 2000-2300 pixels from origin
	
	# Random Y position with much larger range for foreground objects (50-120 pixels in size)
	# Use full screen height plus extra space above and below for better distribution
	var spawn_y = randf_range(-100, screen_size.y + 100)  # Extended range beyond screen bounds
	
	var object = get_object_from_pool(0)  # Foreground uses pool index 0
	object.position = Vector2(fixed_spawn_x, spawn_y)
	
	# Initialize physics for new foreground object
	if object.has_meta("velocity"):
		object.set_meta("velocity", Vector2(randf_range(-8, 8), randf_range(-8, 8)))  # More movement
	if object.has_meta("angular_velocity"):
		var angular_velocity = randf_range(0.1, 4.0)  # Much wider range for dynamic spinning
		if randf() < 0.5:
			angular_velocity = -angular_velocity
		object.set_meta("angular_velocity", angular_velocity)
	
	# Add 15% speed variation for leftward movement
	var speed_variation = randf_range(0.85, 1.15)  # 15% variation
	object.set_meta("speed_variation", speed_variation)
	
	# Add random rotation
	object.rotation = randf_range(-PI, PI)
	
	foreground_layer.add_child(object)





func reset():
	# Reset world position and timing
	world_position = 0.0
	time_elapsed = 0.0
	just_reset = true  # Flag to prevent immediate spawning
	
	# Reset shadow system
	shadow_active = false
	shadow_intensity = 0.0
	if shadow_overlay:
		shadow_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	
	# Clear all shadow effects from objects
	clear_shadow_from_all_objects()
	
	# Reset debug label
	if debug_label:
		debug_label.text = "Shadow: Inactive"
	
	# SIMPLIFIED: Generate new colors for this run FIRST (but don't update objects yet)
	generate_new_colors_only()
	
	# Reset foreground layer completely
	foreground_layer.position.x = 0.0
	foreground_object_count = 8  # Reset to initial count
	
	# AGGRESSIVE: Clear all existing foreground objects and FREE them
	for i in range(int(foreground_layer.get_child_count() - 1), -1, -1):
		var object = foreground_layer.get_child(i)
		foreground_layer.remove_child(object)
		object.queue_free()
	
	# AGGRESSIVE: Clear all parallax layers and FREE objects
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		layer.position.x = 0.0
		
		# Free all objects instead of returning to pools
		for j in range(int(layer.get_child_count() - 1), -1, -1):
			var object = layer.get_child(j)
			layer.remove_child(object)
			object.queue_free()
	
	# AGGRESSIVE: Clear all object pools completely
	object_pool_manager.clear_all_pools()
	
	# CRITICAL: Update ship color
	update_ship_color_simple()
	
	# AGGRESSIVE: Force multiple color updates to ensure consistency
	await get_tree().process_frame
	
	# DEBUG: Check colors after reset
	debug_check_colors()
	
	# Reset star and planet positions
	if star_layer:
		star_layer.position.x = 0.0
	if planet_layer:
		planet_layer.position.x = 0.0
	
	# Reset planet center position to initial state
	planet_center = Vector2(screen_size.x + planet_radius * 1.15, star_position.y + planet_radius * 0.5)
	
	# Ensure physics system is active
	set_physics_process(true)
	set_process(true)
	
	# Force a frame to ensure everything is reset
	await get_tree().process_frame

func start_background_spawning():
	# Start the background spawning system after initial delay
	just_reset = false

# Obstacle color update function removed

func calculate_progressive_difficulty():
	# Calculate current object density based on time elapsed
	var density_progress = min(time_elapsed / parallax_density_growth_time, 1.0)
	var current_parallax_objects = int(lerp(1, max_parallax_objects_per_layer, density_progress))  # Start with 1 object
	
	# Calculate current speed multiplier based on time elapsed
	var speed_progress = min(time_elapsed / speed_increase_time, 1.0)
	var speed_multiplier = lerp(1.0, max_speed_multiplier, speed_progress)
	
	# Update base speed
	base_speed = initial_base_speed * speed_multiplier
	
	return current_parallax_objects

func get_current_parallax_objects_per_layer() -> int:
	return calculate_progressive_difficulty()

func get_planet_center() -> Vector2:
	# Return the actual world position of the planet center
	# planet_center is relative to planet_layer, so we need to add planet_layer's position
	if planet_layer:
		return planet_layer.position + planet_center
	else:
		return planet_center  # Fallback if planet_layer doesn't exist

func get_base_object_color() -> Color:
	return base_object_color

# Difficulty-based color change system completely removed
		


# Difficulty-based color generation removed


	


func get_background_color() -> Color:
	return background_color

# Camera shake functions
func trigger_camera_shake(intensity: float, duration: float, frequency: float = 20.0):
	cam_shake_timer = 0.0
	cam_shake_duration = duration
	cam_shake_intensity = intensity
	cam_shake_frequency = frequency
	cam_shake_seed = randf() * 1000.0

func _process_camera_shake(delta):
	if not camera:
		return
	if cam_shake_timer < cam_shake_duration:
		cam_shake_timer += delta
		var progress = cam_shake_timer / cam_shake_duration
		var current_intensity = cam_shake_intensity * (1.0 - progress)
		var t = cam_shake_seed + cam_shake_timer * cam_shake_frequency
		var offset = Vector2(
			sin(t * 2.0) * current_intensity,
			cos(t * 1.5) * current_intensity
		)
		camera.offset = offset
	else:
		camera.offset = Vector2.ZERO

func create_distant_planet_and_star():
	# Create star layer (furthest back - behind everything)
	star_layer = Node2D.new()
	star_layer.name = "StarLayer"
	star_layer.z_index = -50  # Star layer
	add_child(star_layer)
	
	# Create planet layer (in front of star)
	planet_layer = Node2D.new()
	planet_layer.name = "PlanetLayer"
	planet_layer.z_index = -25  # Planet layer
	add_child(planet_layer)
	
	# Position star in upper quarter of screen, further left
	star_position = Vector2(screen_size.x * 0.3, screen_size.y * 0.25)
	
	# Position planet much further off-screen to the right to hide atmosphere
	planet_center = Vector2(screen_size.x + planet_radius * 1.15, star_position.y + planet_radius * 0.5)
	
	# Create the star
	create_star()
	
	# Create the planet
	create_planet()

func create_star():
	# Create a complex main star with two components
	var star_container = Node2D.new()
	star_container.name = "MainStar"
	star_container.position = star_position
	star_layer.add_child(star_container)
	
	# Create the main star (larger)
	create_star_component(star_container, 12.0, 0.0, Color(1.0, 0.9, 0.7), "MainStarComponent")
	
	# Create the secondary star (smaller, rotated 45 degrees)
	create_star_component(star_container, 8.0, PI/4, Color(1.0, 0.95, 0.8), "SecondaryStarComponent")
	
	# Create distributed stars across the entire screen
	create_distributed_stars()

func create_star_component(container: Node2D, base_size: float, rotation_offset: float, base_color: Color, component_name: String):
	# Create a star component with glow effect
	var star_component = Node2D.new()
	star_component.name = component_name
	star_component.rotation = rotation_offset
	container.add_child(star_component)
	
	# Create multiple layers for star glow effect
	for i in range(8):
		var star_layer_node = Polygon2D.new()
		star_component.add_child(star_layer_node)
		
		# Create star shape (cross pattern)
		var star_size = base_size * (0.3 + i * 0.15)  # Each layer gets bigger
		var star_points = PackedVector2Array([
			Vector2(0, -star_size),      # Top
			Vector2(star_size * 0.3, -star_size * 0.3),  # Top right
			Vector2(star_size, 0),       # Right
			Vector2(star_size * 0.3, star_size * 0.3),   # Bottom right
			Vector2(0, star_size),       # Bottom
			Vector2(-star_size * 0.3, star_size * 0.3),  # Bottom left
			Vector2(-star_size, 0),      # Left
			Vector2(-star_size * 0.3, -star_size * 0.3)  # Top left
		])
		
		star_layer_node.polygon = star_points
		
		# Calculate color and opacity for this layer
		var opacity = 1.0 - (i * 0.12)
		opacity = clamp(opacity, 0.0, 1.0)
		
		# Bright star color with slight variation
		var star_color = base_color
		star_color.a = opacity
		star_layer_node.color = star_color
		star_layer_node.z_index = 0

func create_distributed_stars():
	# Create 200 stars distributed across the entire screen
	var very_small_stars = 150  # Very small stars
	var small_to_medium_stars = 50  # Small to medium stars
	
	# Create very small stars (150)
	for i in range(very_small_stars):
		create_single_distributed_star(randf_range(0.5, 1.5), "VerySmallStar" + str(i))
	
	# Create small to medium stars (50)
	for i in range(small_to_medium_stars):
		create_single_distributed_star(randf_range(2.0, 4.0), "SmallMediumStar" + str(i))

func create_single_distributed_star(size: float, star_name: String):
	# Create a single distributed star
	var star_container = Node2D.new()
	star_container.name = star_name
	
	# Random position across the entire screen (including off-screen areas for parallax)
	var screen_margin = 200  # Extra margin for off-screen stars
	var x_pos = randf_range(-screen_margin, screen_size.x + screen_margin)
	var y_pos = randf_range(-screen_margin, screen_size.y + screen_margin)
	star_container.position = Vector2(x_pos, y_pos)
	
	# Random rotation
	star_container.rotation = randf_range(0, PI * 2)
	
	star_layer.add_child(star_container)
	
	# Create star with fewer layers for performance (smaller stars)
	var num_layers = 4 if size < 2.0 else 6
	
	for i in range(num_layers):
		var star_layer_node = Polygon2D.new()
		star_container.add_child(star_layer_node)
		
		# Create star shape (cross pattern)
		var star_size = size * (0.3 + i * 0.2)  # Each layer gets bigger
		var star_points = PackedVector2Array([
			Vector2(0, -star_size),      # Top
			Vector2(star_size * 0.3, -star_size * 0.3),  # Top right
			Vector2(star_size, 0),       # Right
			Vector2(star_size * 0.3, star_size * 0.3),   # Bottom right
			Vector2(0, star_size),       # Bottom
			Vector2(-star_size * 0.3, star_size * 0.3),  # Bottom left
			Vector2(-star_size, 0),      # Left
			Vector2(-star_size * 0.3, -star_size * 0.3)  # Top left
		])
		
		star_layer_node.polygon = star_points
		
		# Calculate color and opacity for this layer
		var opacity = 1.0 - (i * 0.15)
		opacity = clamp(opacity, 0.0, 1.0)
		
		# Random star color variation (white to yellow to blue)
		var color_variation = randf()
		var star_color: Color
		if color_variation < 0.6:
			# White to yellow stars (most common)
			star_color = Color(1.0, 0.9 + randf_range(-0.1, 0.1), 0.7 + randf_range(-0.2, 0.2), opacity)
		elif color_variation < 0.8:
			# Blue-white stars
			star_color = Color(0.8 + randf_range(-0.1, 0.2), 0.9 + randf_range(-0.1, 0.1), 1.0, opacity)
		else:
			# Red-orange stars (rare)
			star_color = Color(1.0, 0.6 + randf_range(-0.1, 0.2), 0.4 + randf_range(-0.1, 0.1), opacity)
		
		star_layer_node.color = star_color
		star_layer_node.z_index = 0

func create_planet():
	# Create the planet with atmosphere and crescent shadow
	var planet_container = Node2D.new()
	planet_container.name = "Planet"
	planet_container.position = planet_center
	planet_layer.add_child(planet_container)
	
	# Create planet atmosphere (fuzzy edge like foreground objects)
	create_planet_atmosphere(planet_container)
	
	# Create the main planet body
	create_planet_body(planet_container)
	
	# Create the crescent shadow
	create_planet_crescent(planet_container)

func create_planet_atmosphere(container: Node2D):
	# Create fuzzy atmosphere around the planet with more layers and closer spacing
	var num_atmosphere_layers = 15 # More layers for smoother gradient
	
	for i in range(num_atmosphere_layers):
		var atmosphere_layer = Polygon2D.new()
		container.add_child(atmosphere_layer)
		
		# Calculate atmosphere radius (wider atmosphere with larger increments)
		var atmosphere_radius = planet_radius + (i * 3.5)  # 2 pixels per layer (wider spacing)
		
		# Create circle approximation with many points
		var atmosphere_points = PackedVector2Array()
		var num_points = 128  # Smooth circle
		for j in range(num_points):
			var angle = (j * 2 * PI) / num_points
			var point = Vector2(cos(angle) * atmosphere_radius, sin(angle) * atmosphere_radius)
			atmosphere_points.append(point)
		
		atmosphere_layer.polygon = atmosphere_points
		
		# Calculate opacity (smoother fade out with distance)
		var opacity = 0.4 - (i * 0.025)  # Higher initial opacity, slower fade
		opacity = clamp(opacity, 0.0, 0.4)
		
		# Blue atmosphere color
		var atmosphere_color = Color(0.4, 0.6, 1.0, opacity)
		atmosphere_layer.color = atmosphere_color
		atmosphere_layer.z_index = -25 - i - 20  # Behind planet body

func create_planet_body(container: Node2D):
	# Create the main planet body with marbled texture
	var planet_body = Polygon2D.new()
	container.add_child(planet_body)
	
	# Create circle approximation for planet
	var planet_points = PackedVector2Array()
	var num_points = 64  # Very smooth circle
	for i in range(num_points):
		var angle = (i * 2 * PI) / num_points
		var point = Vector2(cos(angle) * planet_radius, sin(angle) * planet_radius)
		planet_points.append(point)
	
	planet_body.polygon = planet_points
	
	# Create marbled blue planet color with noise pattern
	var base_color = Color(0.2, 0.4, 0.8)  # Blue base
	var marbled_color = create_marbled_color(base_color)
	planet_body.color = marbled_color
	planet_body.z_index = -25  # In front of atmosphere (same as planet layer)

func create_planet_crescent(container: Node2D):
	# Create the crescent shadow with feathered edges (multiple overlapping circles)
	var num_shadow_layers = 10  # Doubled for even smoother feathering
	
	# Calculate the direction from star to planet center
	var star_to_planet = planet_center - star_position
	var shadow_direction = star_to_planet.normalized()
	
	for layer in range(num_shadow_layers):
		var shadow_layer = Polygon2D.new()
		container.add_child(shadow_layer)
		
		# Create circle approximation for shadow
		var shadow_points = PackedVector2Array()
		var num_points = 64  # Smooth circle (matching update function)
		
		# Shadow circles get smaller as they move away from planet (opposite of atmosphere)
		var shadow_radius = planet_radius - (layer * 10.0)  # Gets smaller each layer
		shadow_radius = max(shadow_radius, planet_radius * 0.3)  # Don't go smaller than 30%
		
		# Shadow offset increases along the star-planet line, but on the opposite side of the planet from the star
		var shadow_offset = shadow_direction * (planet_radius * 0.05 + (layer * 8))  # Start very close to planet edge, more spaced out
		
		for i in range(num_points):
			var angle = (i * 2 * PI) / num_points
			var point = Vector2(cos(angle) * shadow_radius, sin(angle) * shadow_radius) + shadow_offset
			shadow_points.append(point)
		
		shadow_layer.polygon = shadow_points
		
		# Each shadow layer has higher opacity for better buildup to black
		var opacity = 0.2  # Higher opacity that builds up when overlapped
		
		# Black shadow color with consistent opacity
		var shadow_color = Color(0.0, 0.0, 0.0, opacity)
		shadow_layer.color = shadow_color
		shadow_layer.z_index = -25 + layer + 30  # In front of planet, layered shadow
		# Note: Polygon2D doesn't support blend_mode, using normal alpha blending
		shadow_layer.set_meta("is_shadow", true)  # Mark as shadow for dynamic updates

func update_planet_shadow():
	# Find the planet container and update shadow positions
	var planet_container = planet_layer.get_node_or_null("Planet")
	if not planet_container:
		return
	
	# Calculate the current direction from star to planet center
	# Star layer is stationary, planet layer moves
	var current_planet_center = get_planet_center()  # Get the actual world position of the planet
	var star_world_position = star_layer.position + star_position  # Get the actual world position of the star
	var star_to_planet = current_planet_center - star_world_position
	var shadow_direction = star_to_planet.normalized()
	
	# Update each shadow layer position
	var shadow_layers = []
	var shadow_count = 0
	for i in range(planet_container.get_child_count()):
		var child = planet_container.get_child(i)
		if child.get_meta("is_shadow", false):
			shadow_layers.append({"child": child, "index": shadow_count})
			shadow_count += 1
	
	# Update shadow layers with proper indexing
	for shadow_data in shadow_layers:
		var child = shadow_data.child
		var layer_index = shadow_data.index
		
		# Shadow circles get smaller as they move away from planet
		var shadow_radius = planet_radius - (layer_index * 3.0)
		shadow_radius = max(shadow_radius, planet_radius * 0.3)  # Don't go smaller than 30%
		
		# Shadow offset increases along the star-planet line, but on the opposite side of the planet from the star
		var shadow_offset = shadow_direction * (planet_radius * 0.05 + (layer_index * 8))
		
		# Update the shadow polygon points
		var shadow_points = PackedVector2Array()
		var num_points = 64
		
		for j in range(num_points):
			var angle = (j * 2 * PI) / num_points
			var point = Vector2(cos(angle) * shadow_radius, sin(angle) * shadow_radius) + shadow_offset
			shadow_points.append(point)
		
		child.polygon = shadow_points

func create_marbled_color(base_color: Color) -> Color:
	# Create a marbled effect using noise
	var noise_value = randf()  # Random noise value
	var marbled_color = base_color
	
	# Add some variation to create marbled effect
	marbled_color.r = clamp(base_color.r + (noise_value - 0.5) * 0.2, 0.0, 1.0)
	marbled_color.g = clamp(base_color.g + (noise_value - 0.5) * 0.15, 0.0, 1.0)
	marbled_color.b = clamp(base_color.b + (noise_value - 0.5) * 0.25, 0.0, 1.0)
	
	return marbled_color

func push_debris_from_explosion(explosion_pos: Vector2):
	var max_radius = 800.0  # Reduced from 1200.0 - smaller explosion radius
	var max_impulse = 1500.0  # Reduced from 6000.0 - much less dramatic explosion
	
	# Disable leftward force system globally
	if obstacle_generator and obstacle_generator.has_method("disable_leftward_force"):
		obstacle_generator.disable_leftward_force()
	
	# Push foreground debris (visual foreground layer)
	for debris in foreground_layer.get_children():
		if debris.has_meta("velocity"):
			var to_debris = debris.global_position - explosion_pos
			var dist = to_debris.length()
			if dist < max_radius:
				var strength = (1.0 - (dist / max_radius)) * max_impulse * 1.2  # Reduced from 2.5
				var impulse = to_debris.normalized() * strength
				var velocity = debris.get_meta("velocity")
				velocity += impulse / 80.0  # Increased from 35.0 - less dramatic effect
				debris.set_meta("velocity", velocity)
	

	
	# Push parallax debris layers (background layers)
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		var layer_distance_factor = 1.0 - (float(i) / float(parallax_layers.size()))
		for debris in layer.get_children():
			if debris.has_meta("velocity"):
				var to_debris = debris.global_position - explosion_pos
				var dist = to_debris.length()
				if dist < max_radius:
					var explosion_strength = (1.0 - (dist / max_radius)) * max_impulse
					var layer_strength = explosion_strength * layer_distance_factor
					var impulse = to_debris.normalized() * layer_strength
					var velocity = debris.get_meta("velocity")
					velocity += impulse / 100.0  # Increased from 40.0 - less dramatic effect
					debris.set_meta("velocity", velocity)
	
	# Push collision debris (active obstacles in obstacle_generator) - MUCH STRONGER
	if obstacle_generator and obstacle_generator.has_method("get") and obstacle_generator.get("active_obstacles"):
		var obstacles = obstacle_generator.active_obstacles
		for obstacle in obstacles:
			if not is_instance_valid(obstacle):
				continue
			if obstacle.has_method("get_global_position"):
				var to_obstacle = obstacle.global_position - explosion_pos
				var dist = to_obstacle.length()
				if dist < max_radius:
					var strength = (1.0 - (dist / max_radius)) * max_impulse * 2.0  # Reduced from 8.0
					var impulse = to_obstacle.normalized() * strength
					if obstacle.has_method("get") and obstacle.get("linear_velocity"):
						# Apply a more reasonable explosion push
						obstacle.linear_velocity += impulse / 25.0  # Increased from 8.0 - less dramatic effect
						# Mark obstacle as recently exploded to prevent leftward force override
						obstacle.set_meta("explosion_push_time", Time.get_ticks_msec())
						obstacle.set_meta("explosion_push_duration", 800.0)  # Reduced from 1000.0 - shorter effect





func regenerate_object_shape(object: Node2D, layer_index: int):
	# Regenerate the shape of a pooled object to ensure variety
	if not object.has_method("get_child") or object.get_child_count() < 2:
		return
	
	var size = object.get_meta("size", Vector2(50, 50))
	var _is_absolute_foreground = object.has_meta("is_absolute_foreground") and object.get_meta("is_absolute_foreground")
	var _is_foreground = object.has_meta("is_foreground") and object.get_meta("is_foreground")
	
	# Generate a new random shape
	var shape_type = randi() % 30  # 30 different shapes total
	var polygon_points = shape_generator.generate_complex_shape(shape_type, size)
	
	if layer_index == 0:  # Foreground layer
		# Foreground objects have a VisualContainer with multiple polygons
		var visual_container = object.get_child(1)
		if visual_container is Node2D and visual_container.name == "VisualContainer":
			# Clear existing polygons and recreate with new shape
			for child in visual_container.get_children():
				visual_container.remove_child(child)
				child.queue_free()
			
			# Recreate fuzzy shape with new polygon points
			var color = base_object_color.darkened(0.7)  # 70% darker for foreground
			create_fuzzy_shape(visual_container, polygon_points, color)
	else:  # Background layers
		# Background objects have a single visual polygon
		var visual_polygon = object.get_child(1)
		if visual_polygon is Polygon2D:
			visual_polygon.polygon = polygon_points

func create_shadow_overlay():
	# Create a shadow overlay that will darken debris when planet passes over star
	shadow_overlay = ColorRect.new()
	shadow_overlay.name = "ShadowOverlay"
	shadow_overlay.color = Color(0.0, 0.0, 0.0, 0.0)  # Start transparent
	shadow_overlay.size = screen_size * 2  # Make it larger to cover off-screen areas
	shadow_overlay.position = Vector2(-screen_size.x / 2, -screen_size.y / 2)  # Center it
	shadow_overlay.z_index = -5  # Between foreground and parallax layers
	shadow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	add_child(shadow_overlay)
	
	# Create debug label
	debug_label = Label.new()
	debug_label.name = "ShadowDebugLabel"
	debug_label.text = "Shadow: Inactive"
	debug_label.position = Vector2(10, 10)
	debug_label.z_index = 100  # On top of everything
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_font_size_override("font_size", 16)
	add_child(debug_label)

func update_shadow_overlay():
	# Check if planet is covering the star and update shadow accordingly
	# Calculate the distance from planet center to star center
	# Use simple world coordinates for distance calculation
	var planet_world_center = get_planet_center()
	var star_world_position = star_layer.position + star_position
	
	# Calculate distance in world coordinates
	var star_to_planet = planet_world_center - star_world_position
	var star_planet_distance = star_to_planet.x  # Use signed horizontal distance (negative when planet is past star)
	
	# Shadow detection: when planet is close enough to start covering the star
	var fade_in_start = 380.0  # Start fading in at 350 meters
	var max_darkness_distance = 330.0  # Maximum darkness at 280 meters
	var start_brightening = -340.0  # Start brightening at -340 meters
	var max_brightness_distance = -380.0  # Maximum brightness at -390 meters
	
	if star_planet_distance <= fade_in_start and star_planet_distance >= max_brightness_distance:
		# Calculate shadow intensity based on distance
		var target_intensity = 0.0
		
		if star_planet_distance <= start_brightening:
			# Planet is past the star - fade out (brightening)
			var fade_progress = (star_planet_distance - max_brightness_distance) / (start_brightening - max_brightness_distance)
			fade_progress = clamp(fade_progress, 0.0, 1.0)
			target_intensity = 0.95 * fade_progress  # 95% darkness at start_brightening, 0% at max_brightness
		else:
			# Planet is approaching or covering the star - fade in
			var fade_progress = (fade_in_start - star_planet_distance) / (fade_in_start - max_darkness_distance)
			fade_progress = clamp(fade_progress, 0.0, 1.0)
			target_intensity = 0.95 * fade_progress  # 0% darkness at fade_in_start, 95% at max_darkness
		
		# Smooth transition to target intensity over 3 seconds
		shadow_intensity = lerp(shadow_intensity, target_intensity, (1.0 / 3.0) * get_process_delta_time())
		
		# Update shadow status
		if shadow_intensity > 0.05:
			shadow_active = true
	else:
		# Planet is not covering the star - fade out shadow
		shadow_intensity = lerp(shadow_intensity, 0.0, (1.0 / 3.0) * get_process_delta_time())  # 3 second fade out
		
		if shadow_intensity < 0.05:
			shadow_active = false
			shadow_intensity = 0.0
	
	# Update debug label
	if debug_label:
		if shadow_active:
			debug_label.text = "Shadow: Active (%.1f%%) - Distance: %.1f" % [shadow_intensity * 100, star_planet_distance]
			debug_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			debug_label.text = "Shadow: Inactive - Distance: %.1f" % star_planet_distance
			debug_label.add_theme_color_override("font_color", Color.WHITE)

func apply_shadow_to_debris():
	# Apply shadow effect to ALL debris objects when shadow is active
	if not shadow_active or shadow_intensity < 0.1:
		# Clear shadow effects from all objects when shadow is inactive
		clear_shadow_from_all_objects()
		return
	
	# Debug: Print shadow status

	
	# Apply shadow to ALL foreground debris
	if foreground_layer:
		apply_shadow_to_all_objects_in_layer(foreground_layer)
	
	# Apply shadow to ALL parallax layers
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		apply_shadow_to_all_objects_in_layer(layer)
	
	# Apply shadow to ALL obstacles
	apply_shadow_to_all_obstacles()
	
	# Apply shadow to spaceship
	apply_shadow_to_spaceship()

func apply_shadow_to_all_objects_in_layer(layer: Node2D):
	# Apply shadow effect to ALL objects in a layer (no position checking)
	var _processed_objects = 0
	var _shadowed_objects = 0
	
	for object in layer.get_children():
		if not object.has_method("get_global_position"):
			continue
		
		_processed_objects += 1
		
		# Apply shadow to object's visual elements with full shadow intensity
		apply_shadow_to_object(object, shadow_intensity)
		_shadowed_objects += 1
	
	# Debug output removed for cleaner console

func apply_shadow_to_all_obstacles():
	# Apply shadow effect to ALL obstacles (no position checking)
	if not obstacle_generator:
		return
	
	# Check if active_obstacles property exists
	if not obstacle_generator.has_method("get") or not obstacle_generator.get("active_obstacles"):
		return
	
	var obstacles = obstacle_generator.active_obstacles
	
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		
		# Apply shadow to obstacle with full shadow intensity
		if obstacle.has_method("apply_shadow_effect"):
			obstacle.apply_shadow_effect(shadow_intensity)

func apply_shadow_to_spaceship():
	# Apply shadow effect to the spaceship
	var spaceship = get_node_or_null("/root/Main/GameWorld/Spaceship")
	if not spaceship:
		# Try alternative paths
		spaceship = get_node_or_null("/root/Main/Spaceship")
	
	if spaceship and spaceship.has_method("apply_shadow_effect"):
		spaceship.apply_shadow_effect(shadow_intensity)

func apply_shadow_to_obstacles(line_start: Vector2, line_end: Vector2, _line_direction: Vector2):
	# Apply shadow effect to obstacles from ObstacleGenerator
	if not obstacle_generator:
		return
	
	# Check if active_obstacles property exists
	if not obstacle_generator.has_method("get") or not obstacle_generator.get("active_obstacles"):
		return
	
	# Use dynamic shadow radius based on shadow intensity
	var current_shadow_radius = shadow_detection_radius * shadow_intensity
	
	var obstacles = obstacle_generator.active_obstacles
	
	var _shadowed_obstacles = 0
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		
		var obstacle_pos = obstacle.global_position
		
		# Calculate distance from obstacle to the star-planet line
		var distance_to_line = calculate_distance_to_line(obstacle_pos, line_start, line_end)
		
		# Check if obstacle is within shadow range
		if distance_to_line < current_shadow_radius:
			# Calculate shadow strength based on distance from line
			var shadow_strength = 1.0 - (distance_to_line / current_shadow_radius)
			shadow_strength = clamp(shadow_strength, 0.0, 1.0)
			
			# Apply shadow to obstacle
			if obstacle.has_method("apply_shadow_effect"):
				obstacle.apply_shadow_effect(shadow_strength * shadow_intensity)
				_shadowed_obstacles += 1
		else:
			# Clear shadow from obstacle if it's outside shadow range
			if obstacle.has_method("clear_shadow_effect"):
				obstacle.clear_shadow_effect()

func clear_shadow_from_all_objects():
	# Clear shadow effects from all objects when shadow is inactive
	# Clear from foreground debris
	clear_shadow_from_layer(foreground_layer)
	
	# Clear from all parallax layers
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		clear_shadow_from_layer(layer)
	
	# Clear from obstacles
	clear_shadow_from_obstacles()
	
	# Clear from spaceship
	clear_shadow_from_spaceship()

func clear_shadow_from_layer(layer: Node2D):
	# Clear shadow effects from all objects in a layer
	for object in layer.get_children():
		if not object.has_method("get_child") or object.get_child_count() < 2:
			continue
		
		var layer_index = object.get_meta("layer_index", 0)
		
		if layer_index == 0:  # Foreground layer
			# Foreground objects have Polygon2D children directly starting from index 1
			for i in range(1, object.get_child_count()):
				var child = object.get_child(i)
				if child is Polygon2D:
					clear_shadow_from_polygon(child)
		else:  # Background layers
			# Background objects have a single visual polygon
			var visual_polygon = object.get_child(1)
			if visual_polygon is Polygon2D:
				clear_shadow_from_polygon(visual_polygon)

func clear_shadow_from_polygon(polygon: Polygon2D):
	# Clear shadow effect from a polygon by resetting its color
	# Get the base color (original color without any effects)
	var base_color = polygon.get_meta("base_color", polygon.color)
	if not polygon.has_meta("base_color"):
		polygon.set_meta("base_color", polygon.color)
		base_color = polygon.color
	
	# Reset shadow factor to 1.0 (no shadow)
	polygon.set_meta("current_shadow_factor", 1.0)
	
	# Get the current brightness factor (if any flip effect is active)
	var brightness_factor = polygon.get_meta("current_brightness_factor", 1.0)
	
	# Calculate final color: base_color * brightness_factor (no shadow)
	var final_color = base_color
	final_color.r = clamp(base_color.r * brightness_factor, 0.0, 1.0)
	final_color.g = clamp(base_color.g * brightness_factor, 0.0, 1.0)
	final_color.b = clamp(base_color.b * brightness_factor, 0.0, 1.0)
	
	polygon.color = final_color

func clear_shadow_from_obstacles():
	# Clear shadow effects from obstacles
	if not obstacle_generator:
		return
	
	# Check if active_obstacles property exists
	if not obstacle_generator.has_method("get") or not obstacle_generator.get("active_obstacles"):
		return
	
	var obstacles = obstacle_generator.active_obstacles
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		
		if obstacle.has_method("clear_shadow_effect"):
			obstacle.clear_shadow_effect()

func clear_shadow_from_spaceship():
	# Clear shadow effects from spaceship
	var spaceship = get_node_or_null("/root/Main/GameWorld/Spaceship")
	if not spaceship:
		# Try alternative paths
		spaceship = get_node_or_null("/root/Main/Spaceship")
	
	if spaceship and spaceship.has_method("clear_shadow_effect"):
		spaceship.clear_shadow_effect()

func apply_shadow_to_layer(layer: Node2D, line_start: Vector2, line_end: Vector2, _line_direction: Vector2):
	# Apply shadow effect to all objects in a layer
	# Use dynamic shadow radius based on shadow intensity
	var current_shadow_radius = shadow_detection_radius * shadow_intensity
	
	var _processed_objects = 0
	var _shadowed_objects = 0
	
	for object in layer.get_children():
		if not object.has_method("get_global_position"):
			continue
		
		_processed_objects += 1
		var object_pos = object.global_position
		
		# Calculate distance from object to the star-planet line
		var distance_to_line = calculate_distance_to_line(object_pos, line_start, line_end)
		
		# Check if object is within shadow range
		if distance_to_line < current_shadow_radius:
			# Calculate shadow strength based on distance from line
			var shadow_strength = 1.0 - (distance_to_line / current_shadow_radius)
			shadow_strength = clamp(shadow_strength, 0.0, 1.0)
			
			# Apply shadow to object's visual elements
			apply_shadow_to_object(object, shadow_strength * shadow_intensity)
			_shadowed_objects += 1
		else:
			# Clear shadow from object if it's outside shadow range
			clear_shadow_from_object(object)
	


func calculate_distance_to_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	# Calculate the perpendicular distance from a point to a line segment
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	
	var line_length_sq = line_vec.length_squared()
	if line_length_sq == 0:
		return point_vec.length()
	
	var t = clamp(point_vec.dot(line_vec) / line_length_sq, 0.0, 1.0)
	var projection = line_start + t * line_vec
	
	return point.distance_to(projection)

func apply_shadow_to_object(object: Node2D, shadow_strength: float):
	# Apply shadow effect to an object's visual elements
	if not object.has_method("get_child") or object.get_child_count() < 2:
		return
	
	var layer_index = object.get_meta("layer_index", 0)
	
	if layer_index == 0:  # Foreground layer
		# Foreground objects have Polygon2D children directly (not in a VisualContainer)
		var _polygon_count = 0
		for i in range(1, object.get_child_count()):  # Start from child 1 (skip collision shape)
			var child = object.get_child(i)
			if child is Polygon2D:
				apply_shadow_to_polygon(child, shadow_strength)
				_polygon_count += 1
	else:  # Background layers
		# Background objects have a single visual polygon
		var visual_polygon = object.get_child(1)
		if visual_polygon is Polygon2D:
			apply_shadow_to_polygon(visual_polygon, shadow_strength)

func apply_shadow_to_polygon(polygon: Polygon2D, shadow_strength: float):
	# Apply shadow effect to a polygon by darkening its color
	# Store the base color if not already stored
	var base_color = polygon.get_meta("base_color", polygon.color)
	if not polygon.has_meta("base_color"):
		polygon.set_meta("base_color", polygon.color)
		base_color = polygon.color
	
	# Calculate shadow factor - much darker shadow effect
	var shadow_factor = 1.0 - (shadow_strength * 0.98)  # Max 98% darkness for very dramatic effect
	
	# Store the current shadow factor for the brightness system
	polygon.set_meta("current_shadow_factor", shadow_factor)
	
	# Get the current brightness factor (if any flip effect is active)
	var brightness_factor = polygon.get_meta("current_brightness_factor", 1.0)
	
	# Calculate final color: base_color * shadow_factor * brightness_factor
	var final_color = base_color
	final_color.r = clamp(base_color.r * shadow_factor * brightness_factor, 0.0, 1.0)
	final_color.g = clamp(base_color.g * shadow_factor * brightness_factor, 0.0, 1.0)
	final_color.b = clamp(base_color.b * shadow_factor * brightness_factor, 0.0, 1.0)
	
	polygon.color = final_color

func clear_shadow_from_object(object: Node2D):
	# Clear shadow effect from an object's visual elements
	if not object.has_method("get_child") or object.get_child_count() < 2:
		return
	
	var layer_index = object.get_meta("layer_index", 0)
	
	if layer_index == 0:  # Foreground layer
		# Foreground objects have Polygon2D children directly (not in a VisualContainer)
		for i in range(1, object.get_child_count()):  # Start from child 1 (skip collision shape)
			var child = object.get_child(i)
			if child is Polygon2D:
				clear_shadow_from_polygon(child)
	else:  # Background layers
		# Background objects have a single visual polygon
		var visual_polygon = object.get_child(1)
		if visual_polygon is Polygon2D:
			clear_shadow_from_polygon(visual_polygon)



# Simple function to generate new colors for restart
func generate_new_colors():
	# Pick a random base color for all debris
	var debris_hue = randf()  # Random hue
	var debris_saturation = randf_range(0.7, 0.9)  # High saturation
	var debris_value = randf_range(0.5, 0.7)  # Medium brightness
	base_object_color = Color.from_hsv(debris_hue, debris_saturation, debris_value)
	
	# Pick opposite color for ship (180 degrees opposite on color wheel)
	ship_color = Color.from_hsv(fmod(debris_hue + 0.5, 1.0), debris_saturation, debris_value)
	
	print("New colors generated - Debris: ", base_object_color, " Ship: ", ship_color)
	
	# Update ship color only (debris colors are set when objects are created)
	update_ship_color_simple()

# Function to generate new colors without updating objects (for reset)
func generate_new_colors_only():
	# Pick a random base color for all debris
	var debris_hue = randf()  # Random hue
	var debris_saturation = randf_range(0.7, 0.9)  # High saturation
	var debris_value = randf_range(0.5, 0.7)  # Medium brightness
	base_object_color = Color.from_hsv(debris_hue, debris_saturation, debris_value)
	
	# Pick opposite color for ship (180 degrees opposite on color wheel)
	ship_color = Color.from_hsv(fmod(debris_hue + 0.5, 1.0), debris_saturation, debris_value)
	
	print("New colors generated - Debris: ", base_object_color, " Ship: ", ship_color)



# Simple function to update ship color
func update_ship_color_simple():
	var spaceship = get_node_or_null("/root/Main/GameWorld/Player")
	if spaceship and spaceship.has_method("update_spaceship_color"):
		spaceship.update_spaceship_color()
		print("Ship color updated to: ", ship_color)

# Add a method to get the current debris color for obstacles
func get_debris_color() -> Color:
	return base_object_color

# Add a method to get the current ship color
func get_ship_color() -> Color:
	return ship_color

# Debug function to check all colors in the scene
func debug_check_colors():
	print("=== COLOR DEBUG ===")
	print("Current base_object_color: ", base_object_color)
	print("Current ship_color: ", ship_color)
	
	var color_count = {}
	
	# Check all active objects in parallax layers
	for i in range(parallax_layers.size()):
		var layer = parallax_layers[i]
		for object in layer.get_children():
			if object.get_child_count() >= 2:
				var visual_polygon = object.get_child(1)
				if visual_polygon is Polygon2D:
					var color_str = str(visual_polygon.color)
					color_count[color_str] = color_count.get(color_str, 0) + 1
	
	# Check foreground layer
	if foreground_layer:
		for object in foreground_layer.get_children():
			for i in range(1, object.get_child_count()):
				var child = object.get_child(i)
				if child is Polygon2D:
					var color_str = str(child.color)
					color_count[color_str] = color_count.get(color_str, 0) + 1
	
	# Check obstacle generator
	var obstacle_gen = get_node_or_null("/root/Main/GameWorld/ObstacleGenerator")
	if obstacle_gen and obstacle_gen.has_method("get") and obstacle_gen.get("active_obstacles"):
		for obstacle in obstacle_gen.active_obstacles:
			if is_instance_valid(obstacle) and obstacle.visual_polygon:
				var color_str = str(obstacle.visual_polygon.color)
				color_count[color_str] = color_count.get(color_str, 0) + 1
	
	print("Colors found in scene:")
	for color_str in color_count:
		print("  ", color_str, ": ", color_count[color_str], " objects")
	print("=== END COLOR DEBUG ===")
