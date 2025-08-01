extends CharacterBody2D

@export var speed: float = 300.0
@export var vertical_speed: float = 1000.0  # Increased from 600.0 for more acceleration
@export var horizontal_speed: float = 600.0  # Matched to debris leftward speed
@export var max_vertical_speed: float = 1200.0  # Increased from 700.0
@export var max_horizontal_speed: float = 1000.0  # Increased from 400.0
@export var gravity: float = 800.0  # Increased for more noticeable effect
@export var drag: float = 0.95
@export var screen_boundary: float = 15.0
@export var max_rotation_angle: float = 25.0  # Increased from 15.0 - more dramatic rotation
@export var rotation_speed: float = 8.0  # Increased from 5.0 - faster rotation response

# Spotlight system
@export var spotlight_range: float = 250.0  # How far the spotlight reaches (increased by 25%)
@export var spotlight_angle: float = 60.0  # Angle of the light cone in degrees
@export var spotlight_intensity: float = 100.0  # How bright the spotlight is (doubled for much stronger effect)
@export var spotlight_color: Color = Color(1.0, 0.95, 0.8, 1.0)  # Warm white light (full alpha for Light2D)

var collision_shape: CollisionShape2D
var engine_sound: AudioStreamPlayer
var explosion_sound: AudioStreamPlayer
var spaceship_visual: Polygon2D
var exhaust_jet: Polygon2D

# Spotlight components
var spotlight: Light2D
var spotlight_active: bool = false
var background_parallax: Node

var is_dead: bool = false
var is_colliding: bool = false  # New state for collision sequence
var controls_disabled: bool = false  # Flag to disable player controls
var collision_timer: float = 0.0
var collision_duration: float = 0.0
var out_of_control_timer: float = 0.0
var out_of_control_duration: float = 0.0
var target_direction: Vector2 = Vector2.ZERO
var current_direction: Vector2 = Vector2.ZERO
var collision_particles: Node2D
var smoke_particles: Node2D
var bounce_velocity: Vector2 = Vector2.ZERO  # Store bounce velocity

# Health system
var max_health: int = 3
var current_health: int = 3
var health_stage: int = 3  # 3 = healthy, 2 = damaged (smoke), 1 = critical (constant smoke), 0 = dead

# Speed reduction system
var speed_reduction_factor: float = 1.0  # 1.0 = full speed, 0.75 = 75% speed, 0.5 = 50% speed
var original_vertical_speed: float
var original_horizontal_speed: float

# Particle pooling system
var spark_pool: Array[Polygon2D] = []
var smoke_pool: Array[Polygon2D] = []
var max_pool_size: int = 100  # Maximum particles in each pool

# Continuous emission timers
var spark_emission_timer: float = 0.0
var spark_emission_interval: float = 0.0  # Will be set dynamically
var smoke_emission_timer: float = 0.0
var smoke_emission_interval: float = 0.5  # Emit smoke every 0.5 seconds when critical
var distance: float = 0.0
var exhaust_timer: float = 0.0
var exhaust_scale: float = 1.0
var target_rotation: float = 0.0  # Target rotation angle
var current_rotation: float = 0.0  # Current rotation angle
var boundaries_enabled: bool = true  # Control whether screen boundaries are active



func _ready():
	# Add to player group for obstacle generator to find
	add_to_group("player")
	
	collision_shape = $CollisionShape2D
	engine_sound = $EngineSound
	explosion_sound = $ExplosionSound
	spaceship_visual = $SpaceshipVisual
	exhaust_jet = $ExhaustJet
	
	# Get background parallax reference for shadow detection
	background_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	
	# Set up collision layers
	set_collision_layer(1)  # Player layer
	set_collision_mask(2)   # Collide with obstacle layer (layer 2)
	
	# Set z-index to be -1 (player spaceship - moved one level higher)
	z_index = -1  # Player spaceship layer (moved one level higher)
	
	# Create triangle-shaped spaceship
	create_triangle_spaceship()
	
	# Set up collision shape to match visual triangle
	setup_collision_shape()
	
	# Create teardrop-shaped exhaust jet
	create_exhaust_jet()
	
	# Create spotlight
	create_spotlight()
	
	# Start engine sound
	if engine_sound:
		engine_sound.play()
	
	# Ensure we start in a safe position
	position = Vector2(100, get_viewport().get_visible_rect().size.y / 2)
	
	# Store original speeds for speed reduction system
	original_vertical_speed = vertical_speed
	original_horizontal_speed = horizontal_speed
	
	# Spaceship color updates removed

func create_triangle_spaceship():
	if spaceship_visual:
		# Create triangle points (pointing right)
		var triangle_points = PackedVector2Array([
			Vector2(20, 0),    # Front point (right)
			Vector2(-15, -12), # Top back
			Vector2(-15, 12)   # Bottom back
		])
		spaceship_visual.polygon = triangle_points
		
		# Generate spaceship color: 90 degrees away from base color with strong saturation
		var spaceship_color = generate_spaceship_color()
		spaceship_visual.color = spaceship_color

func setup_collision_shape():
	# Set up collision shape to match the visual triangle
	if collision_shape:
		print("Setting up collision shape...")
		# Create collision shape that matches the visual triangle
		var collision_points = PackedVector2Array([
			Vector2(20, 0),    # Front point (right)
			Vector2(-15, -12), # Top back
			Vector2(-15, 12)   # Bottom back
		])
		
		# Create a ConvexPolygonShape2D for the triangle
		var shape = ConvexPolygonShape2D.new()
		shape.points = collision_points
		collision_shape.shape = shape
		
		print("Collision shape set up to match visual triangle")
		print("Collision points: ", collision_points)
		print("Collision shape enabled: ", collision_shape.disabled)
		print("Collision layer: ", collision_layer)
		print("Collision mask: ", collision_mask)
	else:
		print("ERROR: CollisionShape2D node not found!")

func generate_spaceship_color() -> Color:
	# SIMPLIFIED: Get the ship color from the background parallax system
	var ship_color = Color(0.2, 0.6, 1.0)  # Default blue if not found
	
	# Try to get the ship color from the background parallax system
	var bg_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	if bg_parallax and bg_parallax.has_method("get_ship_color"):
		ship_color = bg_parallax.get_ship_color()
	elif bg_parallax and bg_parallax.has_method("get") and bg_parallax.get("ship_color"):
		ship_color = bg_parallax.ship_color
	
	return ship_color

func update_spaceship_color():
	# Update spaceship color to match current debris color (opposite on color wheel)
	if spaceship_visual:
		var spaceship_color = generate_spaceship_color()
		spaceship_visual.color = spaceship_color
		print("Spaceship color updated to: ", spaceship_color)

func create_exhaust_jet():
	if exhaust_jet:
		# Clear any existing children (halo layers)
		for child in exhaust_jet.get_children():
			child.queue_free()
		
		# Create centered teardrop shape for main exhaust
		var exhaust_points = PackedVector2Array([
			Vector2(-10, -5),   # Top of teardrop (centered)
			Vector2(-30, 0),    # Back point of teardrop (extends backward)
			Vector2(-10, 5)     # Bottom of teardrop (centered)
		])
		exhaust_jet.polygon = exhaust_points
		exhaust_jet.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange flame color
		
		# Position exhaust at the center rear of the ship
		exhaust_jet.position = Vector2(5, 0)  # Center at ship rear
		
		# Set z-index to render behind the ship
		exhaust_jet.z_index = -3
		
		# Create fire halo effect with multiple transparent layers
		create_exhaust_halo_layers()


