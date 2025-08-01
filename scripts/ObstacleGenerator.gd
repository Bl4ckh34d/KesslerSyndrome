extends Node2D

@export var obstacle_scene: PackedScene
@export var base_speed: float = 100.0
@export var max_active_obstacles: int = 25
@export var min_obstacle_gap: float = 150.0
@export var max_obstacle_gap: float = 300.0
@export var min_obstacle_height: float = 80.0
@export var max_obstacle_height: float = 200.0
@export var base_difficulty: float = 1.0
@export var max_difficulty: float = 10.0
@export var difficulty_increase_rate: float = 0.5
@export var difficulty_check_interval: float = 10.0

# Simple physics-based system
var active_obstacles: Array = []
var obstacle_pool: Array = []
var pool_size: int = 30
var screen_width: float
var screen_height: float
var camera: Camera2D

# Fixed spawn and despawn zones (never move)
var spawn_zone_right: float
var despawn_zone_left: float

# Progressive difficulty
var current_difficulty: float = 1.0
var time_elapsed: float = 0.0
var last_difficulty_check: float = 0.0
var obstacle_spawn_timer: float = 0.0
var obstacle_spawn_interval: float = 1.5

# Global state for explosion aftermath
var leftward_force_disabled: bool = false

# Object pooling
# Enhanced obstacle types with more variety
enum ObstacleType {
	RECTANGLE,      # 0 - Simple rectangle
	TRIANGLE,       # 1 - Triangle
	DIAMOND,        # 2 - Diamond
	CROSS,          # 3 - Cross
	ELONGATED,      # 4 - Very long rectangle
	COMPACT,        # 5 - Square-like
	THIN_BEAM,      # 6 - Very thin beam
	THICK_CHUNK,    # 7 - Very thick chunk
	L_SHAPE,        # 8 - L-shaped piece
	T_SHAPE,        # 9 - T-shaped piece
	IRREGULAR       # 10 - Irregular polygon
}

func _ready():
	screen_width = get_viewport().get_visible_rect().size.x
	screen_height = get_viewport().get_visible_rect().size.y
	
	# Get camera reference
	camera = get_node_or_null("/root/Main/GameWorld/Camera2D")
	if not camera:
		camera = get_node_or_null("/root/Main/Camera2D")
	
	# Set up light mask for the obstacle layer container
	light_mask = 2  # Match the spotlight's light mask
	
	# Check if obstacle scene is loaded
	if not obstacle_scene:
		return
	
	# Set up fixed spawn and despawn zones with deferred call to ensure viewport is ready
	call_deferred("setup_fixed_zones")
	
	# Initialize object pool
	expand_pool(pool_size)
	
	# Start with no obstacles - they will spawn gradually over time
	# No longer call create_initial_obstacles()

func setup_fixed_zones():
	# Fixed spawn zone: 300 pixels to the right of screen (well outside view)
	spawn_zone_right = screen_width + 300
	
	# Fixed despawn zone: 1000 pixels to the left of screen (much further out)
	despawn_zone_left = -1000

func expand_pool(expansion_size: int):
	# Optimize pool expansion by creating objects in batches
	var batch_size = 5
	for batch in range(0, expansion_size, batch_size):
		var current_batch_size = min(batch_size, expansion_size - batch)
		for i in range(current_batch_size):
			var obstacle = obstacle_scene.instantiate()
			if not obstacle:
				continue
			
			# CRITICAL: Set safe position and ensure obstacle is completely hidden
			obstacle.position = Vector2(-2000, -2000)  # Far off-screen position
			obstacle.visible = false
			obstacle.set_physics_process(false)
			obstacle.set_process(false)
			
			# Disable physics and collision to prevent any interactions
			if obstacle.has_method("set_physics_enabled"):
				obstacle.set_physics_enabled(false)
			
			# CRITICAL: Set obstacle color to match current debris scheme
			var background_parallax = get_node_or_null("/root/Main/GameWorld/Background")
			if background_parallax and background_parallax.has_method("get_debris_color"):
				var unified_color = background_parallax.get_debris_color()
				obstacle.obstacle_color = unified_color
				obstacle.original_color = unified_color
				if obstacle.visual_polygon:
					obstacle.visual_polygon.color = unified_color
					obstacle.visual_polygon.set_meta("original_color", unified_color)
			
			# Add to scene tree but keep it hidden and inactive
			add_child(obstacle)
			obstacle_pool.append(obstacle)
	
	pool_size += expansion_size

func _process(delta):
	time_elapsed += delta
	
	# Update difficulty over time
	if time_elapsed - last_difficulty_check >= difficulty_check_interval:
		update_difficulty()
		last_difficulty_check = time_elapsed
	
	# Apply constant leftward force to all obstacles
	apply_leftward_force(delta)
	
	# Check for despawning (objects that have moved past the left zone)
	check_despawning()
	
	# Check for spawning (when we need more obstacles)
	check_spawning(delta)

