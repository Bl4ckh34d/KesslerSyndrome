extends Node

@export var game_over_scene: PackedScene

var player: Node2D
var obstacle_generator: Node2D
var background_parallax: Node2D
var score_label: Label
var difficulty_label: Label
var game_over_label: Label
var game_world: Node2D
var ui_layer: CanvasLayer

var game_over: bool = false
var score: float = 0.0
var difficulty: float = 1.0
var fade_timer: float = 0.0
var fade_duration: float = 3.5
var fade_overlay: ColorRect
var original_obstacle_speed: float = 100.0
var original_parallax_speed: float = 100.0

func _ready():
	# Add to game_manager group
	add_to_group("game_manager")
	
	# Get references
	player = $GameWorld/Spaceship
	obstacle_generator = $GameWorld/ObstacleGenerator
	background_parallax = $GameWorld/Background
	score_label = $UI/ScoreLabel
	difficulty_label = $UI/DifficultyLabel
	game_over_label = $UI/GameOverLabel
	game_world = $GameWorld
	ui_layer = $UI
	
	# Store original speeds
	if obstacle_generator:
		original_obstacle_speed = obstacle_generator.base_speed
	if background_parallax:
		original_parallax_speed = background_parallax.base_speed
	
	# Create fade overlay (this will also set up the game over label)
	create_fade_overlay()
	
	# Start the game
	start_game()

func create_fade_overlay():
	# Create a CanvasLayer for the fade effect
	var fade_canvas = CanvasLayer.new()
	fade_canvas.name = "FadeCanvas"
	fade_canvas.layer = 100  # Very high layer to render on top of everything
	add_child(fade_canvas)
	
	# Create the fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.position = Vector2.ZERO
	fade_overlay.visible = false
	fade_canvas.add_child(fade_overlay)
	
	# Move game over label to fade canvas so it renders on top
	if game_over_label:
		# Remove from original parent
		game_over_label.get_parent().remove_child(game_over_label)
		# Add to fade canvas
		fade_canvas.add_child(game_over_label)
		# Set up styling
		game_over_label.add_theme_color_override("font_color", Color.WHITE)
		game_over_label.add_theme_font_size_override("font_size", 32)
		game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Center the label properly
		game_over_label.position = Vector2.ZERO
		game_over_label.size = get_viewport().get_visible_rect().size
		game_over_label.visible = false
	else:
		# Create a new game over label if none exists
		var new_game_over_label = Label.new()
		new_game_over_label.name = "GameOverLabel"
		new_game_over_label.add_theme_color_override("font_color", Color.WHITE)
		new_game_over_label.add_theme_font_size_override("font_size", 32)
		new_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		new_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		new_game_over_label.position = Vector2.ZERO
		new_game_over_label.size = get_viewport().get_visible_rect().size
		new_game_over_label.visible = false
		fade_canvas.add_child(new_game_over_label)
		game_over_label = new_game_over_label

func _process(delta):
	if not game_over and player:
		score = player.distance
		if score_label:
			score_label.text = "Distance: " + str(floor(score)) + "m"
		
		# Update difficulty display
		if obstacle_generator and difficulty_label:
			difficulty = obstacle_generator.current_difficulty
			difficulty_label.text = "Difficulty: " + str(round(difficulty * 10) / 10)
	
	# Handle restart input
	if Input.is_action_just_pressed("restart") and game_over:
		start_game()
	
	# Handle fade animation (always when game over)
	if game_over and fade_overlay:
		animate_fade(delta)