func create_exhaust_halo_layers():
	# Create multiple transparent layers for fire halo effect
	var halo_layers = 6  # Reduced from 8 to 6 layers
	
	for i in range(halo_layers):
		var halo_layer = Polygon2D.new()
		exhaust_jet.add_child(halo_layer)
		
		# Create smaller teardrop shape for each halo layer
		var scale_factor = 1.0 + (i * 0.08)  # Reduced from 0.15 to 0.08 - each layer is only 8% larger
		var halo_points = PackedVector2Array([
			Vector2(-10 * scale_factor, -5 * scale_factor),   # Top
			Vector2(-30 * scale_factor, 0),                   # Back point
			Vector2(-10 * scale_factor, 5 * scale_factor)     # Bottom
		])
		halo_layer.polygon = halo_points
		
		# Position each layer with smaller offset for depth effect
		var offset_x = randf_range(-0.5, 0.5) * (i * 0.2)  # Reduced offset
		var offset_y = randf_range(-0.3, 0.3) * (i * 0.1)  # Reduced offset
		halo_layer.position = Vector2(offset_x, offset_y)
		
		# Create fire halo colors: white-hot core to orange-yellow outer layers
		var alpha = 0.25 - (i * 0.03)  # Reduced from 0.4 to 0.25, smaller decrease
		alpha = max(alpha, 0.03)  # Reduced minimum transparency
		
		var color_progress = float(i) / float(halo_layers - 1)
		var halo_color: Color
		
		if color_progress < 0.3:
			# Inner layers: white-hot to bright yellow
			halo_color = Color(1.0, 1.0, 0.8 - color_progress * 0.3, alpha)
		elif color_progress < 0.7:
			# Middle layers: bright yellow to orange
			var middle_progress = (color_progress - 0.3) / 0.4
			halo_color = Color(1.0, 1.0 - middle_progress * 0.3, 0.5 - middle_progress * 0.3, alpha)
		else:
			# Outer layers: orange to dark orange
			var outer_progress = (color_progress - 0.7) / 0.3
			halo_color = Color(1.0, 0.7 - outer_progress * 0.2, 0.2 - outer_progress * 0.1, alpha)
		
		halo_layer.color = halo_color
		
		# Set z-index so inner layers render on top
		halo_layer.z_index = i
		
		# Store layer info for animation
		halo_layer.set_meta("layer_index", i)
		halo_layer.set_meta("base_alpha", alpha)
		halo_layer.set_meta("scale_factor", scale_factor)


func _physics_process(delta):
	if is_dead:
		# Animate explosion particles
		var explosion = get_node_or_null("Explosion")
		if explosion:
			animate_explosion(explosion, delta)
		
		# CRITICAL: Continue updating particle systems even when dead
		# This ensures smoke trail and sparks continue their motion
		update_particle_systems(delta)
		
		# CRITICAL: Clean up empty particle systems when dead
		cleanup_empty_particle_systems()
		return
	
	if is_colliding:
		# Handle collision sequence
		handle_collision_sequence(delta)
		return
	
	# Update exhaust animation
	update_exhaust_animation(delta)
	
	# Update spotlight status
	update_spotlight()
	
	# Handle continuous emissions based on health stage
	handle_continuous_emissions(delta)
	
	# Update particle systems
	update_particle_systems(delta)
	

	
	# Handle input for all directions (only if controls are enabled)
	var input = Vector2.ZERO
	if not controls_disabled:
		input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		
		# Calculate target rotation based on vertical input
		update_rotation(input.y, delta)
		
		# Apply movement forces
		velocity.y += input.y * vertical_speed * delta
		velocity.x += input.x * horizontal_speed * delta
	
	# Apply drag to create momentum and sliding effect
	velocity *= drag
	
	# Apply planet gravity (attraction towards planet center) - after drag so it's not reduced
	apply_planet_gravity(delta)
	
	# Clamp velocity to maximum speeds
	velocity.y = clamp(velocity.y, -max_vertical_speed, max_vertical_speed)
	velocity.x = clamp(velocity.x, -max_horizontal_speed, max_horizontal_speed)
	
	# Move the character
	move_and_slide()
	
	# Collision detection is now handled by the obstacles via body_entered signal
	# No need to check for collisions here anymore
	
	# Keep player within screen bounds (only if boundaries are enabled)
	if boundaries_enabled:
		var screen_size = get_viewport().get_visible_rect().size
		position.y = clamp(position.y, screen_boundary, screen_size.y - screen_boundary)
		position.x = clamp(position.x, screen_boundary, screen_size.x - screen_boundary)
	
	# Update distance (for scoring) - based on world scroll speed
	distance += speed * delta

func apply_planet_gravity(delta: float):
	# Get the actual planet position from the BackgroundParallax script
	var bg_parallax = get_node_or_null("/root/Main/GameWorld/BackgroundParallax")
	if not bg_parallax:
		return
	
	var planet_center = bg_parallax.get_planet_center()
	
	# Calculate direction from spaceship to actual planet center
	var to_planet = planet_center - position
	var distance_to_planet = to_planet.length()
	
	# Only apply gravity if planet is within reasonable distance
	if distance_to_planet > 50 and distance_to_planet < 800:
		# Normalize direction
		var gravity_direction = to_planet.normalized()
		
		# Calculate gravity strength (stronger when closer to planet)
		var gravity_strength = gravity * (1.0 - (distance_to_planet / 800.0))  # Stronger when closer
		gravity_strength = clamp(gravity_strength, 0.0, gravity)  # Clamp to max gravity
		
		# Apply gravity force towards planet
		velocity += gravity_direction * gravity_strength * delta

func update_exhaust_animation(delta):
	if exhaust_jet:
		exhaust_timer += delta * 10.0  # Fast flickering
		
		# Get current input for dynamic flame behavior
		var input = Vector2.ZERO
		input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		
		# Create random flickering effect
		exhaust_scale = 1.0 + sin(exhaust_timer) * 0.1 + randf_range(-0.05, 0.05)
		exhaust_scale = clamp(exhaust_scale, 0.9, 1.1)  # Keep within 1-10% range
		
		# Dynamic flame behavior based on movement
		var target_length = 1.0
		var target_width = 1.0
		var target_alpha = 0.8
		
		if input.x > 0:  # Moving right - longer, brighter flame
			target_length = 1.2  # Reduced from 1.8 (50% reduction in X growth)
			target_width = 1.1  # Reduced from 1.5 (25% reduction in Y growth)
			target_alpha = 1.0
		elif input.x < 0:  # Moving left - shorter, dimmer flame
			target_length = 0.7  # Increased from 0.6
			target_width = 0.8   # Increased from 0.7
			target_alpha = 0.4
		else:  # No horizontal input - normal flame
			target_length = 1.0
			target_width = 1.0
			target_alpha = 0.8
		
		# Smoothly interpolate to target values
		var current_length = exhaust_jet.scale.x
		var current_width = exhaust_jet.scale.y
		var current_alpha = exhaust_jet.color.a
		
		current_length = lerp(current_length, target_length, delta * 5.0)
		current_width = lerp(current_width, target_width, delta * 5.0)
		current_alpha = lerp(current_alpha, target_alpha, delta * 5.0)
		
		# Apply scale to exhaust (center-based scaling)
		exhaust_jet.scale = Vector2(current_length, current_width)
		
		# Color variation removed
		# Create randomized, brighter, more yellow-white flame colors
		var flame_colors = [
			Color(1.0, 0.95, 0.7, current_alpha),   # Bright yellow-white
			Color(1.0, 0.9, 0.6, current_alpha),    # Yellow-white
			Color(1.0, 0.85, 0.5, current_alpha),   # Light yellow
			Color(1.0, 0.8, 0.4, current_alpha),    # Yellow-orange
			Color(1.0, 0.75, 0.3, current_alpha)    # Orange-yellow
		]
		var color_index = int(exhaust_timer * 3.0) % flame_colors.size()  # Cycle through colors
		var base_color = flame_colors[color_index]
		
		# Add slight random variation to the selected color
		var random_variation = randf_range(-0.1, 0.1)
		exhaust_jet.color = Color(
			base_color.r,
			clamp(base_color.g + random_variation, 0.6, 1.0),
			clamp(base_color.b + random_variation, 0.2, 0.8),
			current_alpha
		)
		
		# Animate halo layers
		animate_exhaust_halo_layers(delta, input, current_length, current_width)


