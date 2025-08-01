extends RigidBody2D

@export var obstacle_color: Color = Color.WHITE  # Will be set to unified debris color

var collision_shape: CollisionShape2D
var visual_polygon: Polygon2D
var is_top_obstacle: bool = false
var original_color: Color  # Store original color for shadow effects

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
var obstacle_type: int = 0

# 0-G Physics variables
var size: Vector2 = Vector2.ZERO
var is_physics_enabled: bool = true

# Physics constants
const GRAVITY: float = 0.0
const DRAG: float = 0.999
const ANGULAR_DRAG: float = 0.999
const MIN_ROTATION_SPEED: float = 2.0
const MAX_ROTATION_SPEED: float = 25.0
const COLLISION_DAMPING: float = 0.95
const LEFTWARD_FORCE: float = 50.0

func _ready():
	collision_shape = $CollisionShape2D
	visual_polygon = $Polygon2D
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Get the unified debris color from the centralized color management system
	var background_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	if background_parallax and background_parallax.has_method("get_debris_color"):
		obstacle_color = background_parallax.get_debris_color()
		original_color = obstacle_color
	else:
		# Fallback to old system if color manager not available
		if background_parallax and background_parallax.has_method("get_base_object_color"):
			obstacle_color = background_parallax.get_base_object_color()
			original_color = obstacle_color
		else:
			obstacle_color = Color(0.2, 0.6, 1.0)  # Default blue
			original_color = obstacle_color
	
	# Set visual appearance
	if visual_polygon:
		visual_polygon.color = obstacle_color
		# Store the original color for shadow effects
		visual_polygon.set_meta("original_color", obstacle_color)
	else:
		return
	
	# Initialize rotation speed based on current difficulty
	update_rotation_speed()
	
	# Set up RigidBody2D for zero gravity physics
	gravity_scale = 0.0
	mass = 1.0
	
	# Configure physics for space-like behavior
	linear_damp = 0.0
	angular_damp = 0.0
	
	# Set collision mode to continuous for better collision detection
	contact_monitor = true
	max_contacts_reported = 4
	
	# Set up collision layers for obstacle-player interaction
	set_collision_layer(2)  # Obstacle layer
	set_collision_mask(1)   # Collide with player layer (layer 1)
	
	# Set up lighting - make obstacles visible to Light2D
	light_mask = 2  # Match the spotlight's light mask
	
	# Also set light mask on the visual polygon
	if visual_polygon:
		visual_polygon.light_mask = 2

func _physics_process(_delta):
	if not is_physics_enabled:
		return
	
	# Apply minimal drag to prevent math from going crazy
	linear_velocity *= DRAG
	angular_velocity *= ANGULAR_DRAG
	
	# Ensure endless spinning by maintaining minimum angular velocity
	if abs(angular_velocity) < 0.1:
		angular_velocity = 0.1 if angular_velocity >= 0 else -0.1
	
	# Keep rotation within reasonable bounds (optional)
	if rotation > PI * 4:
		rotation -= PI * 2
	elif rotation < -PI * 4:
		rotation += PI * 2

func apply_external_force(force: Vector2):
	# Apply force to the obstacle (called by ObstacleGenerator)
	linear_velocity += force

func set_size(new_size: Vector2):
	self.size = new_size
	# Calculate mass based on area (x * y)
	mass = size.x * size.y / 100.0
	
	# Create collision shape that matches the visual polygon
	update_collision_shape(size)
	
	# Set visual polygon based on obstacle type
	if visual_polygon:
		visual_polygon.polygon = get_polygon_for_type(size)
		# Obstacle color update removed
	else:
		return

func update_collision_shape(new_size: Vector2):
	if collision_shape:
		# Create polygon collision shape that matches the visual shape
		var polygon_points = get_polygon_for_type(new_size)
		
		# Check if the polygon is convex or concave
		var is_convex = is_polygon_convex(polygon_points)
		
		if is_convex:
			var polygon_shape = ConvexPolygonShape2D.new()
			polygon_shape.points = polygon_points
			collision_shape.shape = polygon_shape
		else:
			var polygon_shape = ConcavePolygonShape2D.new()
			# ConcavePolygonShape2D uses segments, not points
			# Convert polygon points to segments
			var segments = PackedVector2Array()
			for i in range(polygon_points.size()):
				var p1 = polygon_points[i]
				var p2 = polygon_points[(i + 1) % polygon_points.size()]
				segments.append(p1)
				segments.append(p2)
			polygon_shape.segments = segments
			collision_shape.shape = polygon_shape