func apply_leftward_force(_delta: float):
	# Skip leftward force if globally disabled (after explosion)
	if leftward_force_disabled:
		return
	
	# Apply varied leftward velocities to obstacles for more dynamic movement
	var current_base_speed: float = base_speed * (1.0 + time_elapsed / 120.0)
	var base_leftward_velocity: float = current_base_speed * 0.8
	base_leftward_velocity = max(base_leftward_velocity, base_speed * 0.3)
	
	for obstacle in active_obstacles:
		# CRITICAL: Check if obstacle is still valid
		if not is_instance_valid(obstacle):
			continue
		
		# Check if obstacle was recently hit by explosion push
		var explosion_push_time = obstacle.get_meta("explosion_push_time", 0)
		var explosion_push_duration = obstacle.get_meta("explosion_push_duration", 0.0)
		var current_time = Time.get_ticks_msec()
		
		# If obstacle was recently exploded, let it move freely in space (no friction, no leftward force)
		if explosion_push_time > 0 and (current_time - explosion_push_time) < explosion_push_duration:
			# No friction in space - obstacle moves freely with explosion momentum
			continue
		
		# Use stored velocity variation for consistent movement, or generate new one if not stored
		var velocity_variation = obstacle.get_meta("velocity_variation", randf_range(0.85, 1.15))
		var individual_velocity = base_leftward_velocity * velocity_variation
		
		# Set varied leftward velocity (not acceleration)
		obstacle.linear_velocity.x = -individual_velocity
		
		# Apply minimal drag to Y velocity (like parallax system)
		obstacle.linear_velocity.y *= 0.999

func check_despawning():
	# Remove obstacles that have moved past the despawn zone
	for i in range(active_obstacles.size() - 1, -1, -1):
		var obstacle = active_obstacles[i]
		
		# CRITICAL: Check if obstacle is still valid
		if not is_instance_valid(obstacle):
			active_obstacles.remove_at(i)
			continue
		
		if obstacle.position.x < despawn_zone_left:
			active_obstacles.remove_at(i)
			return_obstacle_to_pool(obstacle)

func check_spawning(delta: float):
	# Spawn new obstacles continuously like the parallax system
	obstacle_spawn_timer += delta
	
	# Find the rightmost obstacle
	var rightmost_x = -1000
	for obstacle in active_obstacles:
		rightmost_x = max(rightmost_x, obstacle.position.x)
	
	# Spawn obstacles when we need more (similar to parallax system)
	# Check if the rightmost object is getting close to the camera view OR if no obstacles exist
	if rightmost_x < screen_width + 100 or active_obstacles.size() == 0:
		# Spawn one obstacle at a time when timer is ready
		var current_max = get_current_max_obstacles()
		if obstacle_spawn_timer >= obstacle_spawn_interval and active_obstacles.size() < current_max:
			spawn_single_obstacle(spawn_zone_right + randf_range(-50, 50))
			obstacle_spawn_timer = 0.0