func animate_exhaust_halo_layers(_delta: float, input: Vector2, main_length: float, main_width: float):
	# Animate each halo layer with independent movement and flickering
	for i in range(exhaust_jet.get_child_count()):
		var halo_layer = exhaust_jet.get_child(i)
		if not halo_layer.has_method("get_meta"):
			continue
		
		var layer_index = halo_layer.get_meta("layer_index", 0)
		var base_alpha = halo_layer.get_meta("base_alpha", 0.3)
		var scale_factor = halo_layer.get_meta("scale_factor", 1.0)
		
		# Independent flickering for each layer
		var layer_timer = exhaust_timer + (layer_index * 0.5)  # Offset timing
		var flicker = sin(layer_timer * 8.0 + layer_index) * 0.08 + randf_range(-0.03, 0.03)  # Reduced flicker
		
		# Scale halo layers based on main flame and input, but with reduced scaling
		var halo_length = main_length * scale_factor * (1.0 + flicker * 0.6)  # Reduced scaling factor
		var halo_width = main_width * scale_factor * (1.0 + flicker * 0.3)  # Reduced scaling factor
		halo_layer.scale = Vector2(halo_length, halo_width)
		
		# Dynamic alpha based on input and layer
		var dynamic_alpha = base_alpha
		if input.x > 0:  # Moving right - brighter halo
			dynamic_alpha *= 1.3  # Reduced from 1.5 to 1.3
		elif input.x < 0:  # Moving left - dimmer halo
			dynamic_alpha *= 0.7  # Increased from 0.6 to 0.7
		
		# Add flickering to alpha
		dynamic_alpha *= (1.0 + flicker * 0.2)  # Reduced flicker effect
		dynamic_alpha = clamp(dynamic_alpha, 0.02, 0.6)  # Reduced max alpha from 0.8 to 0.6
		
		# Slight position animation for dynamic effect
		var pos_offset = Vector2(
			sin(layer_timer * 3.0 + layer_index) * 0.3,  # Reduced movement
			cos(layer_timer * 2.0 + layer_index) * 0.2   # Reduced movement
		)
		halo_layer.position = pos_offset
		
		# Update color with dynamic alpha
		var current_color = halo_layer.color
		halo_layer.color = Color(current_color.r, current_color.g, current_color.b, dynamic_alpha)


func update_rotation(vertical_input: float, delta: float):
	# Calculate target rotation based on vertical input
	# Moving up (negative input) = clockwise rotation
	# Moving down (positive input) = counterclockwise rotation
	target_rotation = vertical_input * deg_to_rad(max_rotation_angle)
	
	# Smoothly interpolate current rotation towards target rotation
	var rotation_diff = target_rotation - current_rotation
	current_rotation += rotation_diff * rotation_speed * delta
	
	# Apply rotation to the spaceship
	rotation = current_rotation

func die():
	if is_dead:
		return
	
	# Trigger the complete final explosion sequence
	trigger_final_explosion()

func handle_collision(collision_velocity: float):
	if is_dead or is_colliding:
		print("Collision blocked - is_dead: ", is_dead, " is_colliding: ", is_colliding)
		return
	
	print("Collision detected! Velocity: ", collision_velocity, " Health: ", current_health)
	
	# Calculate collision intensity based on velocity
	var collision_intensity = "light"
	if collision_velocity > 200.0:
		collision_intensity = "strong"
	elif collision_velocity > 100.0:
		collision_intensity = "medium"
	
	print("Collision intensity: ", collision_intensity)
	
	# Handle collision based on intensity and current health
	match collision_intensity:
		"light":
			handle_light_collision()
		"medium":
			handle_medium_collision()
		"strong":
			handle_strong_collision()
	
	# Trigger collision shake
	trigger_collision_shake()
	
	# Play collision sound (if available)
	if explosion_sound:
		explosion_sound.play()

func handle_light_collision():
	if current_health <= 1:
		# If already critical, light collision causes death
		die()
		return
	
	# Reduce health
	current_health -= 1
	update_health_stage()
	
	# Apply speed reduction
	apply_speed_reduction()
	
	# Initialize spark emission interval for burst-based emission
	spark_emission_interval = randf_range(1.0, 3.0)  # 1-3 seconds for first damage
	spark_emission_timer = 0.0  # Start immediately
	
	# Spawn sparks
	spawn_collision_sparks()
	
	# Brief collision state for visual feedback
	is_colliding = true
	collision_timer = 0.0
	collision_duration = 0.3
	
	print("Light collision! Health: ", current_health, "/", max_health)

func handle_medium_collision():
	if current_health <= 1:
		# If already critical, medium collision causes death
		die()
		return
	
	# Reduce health by 2 (or to 0 if only 1 health left)
	current_health = max(0, current_health - 2)
	update_health_stage()
	
	# Apply speed reduction
	apply_speed_reduction()
	
	if current_health > 0:
		# Initialize spark emission interval for burst-based emission (faster when critical)
		spark_emission_interval = randf_range(0.5, 1.5)  # 0.5-1.5 seconds for critical damage
		spark_emission_timer = 0.0  # Start immediately
		
		# Spawn sparks and smoke
		spawn_collision_sparks()
		spawn_collision_smoke()
		
		# Brief collision state for visual feedback
		is_colliding = true
		collision_timer = 0.0
		collision_duration = 0.5
		
		print("Medium collision! Health: ", current_health, "/", max_health)
	else:
		# Death
		die()

func handle_strong_collision():
	# Strong collision always causes death
	print("Strong collision! Ship destroyed!")
	die()

func update_health_stage():
	health_stage = current_health
	print("Health: ", current_health, "/", max_health, " (Stage: ", health_stage, ")")

func apply_speed_reduction():
	# Calculate speed reduction based on health
	var new_reduction_factor = 1.0
	if current_health == 2:
		new_reduction_factor = 0.75  # 75% speed after first hit
	elif current_health == 1:
		new_reduction_factor = 0.5   # 50% speed after second hit
	
	speed_reduction_factor = new_reduction_factor
	
	# Apply speed reduction
	vertical_speed = original_vertical_speed * speed_reduction_factor
	horizontal_speed = original_horizontal_speed * speed_reduction_factor
	
	print("Speed reduced to ", (speed_reduction_factor * 100), "% - Vertical: ", vertical_speed, " Horizontal: ", horizontal_speed)

func get_world_scroll_speed() -> float:
	# Get the current world scroll speed from obstacle generator
	var obstacle_generator = get_node_or_null("/root/Main/GameWorld/ObstacleGenerator")
	if obstacle_generator:
		var base_speed = obstacle_generator.base_speed
		var time_elapsed = obstacle_generator.time_elapsed
		var current_base_speed = base_speed * (1.0 + time_elapsed / 120.0)
		var base_leftward_velocity = current_base_speed * 0.8
		base_leftward_velocity = max(base_leftward_velocity, base_speed * 0.3)
		return base_leftward_velocity
	return 80.0  # Default fallback speed