func animate_fade(delta: float):
	# Update fade timer
	fade_timer += delta
	var progress = fade_timer / fade_duration
	
	# Ensure fade overlay is visible and properly sized
	fade_overlay.visible = true
	fade_overlay.size = get_viewport().get_visible_rect().size
	
	# Fade to black (complete the fade even after duration)
	if progress <= 1.0:
		fade_overlay.color.a = progress
	else:
		# Keep it fully black after fade completes
		fade_overlay.color.a = 1.0
	
	# Fade in game over text during the fade to black
	if game_over_label:
		# Ensure game over label is properly sized
		game_over_label.size = get_viewport().get_visible_rect().size
		
		# Start text fade-in when background fade is 50% complete
		var text_fade_start = 0.5
		var text_fade_progress = 0.0
		
		if progress >= text_fade_start:
			# Calculate text fade progress (0 to 1) from 50% to 100% of background fade
			text_fade_progress = (progress - text_fade_start) / (1.0 - text_fade_start)
			text_fade_progress = clamp(text_fade_progress, 0.0, 1.0)
			
			# Set text content
			game_over_label.text = "Game Over!\n\nFinal Distance: " + str(floor(score)) + "m\n\nDifficulty Reached: " + str(round(difficulty * 10) / 10) + "\n\nPress R to restart\n\nWASD or Arrow Keys to control\nAvoid obstacles"
			
			# Fade in the text by adjusting its color alpha
			var text_color = Color.WHITE
			text_color.a = text_fade_progress
			game_over_label.add_theme_color_override("font_color", text_color)
			
			# Make text visible when we start fading it in
			if not game_over_label.visible:
				game_over_label.visible = true
		else:
			# Keep text invisible during first 50% of fade
			game_over_label.visible = false

func on_player_died():
	game_over = true
	fade_timer = 0.0
	
	# Ensure fade overlay exists and is properly initialized
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color.a = 0.0  # Start fully transparent
		fade_overlay.size = get_viewport().get_visible_rect().size
	else:
		# Recreate fade overlay if it doesn't exist
		create_fade_overlay()
	
	# Ensure game over label exists and is ready
	if not game_over_label:
		# Try to find it in the scene
		game_over_label = get_node_or_null("UI/GameOverLabel")
		if not game_over_label:
			# Create a new one if not found
			create_fade_overlay()
	
	# Ensure game over label is properly set up
	if game_over_label:
		game_over_label.visible = false  # Start invisible
		game_over_label.size = get_viewport().get_visible_rect().size
		game_over_label.position = Vector2.ZERO

func start_game():
	game_over = false
	score = 0.0
	difficulty = 1.0
	fade_timer = 0.0
	
	# Reset fade overlay
	if fade_overlay:
		fade_overlay.color.a = 0.0
		fade_overlay.visible = false
	
	# Hide game over UI and reset text color
	if game_over_label:
		game_over_label.visible = false
		# Reset text color to full opacity
		var text_color = Color.WHITE
		text_color.a = 1.0
		game_over_label.add_theme_color_override("font_color", text_color)
	
	# Complete reset in proper order
	# 1. Reset background parallax first (clears all objects and generates new colors)
	if background_parallax:
		background_parallax.reset()
	
	# 2. Reset obstacle generator (clears all obstacles)
	if obstacle_generator:
		obstacle_generator.reset()
	
	# 3. Reset player last (ensures clean environment)
	if player:
		player.reset()
	
	# 4. Reset camera shake
	if background_parallax and background_parallax.has_method("reset_camera_shake"):
		background_parallax.reset_camera_shake()
	
	# 5. Force multiple frame delays to ensure all resets are complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 6. CRITICAL FIX: Update ship color to ensure it's the opposite of debris color
	if background_parallax and background_parallax.has_method("update_ship_color_simple"):
		background_parallax.update_ship_color_simple()
	
	# 7. RESTORE ORIGINAL SPEEDS - this is critical!
	if obstacle_generator:
		obstacle_generator.base_speed = original_obstacle_speed
	if background_parallax:
		background_parallax.base_speed = original_parallax_speed
	
	# 8. Start background spawning after initial delay
	if background_parallax:
		background_parallax.call_deferred("start_background_spawning")
	
	# Reset score display
	if score_label:
		score_label.text = "Distance: 0m"