func spawn_single_obstacle(spawn_x: float):
	var obstacle = get_obstacle_from_pool()
	if not obstacle:
		return
	
	# Set up obstacle properties
	var height = randf_range(min_obstacle_height, max_obstacle_height)
	var config = get_obstacle_configuration()
	
	# Position the obstacle with better Y positioning (include center positions)
	var spawn_y = screen_height / 2
	var position_type = randi() % 3
	
	match position_type:
		0:  # Top
			spawn_y = height / 2 + randf_range(50, 150)
		1:  # Center
			spawn_y = screen_height / 2 + randf_range(-100, 100)
		2:  # Bottom
			spawn_y = screen_height - height / 2 - randf_range(50, 150)
	
	# CRITICAL: Ensure spawn position is ALWAYS well outside the screen to the right
	# Use the fixed spawn zone or fallback to a safe position
	var safe_spawn_x = spawn_zone_right
	if safe_spawn_x <= 0 or safe_spawn_x < screen_width:
		# Fallback to a safe position if spawn zone isn't set correctly
		safe_spawn_x = screen_width + 300
	
	# Add some randomization but keep it off-screen
	spawn_x = safe_spawn_x + randf_range(-50, 50)
	spawn_x = max(spawn_x, screen_width + 100)  # Never spawn closer than 100 pixels to screen edge
	
	obstacle.position = Vector2(spawn_x, spawn_y)
	obstacle.set_obstacle_rotation(config.rotation)
	obstacle.set_size(Vector2(config.width, config.height))
	obstacle.set_obstacle_type(config.type)
	obstacle.is_top_obstacle = config.is_top
	
	# Enable physics
	obstacle.set_physics_enabled(true)
	obstacle.set_collision_layer(2)  # Layer 2 for obstacles
	obstacle.set_collision_mask(3)   # Collide with player (layer 1) and other obstacles (layer 2)
	
	# Set z-index to be -3 (obstacle layer - moved one level deeper)
	obstacle.z_index = -3  # Obstacle layer (moved one level deeper)
	
	# Add initial velocity with variation for dynamic movement
	var base_velocity = base_speed * (1.0 + time_elapsed / 120.0) * 0.8
	var velocity_variation = randf_range(0.85, 1.15)
	var individual_velocity = base_velocity * velocity_variation
	obstacle.linear_velocity = Vector2(-individual_velocity, randf_range(-3, 3))
	
	# Store the velocity variation for consistent movement
	obstacle.set_meta("velocity_variation", velocity_variation)
	
	# Update obstacle color to match unified debris scheme
	var background_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	if background_parallax and background_parallax.has_method("get_debris_color"):
		var unified_color = background_parallax.get_debris_color()
		obstacle.obstacle_color = unified_color
		obstacle.original_color = unified_color
		if obstacle.visual_polygon:
			obstacle.visual_polygon.color = unified_color
			# Store the original color for shadow effects
			obstacle.visual_polygon.set_meta("original_color", unified_color)
	else:
		# Fallback: Use a default color if background parallax is not available
		var fallback_color = Color(0.8, 0.8, 0.8)  # Light gray
		obstacle.obstacle_color = fallback_color
		obstacle.original_color = fallback_color
		if obstacle.visual_polygon:
			obstacle.visual_polygon.color = fallback_color
			obstacle.visual_polygon.set_meta("original_color", fallback_color)
	

	
	# Update rotation speed based on current difficulty
	if obstacle.has_method("update_rotation_speed"):
		obstacle.update_rotation_speed()
	
	# Make sure obstacle is visible and active
	obstacle.visible = true
	obstacle.set_physics_process(true)
	obstacle.set_process(true)
	
	active_obstacles.append(obstacle)

func get_obstacle_from_pool() -> Node2D:
	if obstacle_pool.size() > 0:
		var obstacle = obstacle_pool.pop_back()
		
		# CRITICAL: Check if obstacle is still valid (not freed)
		if not is_instance_valid(obstacle):
			return get_obstacle_from_pool()
		
		# CRITICAL: Ensure obstacle is properly reset before use
		obstacle.visible = false  # Keep hidden until properly positioned
		obstacle.set_physics_process(false)
		obstacle.set_process(false)
		
		# Reset position to safe location
		obstacle.position = Vector2(-2000, -2000)
		obstacle.linear_velocity = Vector2.ZERO
		
		# Color is set when obstacle is created, no update needed
		
		# CRITICAL: Add obstacle back to scene tree if it was removed
		if not obstacle.get_parent():
			add_child(obstacle)
		
		return obstacle
	else:
		# Expand pool if needed
		expand_pool(10)
		return get_obstacle_from_pool()

func return_obstacle_to_pool(obstacle: Node2D):
	# CRITICAL: Check if obstacle is still valid before returning to pool
	if not is_instance_valid(obstacle):
		return
	
	# Remove obstacle from scene tree to prevent collisions
	if obstacle.get_parent():
		obstacle.get_parent().remove_child(obstacle)
	
	obstacle.visible = false
	obstacle.set_physics_enabled(false)
	obstacle.position = Vector2.ZERO
	obstacle.linear_velocity = Vector2.ZERO
	obstacle_pool.append(obstacle)

func get_obstacle_configuration() -> Dictionary:
	var max_rotation = min(PI/2, (current_difficulty / max_difficulty) * PI/2)
	
	# Randomly select obstacle type with varied distribution (CONVEX ONLY)
	var type_roll = randf()
	var obstacle_type = ObstacleType.RECTANGLE
	
	if type_roll < 0.20:
		obstacle_type = ObstacleType.RECTANGLE
	elif type_roll < 0.35:
		obstacle_type = ObstacleType.TRIANGLE
	elif type_roll < 0.45:
		obstacle_type = ObstacleType.DIAMOND
	elif type_roll < 0.60:
		obstacle_type = ObstacleType.ELONGATED
	elif type_roll < 0.75:
		obstacle_type = ObstacleType.COMPACT
	elif type_roll < 0.85:
		obstacle_type = ObstacleType.THIN_BEAM
	else:
		obstacle_type = ObstacleType.THICK_CHUNK
	
	# Generate varied sizes based on obstacle type
	var base_width = 50.0
	var base_height = 50.0
	
	match obstacle_type:
		ObstacleType.ELONGATED:
			base_width = randf_range(80.0, 150.0)
			base_height = randf_range(20.0, 40.0)
		ObstacleType.COMPACT:
			base_width = randf_range(30.0, 60.0)
			base_height = randf_range(30.0, 60.0)
		ObstacleType.THIN_BEAM:
			base_width = randf_range(100.0, 200.0)
			base_height = randf_range(8.0, 15.0)
		ObstacleType.THICK_CHUNK:
			base_width = randf_range(40.0, 80.0)
			base_height = randf_range(80.0, 120.0)
		ObstacleType.L_SHAPE, ObstacleType.T_SHAPE:
			base_width = randf_range(60.0, 100.0)
			base_height = randf_range(60.0, 100.0)
		ObstacleType.IRREGULAR:
			base_width = randf_range(50.0, 120.0)
			base_height = randf_range(50.0, 120.0)
		_:  # Default shapes
			base_width = randf_range(40.0, 80.0)
			base_height = randf_range(40.0, 80.0)
	
	return {
		"is_top": randi() % 2 == 0,
		"rotation": randf_range(-max_rotation, max_rotation),
		"width": base_width,
		"height": base_height,
		"type": obstacle_type
	}