func get_spark_from_pool() -> Polygon2D:
	# Get a spark particle from the pool or create a new one
	if spark_pool.size() > 0:
		var spark = spark_pool.pop_back()
		spark.visible = true
		spark.scale = Vector2.ONE
		spark.rotation = 0.0
		return spark
	else:
		# Create new spark particle
		var spark = Polygon2D.new()
		# Create tiny circular spark particle
		var spark_radius = randf_range(0.2, 0.8)
		var spark_points = PackedVector2Array()
		var segments = 6
		
		for j in range(segments):
			var spark_angle = (j * PI * 2) / segments
			spark_points.append(Vector2(cos(spark_angle) * spark_radius, sin(spark_angle) * spark_radius))
		
		spark.polygon = spark_points
		return spark

func get_smoke_from_pool() -> Polygon2D:
	# Get a smoke particle from the pool or create a new one
	if smoke_pool.size() > 0:
		var smoke = smoke_pool.pop_back()
		smoke.visible = true
		smoke.scale = Vector2.ONE
		smoke.rotation = 0.0
		return smoke
	else:
		# Create new smoke particle
		var smoke = Polygon2D.new()
		# Create small round smoke bubble
		var smoke_radius = randf_range(1.5, 3.0)
		var smoke_points = PackedVector2Array()
		var segments = 10
		
		for j in range(segments):
			var smoke_angle = (j * PI * 2) / segments
			smoke_points.append(Vector2(cos(smoke_angle) * smoke_radius, sin(smoke_angle) * smoke_radius))
		
		smoke.polygon = smoke_points
		return smoke

func return_particle_to_pool(particle: Polygon2D, is_smoke: bool = false):
	# Return particle to appropriate pool
	if is_smoke:
		if smoke_pool.size() < max_pool_size:
			particle.visible = false
			smoke_pool.append(particle)
		else:
			particle.queue_free()
	else:
		if spark_pool.size() < max_pool_size:
			particle.visible = false
			spark_pool.append(particle)
		else:
			particle.queue_free()

func handle_continuous_emissions(delta: float):
	# Don't emit new particles if ship is dead
	if is_dead:
		return
	
	# Handle burst-based spark emissions when damaged (health stage 2)
	if health_stage <= 2:
		spark_emission_timer += delta
		if spark_emission_timer >= spark_emission_interval:
			spark_emission_timer = 0.0
			# Set next interval based on health stage
			if health_stage == 2:
				spark_emission_interval = randf_range(1.0, 3.0)  # 1-3 seconds for first damage
			else:
				spark_emission_interval = randf_range(0.5, 1.5)  # 0.5-1.5 seconds for critical damage
			spawn_collision_sparks()
	
	# Handle continuous smoke emissions when critical (health stage 1)
	if health_stage <= 1:
		# Create smoke particle system if it doesn't exist
		if not smoke_particles:
			spawn_smoke_particles()
			# Removed debug print for performance
		
		smoke_emission_timer += delta
		if smoke_emission_timer >= smoke_emission_interval:
			smoke_emission_timer = 0.0
			# Removed debug print for performance
			# The continuous smoke emission is handled by update_smoke_particles()

func update_particle_systems(delta: float):
	# Update collision particles (in world space)
	if collision_particles and is_instance_valid(collision_particles):
		update_collision_particles(delta)
	
	# Update smoke particles (in world space)
	if smoke_particles and is_instance_valid(smoke_particles):
		update_smoke_particles(delta)

func spawn_collision_sparks():
	# Removed debug print for performance
	# Create spark particle system in world space if it doesn't exist
	if not collision_particles:
		collision_particles = Node2D.new()
		collision_particles.name = "CollisionParticles"
		# Add to world space instead of ship
		get_parent().add_child(collision_particles)
	
	# Create spark particles
	var spark_count = 20  # Even more sparks
	for i in range(spark_count):
		var spark = get_spark_from_pool()
		collision_particles.add_child(spark)
		
		# White to yellow spark color (completely opaque)
		var spark_color_type = randi() % 2
		if spark_color_type == 0:
			spark.color = Color(1.0, 1.0, 1.0, 1.0)  # White
		else:
			spark.color = Color(1.0, 1.0, 0.3, 1.0)  # Yellow
		
		# Random position around collision point (in world space)
		var angle = randf_range(0, PI * 2)
		var spark_distance = randf_range(3, 8)
		spark.position = global_position + Vector2(cos(angle) * spark_distance, sin(angle) * spark_distance)
		
		# Set up spark animation with world scroll movement
		var world_scroll_speed = get_world_scroll_speed()
		var spark_velocity = Vector2(cos(angle) * randf_range(30, 80), sin(angle) * randf_range(30, 80))
		spark_velocity.x -= world_scroll_speed  # Add leftward movement
		spark.set_meta("velocity", spark_velocity)
		spark.set_meta("lifetime", 0.0)
		spark.set_meta("max_lifetime", 0.6)
		spark.set_meta("rotation_speed", randf_range(-5.0, 5.0))

func spawn_collision_smoke():
	# Removed debug print for performance
	# Create smoke particle system in world space if it doesn't exist
	if not smoke_particles:
		smoke_particles = Node2D.new()
		smoke_particles.name = "SmokeParticles"
		# Add to world space instead of ship
		get_parent().add_child(smoke_particles)
	
	# Create smoke particles
	var smoke_count = 6  # More smoke bubbles
	for i in range(smoke_count):
		var smoke = get_smoke_from_pool()
		smoke_particles.add_child(smoke)
		
		# Grey smoke color with fade - increased brightness and alpha for better visibility
		var grey_brightness = randf_range(0.4, 0.7)
		smoke.color = Color(grey_brightness, grey_brightness, grey_brightness, 1.0)
		
		# Random position around collision point (in world space)
		var angle = randf_range(0, PI * 2)
		var smoke_distance = randf_range(2, 6)
		smoke.position = global_position + Vector2(cos(angle) * smoke_distance, sin(angle) * smoke_distance)
		
		# Set up smoke animation with world scroll movement
		var world_scroll_speed = get_world_scroll_speed()
		var smoke_velocity = Vector2(cos(angle) * randf_range(10, 40), sin(angle) * randf_range(10, 40))
		smoke_velocity.x -= world_scroll_speed  # Add leftward movement
		smoke.set_meta("velocity", smoke_velocity)
		smoke.set_meta("lifetime", 0.0)
		smoke.set_meta("max_lifetime", 8.0)  # Doubled from 4.0 to 8.0 seconds
		smoke.set_meta("expansion_rate", randf_range(2.5, 5.0))  # Increased from 1.5-3.0 to 2.5-5.0

func trigger_collision_shake():
	# Get the background parallax system and trigger real camera shake
	var bg_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	if bg_parallax and bg_parallax.has_method("trigger_camera_shake"):
		bg_parallax.trigger_camera_shake(8.0, 0.3, 26.0)  # 30% faster frequency

func trigger_explosion_shake():
	# Get the background parallax system and trigger real camera shake and debris push
	var bg_parallax = get_node_or_null("/root/Main/GameWorld/Background")
	if bg_parallax:
		if bg_parallax.has_method("trigger_camera_shake"):
			bg_parallax.trigger_camera_shake(8.0, 0.8, 12.0)  # Reduced intensity from 15.0 to 8.0, duration from 1.2 to 0.8, frequency from 15.6 to 12.0
		if bg_parallax.has_method("push_debris_from_explosion"):
			bg_parallax.push_debris_from_explosion(global_position)