func is_polygon_convex(points: PackedVector2Array) -> bool:
	# Check if a polygon is convex by examining the cross products of consecutive edges
	if points.size() < 3:
		return true  # Degenerate polygons are considered convex
	
	var n = points.size()
	var first_sign = 0
	
	for i in range(n):
		var p1 = points[i]
		var p2 = points[(i + 1) % n]
		var p3 = points[(i + 2) % n]
		
		# Calculate cross product of two consecutive edges
		var edge1 = p2 - p1
		var edge2 = p3 - p2
		var cross_product = edge1.x * edge2.y - edge1.y * edge2.x
		
		# If cross product changes sign, polygon is concave
		if i == 0:
			first_sign = sign(cross_product)
		elif sign(cross_product) != first_sign:
			return false
	
	return true

# Obstacle color update function removed

func apply_shadow_effect(shadow_strength: float):
	# Apply shadow effect to the obstacle visual
	if visual_polygon:
		# Store original color if not already stored
		if not visual_polygon.has_meta("original_color"):
			visual_polygon.set_meta("original_color", visual_polygon.color)
		
		var stored_original_color = visual_polygon.get_meta("original_color")
		
		# Calculate shadowed color - much darker shadow effect
		var shadow_factor = 1.0 - (shadow_strength * 0.98)  # Max 98% darkness for very dramatic effect
		var shadowed_color = Color(
			stored_original_color.r * shadow_factor,
			stored_original_color.g * shadow_factor,
			stored_original_color.b * shadow_factor,
			stored_original_color.a
		)
		
		visual_polygon.color = shadowed_color
		
func clear_shadow_effect():
	# Clear shadow effect and restore original color
	if not visual_polygon:
		return
	
	# Use original color if not set
	if original_color == Color():
		original_color = obstacle_color
	
	visual_polygon.color = original_color

func illuminate(illumination_strength: float):
	# Illuminate the obstacle by brightening its visual
	if not visual_polygon:
		return
	
	# Store original color if not already stored
	if not visual_polygon.has_meta("original_color"):
		visual_polygon.set_meta("original_color", visual_polygon.color)
	
	var stored_original_color = visual_polygon.get_meta("original_color")
	
	# Calculate illuminated color (brighten the object)
	var brightness_boost = illumination_strength * 0.6  # Max 60% brightness increase
	var illuminated_color = Color(
		clamp(stored_original_color.r + brightness_boost, 0.0, 1.0),
		clamp(stored_original_color.g + brightness_boost, 0.0, 1.0),
		clamp(stored_original_color.b + brightness_boost, 0.0, 1.0),
		stored_original_color.a
	)
	
	visual_polygon.color = illuminated_color

func clear_illumination():
	# Clear illumination and restore original color
	if not visual_polygon:
		return
	
	# Restore original color
	if visual_polygon.has_meta("original_color"):
		visual_polygon.color = visual_polygon.get_meta("original_color")
	else:
		visual_polygon.color = original_color

func set_obstacle_type(type: int):
	obstacle_type = type
	# Obstacle color update removed