func update_difficulty():
	current_difficulty = min(max_difficulty, base_difficulty + (time_elapsed / 120.0) * difficulty_increase_rate)

func get_current_max_obstacles() -> int:
	# Increase max obstacles over time
	var base_max = 15
	var max_increase = 20
	var time_factor = min(time_elapsed / 300.0, 1.0)
	return base_max + int(max_increase * time_factor)

func create_initial_obstacles():
	# Create initial obstacles outside screen to the right for safety
	for i in range(10):
		var spawn_x = screen_width + 150 + (i * 80)
		spawn_single_obstacle(spawn_x)
	
	# Force enable processing to ensure obstacles are active
	set_process(true)
	set_physics_process(true)

func reset():
	# AGGRESSIVE: Free all active obstacles instead of returning to pool
	for obstacle in active_obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	active_obstacles.clear()
	
	# Force clear any remaining obstacles
	force_clear_all_obstacles()
	
	# AGGRESSIVE: Free all obstacles in pool and clear it completely
	for obstacle in obstacle_pool:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacle_pool.clear()
	
	# Reset variables
	current_difficulty = base_difficulty
	time_elapsed = 0.0
	last_difficulty_check = 0.0
	obstacle_spawn_timer = 0.0
	
	# Reset base speed to original value
	base_speed = 100.0
	
	# Re-enable leftward force system
	leftward_force_disabled = false
	
	# CRITICAL: Reinitialize the object pool with fresh obstacles
	# This ensures new obstacles are created with the current color scheme
	if obstacle_scene:
		expand_pool(pool_size)
	
	# Ensure physics system is active
	set_physics_process(true)
	set_process(true)
	
	# Force multiple frames to ensure everything is reset
	await get_tree().process_frame
	await get_tree().process_frame
	
	# CRITICAL FIX: Force spawn initial obstacles after reset
	# This ensures obstacles are present immediately after restart
	call_deferred("force_spawn_initial_obstacles")
	
	# Obstacle color updates removed

# Add a new function to force spawn initial obstacles after reset
func force_spawn_initial_obstacles():
	print("Force spawning initial obstacles after reset...")
	
	# Spawn a few obstacles immediately to ensure they're present
	var initial_count = 5
	for i in range(initial_count):
		var spawn_x = spawn_zone_right + (i * 100)  # Space them out
		spawn_single_obstacle(spawn_x)
	
	print("Spawned ", initial_count, " initial obstacles")
	
	# Verify obstacles are spawning correctly
	await get_tree().process_frame
	print("Active obstacles after force spawn: ", active_obstacles.size())

func disable_leftward_force():
	# Disable leftward force system after explosion
	leftward_force_disabled = true

func force_clear_all_obstacles():
	# Aggressively clear ALL obstacle children from scene tree, regardless of position or state
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child.has_method("set_physics_enabled") or child.has_method("set_obstacle_rotation"):
			# Force remove from scene tree and free
			if child.get_parent():
				child.get_parent().remove_child(child)
			child.queue_free()
	
	# Also clear any obstacles that might be in the active list but not in scene tree
	for i in range(active_obstacles.size() - 1, -1, -1):
		var obstacle = active_obstacles[i]
		if not is_instance_valid(obstacle):
			active_obstacles.remove_at(i)
		elif obstacle.get_parent() != self:
			# Obstacle is not a child of this node, remove it from active list
			active_obstacles.remove_at(i)

# OBSOLETE: This function is no longer needed since we destroy all objects on reset
# Colors are now set when objects are created, not updated later
func force_update_all_obstacle_colors():
	print("OBSOLETE: force_update_all_obstacle_colors() called - no longer needed")
	pass