func spawn_explosion():
	# Create explosion particle system in world space
	var explosion = Node2D.new()
	explosion.name = "Explosion"
	# Add to world space instead of ship so it doesn't get hidden
	get_parent().add_child(explosion)
	# Set explosion position to ship's current position
	explosion.position = global_position
	print("Explosion created at ship position: ", global_position, " explosion position: ", explosion.position)
	
	# Create enhanced flame particles (white to yellow to orange)
	var flame_count = 40  # Reduced from 80 - less overwhelming effect
	for i in range(flame_count):
		var particle = Polygon2D.new()
		explosion.add_child(particle)
		
		# Create spherical flame particle using circle approximation
		var radius = randf_range(2.0, 6.0)  # Varied sizes
		var circle_points = PackedVector2Array()
		var segments = 12  # Smooth circle approximation
		
		for j in range(segments):
			var circle_angle = (j * PI * 2) / segments
			circle_points.append(Vector2(cos(circle_angle) * radius, sin(circle_angle) * radius))
		
		particle.polygon = circle_points
		
		# Flame color gradient: white -> yellow -> orange
		var color_type = randi() % 3
		match color_type:
			0:  # White-hot core
				particle.color = Color(1.0, 1.0, 1.0, 1.0)
			1:  # Yellow flame
				particle.color = Color(1.0, 1.0, 0.3, 1.0)
			2:  # Orange flame
				particle.color = Color(1.0, 0.5, 0.0, 1.0)
		
		# Random initial position around explosion center (relative to explosion node)
		var particle_angle = randf_range(0, PI * 2)
		var particle_distance = randf_range(3, 20)
		particle.position = Vector2(cos(particle_angle) * particle_distance, sin(particle_angle) * particle_distance)
		
		# Set up particle animation with varied velocities
		particle.set_meta("initial_scale", Vector2.ONE)
		particle.set_meta("velocity", Vector2(cos(particle_angle) * randf_range(60, 150), sin(particle_angle) * randf_range(60, 150)))  # Reduced velocity range
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", randf_range(0.8, 1.5))  # Varied lifetimes
		particle.set_meta("rotation_speed", randf_range(-3.0, 3.0))  # Spinning particles
	
	# Create spherical smoke puffs
	var smoke_count = 25  # Reduced from 45 - less overwhelming effect
	for i in range(smoke_count):
		var smoke_particle = Polygon2D.new()
		explosion.add_child(smoke_particle)
		
		# Create spherical smoke using circle approximation
		var smoke_radius = randf_range(3.0, 15.0)  # Wider range including smaller puffs
		var smoke_circle_points = PackedVector2Array()
		var smoke_segments = 16  # More segments for smoother smoke
		
		for j in range(smoke_segments):
			var smoke_circle_angle = (j * PI * 2) / smoke_segments
			smoke_circle_points.append(Vector2(cos(smoke_circle_angle) * smoke_radius, sin(smoke_circle_angle) * smoke_radius))
		
		smoke_particle.polygon = smoke_circle_points
		
		# Grey smoke with varied brightness - increased alpha for better visibility
		var grey_brightness = randf_range(0.2, 0.8)  # Wider brightness range
		smoke_particle.color = Color(grey_brightness, grey_brightness, grey_brightness, 1.0)
		
		# Random position around explosion center (relative to explosion node)
		var smoke_angle = randf_range(0, PI * 2)
		var smoke_distance = randf_range(3, 30)  # Wider spread including closer puffs
		smoke_particle.position = Vector2(cos(smoke_angle) * smoke_distance, sin(smoke_angle) * smoke_distance)
		
		# Smoke physics - slower, drifting movement
		var smoke_velocity = Vector2(cos(smoke_angle) * randf_range(15, 70), sin(smoke_angle) * randf_range(15, 70))
		smoke_particle.set_meta("velocity", smoke_velocity)
		smoke_particle.set_meta("lifetime", 0.0)
		smoke_particle.set_meta("max_lifetime", randf_range(1.8, 4.0))  # Varied lifetimes
		smoke_particle.set_meta("expansion_rate", randf_range(0.3, 2.0))  # How fast smoke expands
	
	# Start explosion animation
	explosion.set_meta("animation_timer", 0.0)
	explosion.set_meta("_max_animation_time", 1.0)

func _process(delta):
	if is_dead:
		# Animate explosion particles (in world space)
		var explosion = get_parent().get_node_or_null("Explosion")
		if explosion:
			animate_explosion(explosion, delta)
		return

func animate_explosion(explosion: Node2D, delta: float):
	var animation_timer = explosion.get_meta("animation_timer", 0.0)
	var _max_animation_time = explosion.get_meta("_max_animation_time", 1.0)
	
	animation_timer += delta
	explosion.set_meta("animation_timer", animation_timer)
	
	# Animate each particle
	for particle in explosion.get_children():
		if particle is Polygon2D:
			var lifetime = particle.get_meta("lifetime", 0.0)
			var max_lifetime = particle.get_meta("max_lifetime", 1.0)
			
			lifetime += delta
			particle.set_meta("lifetime", lifetime)
			
			# Calculate progress (0 to 1)
			var progress = lifetime / max_lifetime
			
			# Move particle
			var particle_velocity = particle.get_meta("velocity", Vector2.ZERO)
			particle.position += particle_velocity * delta
			
			# Rotate flame particles
			var particle_rotation_speed = particle.get_meta("rotation_speed", 0.0)
			if particle_rotation_speed != 0.0:
				particle.rotation += particle_rotation_speed * delta
			
			# Different expansion for flames vs smoke
			var expansion_rate = particle.get_meta("expansion_rate", 1.0)
			if expansion_rate > 0.0:
				# Smoke particles - expand more gradually
				var scale_factor = 1.0 + progress * expansion_rate * 2.0
				particle.scale = Vector2(scale_factor, scale_factor)
			else:
				# Flame particles - expand more dramatically
				var scale_factor = 1.0 + progress * 4.0  # Expand to 5x size
				particle.scale = Vector2(scale_factor, scale_factor)
			
			# Different fade patterns for flames vs smoke
			var original_color = particle.color
			if expansion_rate > 0.0:
				# Smoke - fade out more gradually
				var alpha = 1.0 - (progress * progress * progress)  # Cubic fade for smoke
				particle.color.a = alpha * original_color.a
			else:
				# Flames - fade out more dramatically
				var alpha = 1.0 - (progress * progress)  # Quadratic fade for flames
				particle.color.a = alpha * original_color.a
			
			# Remove particle when fully transparent
			if progress >= 1.0:
				particle.queue_free()
	
	# Remove explosion when all particles are gone
	if explosion.get_child_count() == 0:
		explosion.queue_free()