func handle_collision(other_obstacle):
	if not is_physics_enabled or not other_obstacle.is_physics_enabled:
		return
	
	# Store original leftward velocities before collision
	var original_left_velocity_self = linear_velocity.x
	var original_left_velocity_other = other_obstacle.linear_velocity.x
	
	# Calculate collision response
	var relative_velocity = linear_velocity - other_obstacle.linear_velocity
	var collision_normal = (position - other_obstacle.position).normalized()
	
	# Calculate impulse with inertia limits
	var relative_speed = relative_velocity.dot(collision_normal)
	if relative_speed > 0:
		return
	
	var impulse = -(1 + COLLISION_DAMPING) * relative_speed
	impulse /= 1/mass + 1/other_obstacle.mass
	
	# Limit impulse to prevent extreme values and flickering
	var max_impulse = 100.0
	impulse = clamp(impulse, -max_impulse, max_impulse)
	
	# Apply impulse with interpolation to smooth out changes
	var impulse_vector = impulse * collision_normal
	linear_velocity += impulse_vector / mass
	other_obstacle.linear_velocity -= impulse_vector / other_obstacle.mass
	
	# Separate objects to prevent sticking (more aggressive separation)
	var separation_distance = (self.size.length() + other_obstacle.size.length()) * 0.8
	var current_distance = position.distance_to(other_obstacle.position)
	if current_distance < separation_distance:
		var separation_vector = collision_normal * (separation_distance - current_distance) * 1.5
		position += separation_vector
		other_obstacle.position -= separation_vector
		
		# Add extra separation in the vertical direction to prevent stacking
		var vertical_separation = Vector2(0, randf_range(-30, 30))
		position += vertical_separation
		other_obstacle.position -= vertical_separation
	
	# Preserve the primary leftward momentum while allowing some collision response
	# Use a weighted average to maintain leftward movement (like parallax system)
	var leftward_weight = 0.95
	var collision_weight = 0.05
	
	linear_velocity.x = (original_left_velocity_self * leftward_weight) + (linear_velocity.x * collision_weight)
	other_obstacle.linear_velocity.x = (original_left_velocity_other * leftward_weight) + (other_obstacle.linear_velocity.x * collision_weight)
	
	# Limit velocity extremes to prevent flickering
	var max_velocity = 300.0
	linear_velocity = linear_velocity.limit_length(max_velocity)
	other_obstacle.linear_velocity = other_obstacle.linear_velocity.limit_length(max_velocity)
	
	# Add small random vertical movement to prevent stacking
	linear_velocity.y += randf_range(-10, 10)
	other_obstacle.linear_velocity.y += randf_range(-10, 10)

func set_physics_enabled(enabled: bool):
	is_physics_enabled = enabled

func update_rotation_speed():
	# Calculate current rotation speed based on time elapsed
	var time_elapsed = 0.0
	
	# Only try to get time elapsed if we're in the scene tree
	if is_inside_tree():
		var obstacle_generator = get_node_or_null("/root/Main/GameWorld/ObstacleGenerator")
		if obstacle_generator:
			time_elapsed = obstacle_generator.time_elapsed
	
	# Progressive difficulty: rotation speed increases over time with much faster early progression
	var difficulty_factor = min(time_elapsed / 60.0, 1.0)
	
	# Use exponential curve for very fast early progression
	var curve_factor = pow(difficulty_factor, 0.5)
	
	var current_min_rotation = MIN_ROTATION_SPEED
	var current_max_rotation = MIN_ROTATION_SPEED + (MAX_ROTATION_SPEED - MIN_ROTATION_SPEED) * curve_factor
	
	# Set random rotation speed within current range
	angular_velocity = randf_range(current_min_rotation, current_max_rotation)
	if randf() < 0.5:
		angular_velocity = -angular_velocity