func reset():
	is_dead = false
	is_colliding = false
	controls_disabled = false  # Re-enable player controls
	collision_timer = 0.0
	collision_duration = 0.0
	out_of_control_timer = 0.0
	out_of_control_duration = 0.0
	target_direction = Vector2.ZERO
	current_direction = Vector2.ZERO
	bounce_velocity = Vector2.ZERO
	distance = 0.0
	velocity = Vector2.ZERO
	position = Vector2(100, get_viewport().get_visible_rect().size.y / 2)
	exhaust_timer = 0.0
	exhaust_scale = 1.0
	target_rotation = 0.0
	current_rotation = 0.0
	rotation = 0.0  # Reset visual rotation
	
	# Reset health system
	current_health = max_health
	health_stage = 3
	spark_emission_timer = 0.0
	smoke_emission_timer = 0.0
	
	# Reset speed system
	speed_reduction_factor = 1.0
	vertical_speed = original_vertical_speed
	horizontal_speed = original_horizontal_speed
	
	# Clear particle pools
	spark_pool.clear()
	smoke_pool.clear()
	
	# Re-enable screen boundaries for new game
	boundaries_enabled = true
	
	# Set z-index to be -1 (player spaceship - moved one level higher)
	z_index = -1  # Player spaceship layer (moved one level higher)
	
	# Update spaceship color to match new debris color
	update_spaceship_color()
	
	# Make spaceship visible again
	if spaceship_visual:
		spaceship_visual.visible = true
	if exhaust_jet:
		exhaust_jet.visible = true
	
	# Clean up any explosion or collision particles (in world space)
	var explosion_node = get_parent().get_node_or_null("Explosion")
	if explosion_node:
		explosion_node.queue_free()
	
	var collision_particles_node = get_parent().get_node_or_null("CollisionParticles")
	if collision_particles_node:
		collision_particles_node.queue_free()
	
	var smoke_particles_node = get_parent().get_node_or_null("SmokeParticles")
	if smoke_particles_node:
		smoke_particles_node.queue_free()
	

	
	if collision_shape:
		collision_shape.disabled = false
	
	if exhaust_jet:
		exhaust_jet.visible = true
		exhaust_jet.scale = Vector2.ONE
	
	if engine_sound:
		engine_sound.play()
	
	# Reset spotlight
	if spotlight:
		spotlight.visible = false
		spotlight.energy = 0.0
	spotlight_active = false

func handle_collision_sequence(delta: float):
	# Update collision timer
	collision_timer += delta
	
	# Update collision particles
	if collision_particles:
		update_collision_particles(delta)
	
	# Update smoke particles
	if smoke_particles:
		update_smoke_particles(delta)
	
	# Check if collision sequence is complete
	if collision_timer >= collision_duration:
		# End collision state
		is_colliding = false



func spawn_collision_particles():
	# Create collision particle system in world space
	collision_particles = Node2D.new()
	collision_particles.name = "CollisionParticles"
	# Add to world space instead of ship
	get_parent().add_child(collision_particles)
	
	# Create initial collision particles
	var particle_count = 8
	for i in range(particle_count):
		var particle = Polygon2D.new()
		collision_particles.add_child(particle)
		
		# Small collision particles
		var particle_points = PackedVector2Array([
			Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)
		])
		particle.polygon = particle_points
		particle.color = Color(1.0, 0.3, 0.0, 1.0)  # Orange-red collision color
		
		# Random position around collision point
		var angle = randf_range(0, PI * 2)
		var particle_distance = randf_range(3, 8)
		particle.position = Vector2(cos(angle) * particle_distance, sin(angle) * particle_distance)
		
		# Set up particle animation with world scroll movement
		var world_scroll_speed = get_world_scroll_speed()
		var particle_velocity = Vector2(cos(angle) * randf_range(30, 80), sin(angle) * randf_range(30, 80))
		particle_velocity.x -= world_scroll_speed  # Add leftward movement
		particle.set_meta("velocity", particle_velocity)
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", 0.8)
		particle.set_meta("emission_timer", 0.0)

func update_collision_particles(delta: float):
	if not collision_particles:
		return
	
	# Emit new particles continuously
	var emission_timer = collision_particles.get_meta("emission_timer", 0.0)
	emission_timer += delta
	collision_particles.set_meta("emission_timer", emission_timer)
	
	# Emit new particle every 0.1 seconds (10 particles per second) - only when ship is not dead
	if emission_timer >= 0.1 and not is_dead:
		emission_timer = 0.0
		collision_particles.set_meta("emission_timer", emission_timer)
		
		# Create new small circular spark particle
		var particle = get_spark_from_pool()
		collision_particles.add_child(particle)
		
		# White to yellow spark color (completely opaque)
		var spark_color_type = randi() % 2
		if spark_color_type == 0:
			particle.color = Color(1.0, 1.0, 1.0, 1.0)  # White
		else:
			particle.color = Color(1.0, 1.0, 0.3, 1.0)  # Yellow
		
		# Emit in opposite direction of flight (in world space) with world scroll movement
		var opposite_direction = -velocity.normalized()
		var angle = atan2(opposite_direction.y, opposite_direction.x) + randf_range(-0.5, 0.5)
		var particle_speed = randf_range(40, 100)
		particle.position = global_position
		var world_scroll_speed = get_world_scroll_speed()
		var particle_velocity = Vector2(cos(angle) * particle_speed, sin(angle) * particle_speed)
		particle_velocity.x -= world_scroll_speed  # Add leftward movement
		particle.set_meta("velocity", particle_velocity)
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", 0.6)
		particle.set_meta("rotation_speed", randf_range(-5.0, 5.0))
	
	# Animate existing particles (both continuous and one-time collision particles)
	for i in range(int(collision_particles.get_child_count() - 1), -1, -1):
		var particle = collision_particles.get_child(i)
		if particle is Polygon2D:
			var lifetime = particle.get_meta("lifetime", 0.0)
			var max_lifetime = particle.get_meta("max_lifetime", 0.8)
			
			lifetime += delta
			particle.set_meta("lifetime", lifetime)
			
			# Calculate progress
			var progress = lifetime / max_lifetime
			
			# Move particle
			var particle_velocity = particle.get_meta("velocity", Vector2.ZERO)
			particle.position += particle_velocity * delta
			
			# Rotate particle (for sparks)
			var particle_rotation_speed = particle.get_meta("rotation_speed", 0.0)
			particle.rotation += particle_rotation_speed * delta
			
			# Expand and fade
			var scale_factor = 1.0 + progress * 2.0
			particle.scale = Vector2(scale_factor, scale_factor)
			
			# Fade out
			var alpha = 1.0 - progress
			particle.color.a = alpha
			
			# Remove when done
			if progress >= 1.0:
				particle.get_parent().remove_child(particle)
				return_particle_to_pool(particle, false)  # false = spark

func spawn_smoke_particles():
	# Create smoke particle system in world space
	smoke_particles = Node2D.new()
	smoke_particles.name = "SmokeParticles"
	# Add to world space instead of ship
	get_parent().add_child(smoke_particles)
	
	# Set up smoke emission timer
	smoke_particles.set_meta("emission_timer", 0.0)

func update_smoke_particles(delta: float):
	if not smoke_particles:
		return
	
	# Emit new smoke particles continuously
	var emission_timer = smoke_particles.get_meta("emission_timer", 0.0)
	emission_timer += delta
	smoke_particles.set_meta("emission_timer", emission_timer)
	
	# Emit new smoke particle every 0.05 seconds (20 particles per second) - only when health stage is 1 or less AND ship is not dead
	if emission_timer >= 0.05 and health_stage <= 1 and not is_dead:
		emission_timer = 0.0
		smoke_particles.set_meta("emission_timer", emission_timer)
		# Removed debug print for performance
		
		# Create new round smoke bubble
		var particle = get_smoke_from_pool()
		smoke_particles.add_child(particle)
		
		# Grey smoke color with fade - increased brightness and alpha for better visibility
		var grey_brightness = randf_range(0.4, 0.7)
		particle.color = Color(grey_brightness, grey_brightness, grey_brightness, 1.0)
		
		# Position behind the ship (in world space)
		particle.position = global_position + Vector2(-10, 0)  # Behind the ship
		
		# Smoke physics with world scroll movement
		var world_scroll_speed = get_world_scroll_speed()
		var smoke_velocity = Vector2(randf_range(-20, -40), randf_range(-10, 10))  # Drift backward and up/down
		smoke_velocity.x -= world_scroll_speed  # Add leftward movement
		particle.set_meta("velocity", smoke_velocity)
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", 12.0)  # Increased to 12.0 seconds for better visibility
		particle.set_meta("expansion_rate", randf_range(2.5, 5.0))  # Increased expansion rate for continuous smoke
		particle.set_meta("initial_scale", Vector2.ONE)
	
	# Animate existing smoke particles (both continuous and one-time collision smoke)
	for i in range(int(smoke_particles.get_child_count() - 1), -1, -1):
		var particle = smoke_particles.get_child(i)
		if particle is Polygon2D:
			var lifetime = particle.get_meta("lifetime", 0.0)
			var max_lifetime = particle.get_meta("max_lifetime", 12.0)  # Updated for 12 second smoke lifetime
			
			lifetime += delta
			particle.set_meta("lifetime", lifetime)
			
			# Calculate progress
			var progress = lifetime / max_lifetime
			
			# Move particle
			var particle_velocity = particle.get_meta("velocity", Vector2.ZERO)
			particle.position += particle_velocity * delta
			
			# Expand smoke (with expansion rate for all smoke types)
			var expansion_rate = particle.get_meta("expansion_rate", 2.0)  # Default expansion rate
			var scale_factor = 1.0 + progress * expansion_rate
			particle.scale = Vector2(scale_factor, scale_factor)
			
			# Fade out slowly - go from initial alpha to 0
			var initial_alpha = particle.color.a
			var alpha = initial_alpha * (1.0 - progress)  # Smoke fades from initial alpha to 0
			particle.color.a = alpha
			
			# Remove when done
			if progress >= 1.0:
				particle.get_parent().remove_child(particle)
				return_particle_to_pool(particle, true)  # true = smoke

func trigger_final_explosion():
	is_dead = true
	
	# Make spaceship invisible
	if spaceship_visual:
		spaceship_visual.visible = false
	if exhaust_jet:
		exhaust_jet.visible = false
	
	# Stop engine sound
	if engine_sound:
		engine_sound.stop()
	
	# Trigger camera shake for explosion
	trigger_explosion_shake()
	
	# Convert collision particles to final explosion
	if collision_particles:
		convert_to_final_explosion()
	else:
		spawn_explosion()
	
	# Disable collision
	if collision_shape:
		collision_shape.call_deferred("set_disabled", true)
	
	# Trigger game over sequence
	get_tree().call_group("game_manager", "on_player_died")

func convert_to_final_explosion():
	# Rename collision particles to explosion
	collision_particles.name = "Explosion"
	# Move explosion to world space and set correct position
	if collision_particles.get_parent():
		collision_particles.get_parent().remove_child(collision_particles)
	get_parent().add_child(collision_particles)
	collision_particles.position = global_position
	print("Converted explosion at ship position: ", global_position, " explosion position: ", collision_particles.position)
	
	# Add enhanced flame particles for final explosion (white to yellow to orange)
	var additional_particles = 60  # Reduced from 120 - less overwhelming final explosion
	for i in range(additional_particles):
		var particle = Polygon2D.new()
		collision_particles.add_child(particle)
		
		# Create spherical flame particle using circle approximation
		var radius = randf_range(2.0, 8.0)  # Larger range for final explosion
		var circle_points = PackedVector2Array()
		var segments = 14  # Smooth circle approximation
		
		for j in range(segments):
			var final_circle_angle = (j * PI * 2) / segments
			circle_points.append(Vector2(cos(final_circle_angle) * radius, sin(final_circle_angle) * radius))
		
		particle.polygon = circle_points
		
		# Flame color gradient: white -> yellow -> orange
		var color_type = randi() % 3
		match color_type:
			0:  # White-hot core
				particle.color = Color(1.0, 1.0, 1.0, 1.0)
			1:  # Yellow flame
				particle.color = Color(1.0, 1.0, 0.3, 1.0)
			2:  # Orange flame
				particle.color = Color(1.0, 0.5, 0.0, 1.0)
		
		# Random initial position around explosion center (relative to explosion node)
		var final_particle_angle = randf_range(0, PI * 2)
		var particle_distance = randf_range(3, 25)
		particle.position = Vector2(cos(final_particle_angle) * particle_distance, sin(final_particle_angle) * particle_distance)
		
		# Set up particle animation with varied velocities
		particle.set_meta("velocity", Vector2(cos(final_particle_angle) * randf_range(80, 180), sin(final_particle_angle) * randf_range(80, 180)))  # Reduced velocity range
		particle.set_meta("lifetime", 0.0)
		particle.set_meta("max_lifetime", randf_range(1.0, 2.0))  # Longer lifetime for final explosion
		particle.set_meta("rotation_speed", randf_range(-4.0, 4.0))  # Spinning particles
	
	# Add spherical smoke burst to explosion
	var smoke_burst_count = 35  # Large smoke particles
	var small_smoke_count = 50  # Additional small smoke particles
	for i in range(smoke_burst_count):
		var smoke_particle = Polygon2D.new()
		collision_particles.add_child(smoke_particle)
		
		# Create spherical smoke using circle approximation
		var smoke_radius = randf_range(2.0, 18.0)  # Much wider range including tiny puffs
		var smoke_circle_points = PackedVector2Array()
		var smoke_segments = 18  # More segments for smoother smoke
		
		for j in range(smoke_segments):
			var final_smoke_circle_angle = (j * PI * 2) / smoke_segments
			smoke_circle_points.append(Vector2(cos(final_smoke_circle_angle) * smoke_radius, sin(final_smoke_circle_angle) * smoke_radius))
		
		smoke_particle.polygon = smoke_circle_points
		
		# Grey smoke with varied brightness - increased alpha for better visibility
		var grey_brightness = randf_range(0.2, 0.9)  # Even wider brightness range
		smoke_particle.color = Color(grey_brightness, grey_brightness, grey_brightness, 1.0)
		
		# Random position around explosion center (relative to explosion node)
		var final_smoke_angle = randf_range(0, PI * 2)
		var smoke_distance = randf_range(2, 35)  # Even wider spread
		smoke_particle.position = Vector2(cos(final_smoke_angle) * smoke_distance, sin(final_smoke_angle) * smoke_distance)
		
		# Smoke physics - slower, drifting movement
		var smoke_velocity = Vector2(cos(final_smoke_angle) * randf_range(20, 90), sin(final_smoke_angle) * randf_range(20, 90))
		smoke_particle.set_meta("velocity", smoke_velocity)
		smoke_particle.set_meta("lifetime", 0.0)
		smoke_particle.set_meta("max_lifetime", randf_range(2.0, 4.5))  # Varied lifetimes
		smoke_particle.set_meta("expansion_rate", randf_range(0.2, 2.5))  # How fast smoke expands
	
			# Set up explosion animation
		collision_particles.set_meta("animation_timer", 0.0)
		collision_particles.set_meta("max_animation_time", 1.0)
	
	# Add additional small smoke particles for more density
	for i in range(small_smoke_count):
		var small_smoke = Polygon2D.new()
		collision_particles.add_child(small_smoke)
		
		# Create small smoke particles
		var small_smoke_radius = randf_range(0.8, 2.5)  # Smaller than the main smoke
		var small_smoke_circle_points = PackedVector2Array()
		var small_smoke_segments = 8  # Fewer segments for small particles
		
		for j in range(small_smoke_segments):
			var small_smoke_circle_angle = (j * PI * 2) / small_smoke_segments
			small_smoke_circle_points.append(Vector2(cos(small_smoke_circle_angle) * small_smoke_radius, sin(small_smoke_circle_angle) * small_smoke_radius))
		
		small_smoke.polygon = small_smoke_circle_points
		
		# Grey smoke with varied brightness (smaller particles can be darker) - increased alpha for better visibility
		var small_grey_brightness = randf_range(0.2, 0.6)
		small_smoke.color = Color(small_grey_brightness, small_grey_brightness, small_grey_brightness, 1.0)
		
		# Random position around explosion center (relative to explosion node)
		var small_smoke_angle = randf_range(0, PI * 2)
		var small_smoke_distance = randf_range(1, 20)  # Closer to center for small particles
		small_smoke.position = Vector2(cos(small_smoke_angle) * small_smoke_distance, sin(small_smoke_angle) * small_smoke_distance)
		
		# Small smoke physics - slower movement
		var small_smoke_velocity = Vector2(cos(small_smoke_angle) * randf_range(10, 50), sin(small_smoke_angle) * randf_range(10, 50))
		small_smoke.set_meta("velocity", small_smoke_velocity)
		small_smoke.set_meta("lifetime", 0.0)
		small_smoke.set_meta("max_lifetime", randf_range(1.5, 3.0))  # Shorter lifetime for small particles
		small_smoke.set_meta("expansion_rate", randf_range(0.1, 1.5))  # Slower expansion