func get_polygon_for_type(new_size: Vector2) -> PackedVector2Array:
	var half_size = new_size / 2
	
	match obstacle_type:
		ObstacleType.RECTANGLE:  # Simple rectangle
			return PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x, half_size.y)
			])
		ObstacleType.TRIANGLE:  # Triangle
			return PackedVector2Array([
				Vector2(0, -half_size.y),
				Vector2(-half_size.x, half_size.y),
				Vector2(half_size.x, half_size.y)
			])
		ObstacleType.DIAMOND:  # Diamond
			return PackedVector2Array([
				Vector2(0, -half_size.y),
				Vector2(half_size.x, 0),
				Vector2(0, half_size.y),
				Vector2(-half_size.x, 0)
			])
		ObstacleType.CROSS:  # Cross
			var cross_width = half_size.x * 0.3
			var cross_height = half_size.y * 0.3
			return PackedVector2Array([
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
				Vector2(-half_size.x, -cross_height)
			])
		ObstacleType.ELONGATED:  # Very long rectangle
			return PackedVector2Array([
				Vector2(-half_size.x * 2.5, -half_size.y * 0.4),
				Vector2(half_size.x * 2.5, -half_size.y * 0.4),
				Vector2(half_size.x * 2.5, half_size.y * 0.4),
				Vector2(-half_size.x * 2.5, half_size.y * 0.4)
			])
		ObstacleType.COMPACT:  # Square-like
			return PackedVector2Array([
				Vector2(-half_size.x * 0.8, -half_size.y * 0.8),
				Vector2(half_size.x * 0.8, -half_size.y * 0.8),
				Vector2(half_size.x * 0.8, half_size.y * 0.8),
				Vector2(-half_size.x * 0.8, half_size.y * 0.8)
			])
		ObstacleType.THIN_BEAM:  # Very thin beam
			return PackedVector2Array([
				Vector2(-half_size.x * 3.0, -half_size.y * 0.2),
				Vector2(half_size.x * 3.0, -half_size.y * 0.2),
				Vector2(half_size.x * 3.0, half_size.y * 0.2),
				Vector2(-half_size.x * 3.0, half_size.y * 0.2)
			])
		ObstacleType.THICK_CHUNK:  # Very thick chunk
			return PackedVector2Array([
				Vector2(-half_size.x * 0.6, -half_size.y * 1.8),
				Vector2(half_size.x * 0.6, -half_size.y * 1.8),
				Vector2(half_size.x * 0.6, half_size.y * 1.8),
				Vector2(-half_size.x * 0.6, half_size.y * 1.8)
			])
		ObstacleType.L_SHAPE:  # L-shaped piece
			return PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x * 0.3, -half_size.y),
				Vector2(half_size.x * 0.3, -half_size.y * 0.3),
				Vector2(half_size.x, -half_size.y * 0.3),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x, half_size.y)
			])
		ObstacleType.T_SHAPE:  # T-shaped piece
			return PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y * 0.3),
				Vector2(half_size.x * 0.3, -half_size.y * 0.3),
				Vector2(half_size.x * 0.3, half_size.y),
				Vector2(-half_size.x * 0.3, half_size.y),
				Vector2(-half_size.x * 0.3, -half_size.y * 0.3),
				Vector2(-half_size.x, -half_size.y * 0.3)
			])
		ObstacleType.IRREGULAR:  # Irregular polygon
			return PackedVector2Array([
				Vector2(-half_size.x * 0.8, -half_size.y * 1.2),
				Vector2(half_size.x * 0.4, -half_size.y * 0.9),
				Vector2(half_size.x * 1.1, -half_size.y * 0.3),
				Vector2(half_size.x * 0.7, half_size.y * 0.6),
				Vector2(half_size.x * 0.2, half_size.y * 1.1),
				Vector2(-half_size.x * 0.3, half_size.y * 0.8),
				Vector2(-half_size.x * 1.0, half_size.y * 0.4),
				Vector2(-half_size.x * 0.6, -half_size.y * 0.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x, half_size.y)
			])

func set_obstacle_rotation(angle: float):
	rotation = angle

func _on_body_entered(body: Node2D):
	print("Obstacle body_entered signal triggered with: ", body.name, " (", body.get_class(), ")")
	print("Body has handle_collision method: ", body.has_method("handle_collision"))
	print("Body is in player group: ", body.is_in_group("player"))
	
	# Check if this is the player (spaceship)
	if body.has_method("handle_collision") and body.is_in_group("player"):
		print("Obstacle detected collision with player!")
		# Calculate collision velocity for intensity determination
		var collision_velocity = body.velocity.length() if body.has_method("get") and body.get("velocity") else 100.0
		print("Collision velocity: ", collision_velocity)
		body.handle_collision(collision_velocity)
		return
	
	# Check if this is another obstacle with physics
	if body.has_method("handle_collision") and body.has_method("set_physics_enabled"):
		# Handle collision with another obstacle
		handle_collision(body)