func apply_shadow_effect(shadow_strength: float):
	# Apply shadow effect to the spaceship visual
	if spaceship_visual:
		# Store original color if not already stored
		if not spaceship_visual.has_meta("original_color"):
			spaceship_visual.set_meta("original_color", spaceship_visual.color)
		
		var original_color = spaceship_visual.get_meta("original_color")
		
		# Calculate shadowed color - much darker shadow effect
		var shadow_factor = 1.0 - (shadow_strength * 0.95)  # Max 95% darkness for very dramatic effect
		var shadowed_color = Color(
			original_color.r * shadow_factor,
			original_color.g * shadow_factor,
			original_color.b * shadow_factor,
			original_color.a
		)
		
		spaceship_visual.color = shadowed_color
		
		# Also darken the exhaust jet
		if exhaust_jet:
			if not exhaust_jet.has_meta("original_color"):
				exhaust_jet.set_meta("original_color", exhaust_jet.color)
			
			var exhaust_original_color = exhaust_jet.get_meta("original_color")
			var exhaust_shadowed_color = Color(
				exhaust_original_color.r * shadow_factor,
				exhaust_original_color.g * shadow_factor,
				exhaust_original_color.b * shadow_factor,
				exhaust_original_color.a
			)
			
			exhaust_jet.color = exhaust_shadowed_color

func clear_shadow_effect():
	# Clear shadow effect from the spaceship visual
	if spaceship_visual and spaceship_visual.has_meta("original_color"):
		spaceship_visual.color = spaceship_visual.get_meta("original_color")
	
	# Clear shadow effect from the exhaust jet
	if exhaust_jet and exhaust_jet.has_meta("original_color"):
		exhaust_jet.color = exhaust_jet.get_meta("original_color")

func create_spotlight():
	# Create Light2D spotlight using proper Godot 4 syntax
	var light_scene = preload("res://spotlight_light.tscn")
	spotlight = light_scene.instantiate()
	spotlight.name = "Spotlight"
	add_child(spotlight)
	
	# Set Light2D properties
	spotlight.texture = create_spotlight_texture()
	spotlight.color = spotlight_color
	spotlight.energy = spotlight_intensity
	spotlight.blend_mode = Light2D.BLEND_MODE_ADD  # Additive blending for realistic lighting
	spotlight.shadow_enabled = false  # No shadows for this spotlight
	
	# Set up light mask to only affect debris/obstacles
	# Layer 1: Player, Layer 2: Obstacles, Layer 3: Background objects
	spotlight.light_mask = 2  # Only affect obstacle layer (layer 2)
	
	# Position the light at the front of the spaceship
	spotlight.position = Vector2(20, 0)  # Front point of spaceship
	
	# Set Z-index to be in front of everything for testing
	spotlight.z_index = 2  # In front of everything for testing
	
	# Initially hidden
	spotlight.visible = false

func create_spotlight_texture():
	# Create a custom light texture for the cone shape - make it bigger to avoid cutoff
	var texture_size = 512  # Increased from 256 to 512
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Start with transparent
	
	# Calculate cone parameters
	var center = Vector2(texture_size / 2.0, texture_size / 2.0)  # Center of the texture
	var angle_rad = deg_to_rad(spotlight_angle)
	var half_angle = angle_rad / 2.0
	
	# Create the light cone pattern
	for y in range(texture_size):
		for x in range(texture_size):
			var pixel_pos = Vector2(x, y)
			var direction = (pixel_pos - center).normalized()
			var pixel_distance = (pixel_pos - center).length()
			
			# Check if pixel is within the cone
			var angle_to_center = abs(direction.angle_to(Vector2(1, 0)))  # Angle from forward direction
			if angle_to_center <= half_angle and pixel_distance <= spotlight_range:
				# Calculate intensity based on distance and angle
				var distance_factor = 1.0 - (pixel_distance / spotlight_range)
				var angle_factor = 1.0 - (angle_to_center / half_angle)
				var intensity = distance_factor * angle_factor
				
				# Create smooth falloff with stronger center
				intensity = pow(intensity, 1.5)  # Smooth curve with stronger center
				intensity = clamp(intensity, 0.0, 1.0)
				
				# Set pixel color (white with intensity-based alpha)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, intensity))
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(image)
	return texture

func update_spotlight():
	# Check if we should activate the spotlight based on shadow status
	if not background_parallax:
		return
	
	# Check if shadow is active - access the public property directly
	var should_activate = false
	if background_parallax.has_method("get"):
		# Try to access shadow_active property
		should_activate = background_parallax.shadow_active
	
	# Debug: Print spotlight status (only when it changes)
	if should_activate != spotlight_active:
		print("Spotlight: ", "ACTIVATED" if should_activate else "DEACTIVATED")
		print("Shadow active: ", should_activate)
	
	# Activate or deactivate spotlight
	if should_activate and not spotlight_active:
		activate_spotlight()
	elif not should_activate and spotlight_active:
		deactivate_spotlight()
	
	# Light2D handles illumination automatically

func activate_spotlight():
	spotlight_active = true
	print("Activating spotlight...")
	if spotlight:
		spotlight.visible = true
		# Fade in effect by animating energy
		spotlight.energy = 0.0
		# Animate fade in over 0.5 seconds
		var tween = create_tween()
		tween.tween_property(spotlight, "energy", spotlight_intensity, 0.5)
		print("Spotlight fade-in animation started")
	else:
		print("ERROR: Spotlight is null!")

func deactivate_spotlight():
	spotlight_active = false
	print("Deactivating spotlight...")
	
	if spotlight:
		# Fade out effect by animating energy
		var tween = create_tween()
		tween.tween_property(spotlight, "energy", 0.0, 0.3)
		tween.tween_callback(func(): spotlight.visible = false)
		print("Spotlight fade-out animation started")

# Light2D handles all illumination automatically - no manual functions needed

# Clean up empty particle systems when ship is dead
func cleanup_empty_particle_systems():
	# Clean up collision particles if empty and ship is dead
	if collision_particles and is_instance_valid(collision_particles):
		if collision_particles.get_child_count() == 0:
			collision_particles.queue_free()
			collision_particles = null
	
	# Clean up smoke particles if empty and ship is dead
	if smoke_particles and is_instance_valid(smoke_particles):
		if smoke_particles.get_child_count() == 0:
			smoke_particles.queue_free()
			smoke_particles = null
