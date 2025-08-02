extends RefCounted

# Debris Shape Generator
# Extracted from BackgroundParallax.gd to handle all debris shape generation
# This script contains all the complex shape generation logic for space debris

func generate_complex_shape(shape_type: int, size: Vector2) -> PackedVector2Array:
	# Generate all 30 complex shapes for debris objects with varied thickness
	var half_size = size / 2
	var scale_factor = 1.0  # Default scale factor
	
	# Calculate thickness variation based on actual size
	var thickness_ratio = size.y / size.x  # How thick vs long the piece is
	var is_thick = thickness_ratio > 0.8  # Thick pieces
	var is_thin = thickness_ratio < 0.3   # Thin pieces
	var _is_medium = not is_thick and not is_thin  # Medium thickness
	
	match shape_type:
		0:  # Twisted hull plating with thickness variation
			var _hull_size = randf_range(4 * scale_factor, size.x)
			var elongated_factor = 2.2  # Make it more elongated
			var thickness_multiplier = 1.0
			if is_thick:
				thickness_multiplier = 1.8  # Make thick pieces even thicker
			elif is_thin:
				thickness_multiplier = 0.4  # Make thin pieces even thinner
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor * 1.1, -half_size.y * 0.7 * thickness_multiplier),  # Twisted left
				Vector2(-half_size.x * elongated_factor * 0.5, -half_size.y * 1.3 * thickness_multiplier),  # Major deformation
				Vector2(half_size.x * elongated_factor * 0.2, -half_size.y * 0.8 * thickness_multiplier),
				Vector2(half_size.x * elongated_factor * 0.7, -half_size.y * 1.5 * thickness_multiplier),   # Deep twist
				Vector2(half_size.x * elongated_factor * 1.2, -half_size.y * 0.3 * thickness_multiplier),   # Protruding right
				Vector2(half_size.x * elongated_factor * 0.9, half_size.y * 0.6 * thickness_multiplier),    # Right deformation
				Vector2(half_size.x * elongated_factor * 0.4, half_size.y * 1.2 * thickness_multiplier),    # Bottom twist
				Vector2(-half_size.x * elongated_factor * 0.1, half_size.y * 0.9 * thickness_multiplier),
				Vector2(-half_size.x * elongated_factor * 0.6, half_size.y * 1.4 * thickness_multiplier),   # Bottom left twist
				Vector2(-half_size.x * elongated_factor * 1.0, half_size.y * 0.5 * thickness_multiplier),   # Left deformation
				Vector2(-half_size.x * elongated_factor * 0.8, -half_size.y * 0.1 * thickness_multiplier)   # Back to start
			])
		1:  # Structural beam with thickness variation
			var beam_length = randf_range(8 * scale_factor, size.x * 2.0)  # Much longer
			var beam_width = randf_range(1 * scale_factor, size.x * 0.15)  # Much thinner
			var thickness_multiplier = 1.0
			if is_thick:
				beam_width *= 2.5  # Make thick beams much wider
				thickness_multiplier = 1.5
			elif is_thin:
				beam_width *= 0.3  # Make thin beams even thinner
				thickness_multiplier = 0.6
			return PackedVector2Array([
				Vector2(-beam_length * 0.7, -beam_width * 0.8 * thickness_multiplier),  # Severed base
				Vector2(-beam_length * 0.3, -beam_width * 1.8 * thickness_multiplier),  # First break
				Vector2(beam_length * 0.1, -beam_width * 0.9 * thickness_multiplier),
				Vector2(beam_length * 0.5, -beam_width * 2.1 * thickness_multiplier),   # Second break
				Vector2(beam_length * 0.9, -beam_width * 0.4 * thickness_multiplier),   # Third break
				Vector2(beam_length * 1.3, beam_width * 0.8 * thickness_multiplier),    # Severed tip
				Vector2(beam_length * 0.8, beam_width * 2.2 * thickness_multiplier),    # Bottom breaks
				Vector2(beam_length * 0.4, beam_width * 1.1 * thickness_multiplier),
				Vector2(beam_length * 0.0, beam_width * 2.0 * thickness_multiplier),
				Vector2(-beam_length * 0.4, beam_width * 0.9 * thickness_multiplier),
				Vector2(-beam_length * 0.8, beam_width * 1.9 * thickness_multiplier)    # Back to start
			])
		2:  # Elongated exploded thruster nozzle with scattered pieces
			var nozzle_size = randf_range(3 * scale_factor, size.x * 0.7)
			var num_points = 14
			var points = PackedVector2Array()
			for i in range(num_points):
				var angle = (i * 2 * PI) / num_points
				var radius = nozzle_size
				# Create elongated exploded nozzle shape
				if i < 3:  # Top explosion
					radius *= randf_range(0.2, 2.1)
				elif i < 7:  # Right explosion (elongated)
					radius *= randf_range(0.4, 2.5)  # More elongation
				elif i < 10:  # Bottom explosion
					radius *= randf_range(0.3, 2.0)
				else:  # Left explosion
					radius *= randf_range(0.5, 1.7)
				var point = Vector2(cos(angle) * radius * 1.8, sin(angle) * radius)  # Elongate horizontally
				points.append(point)
			return points
		3:  # Elongated shattered circuit board with exposed components
			var board_size = randf_range(3 * scale_factor, size.x * 0.8)
			var elongated_factor = 2.5  # Make it very elongated
			return PackedVector2Array([
				Vector2(-board_size * elongated_factor * 0.9, -board_size * 0.5),    # Main board
				Vector2(-board_size * elongated_factor * 0.4, -board_size * 0.9),    # Top component
				Vector2(board_size * elongated_factor * 0.1, -board_size * 0.7),
				Vector2(board_size * elongated_factor * 0.6, -board_size * 1.2),     # Large component
				Vector2(board_size * elongated_factor * 1.1, -board_size * 0.4),     # Right edge
				Vector2(board_size * elongated_factor * 0.8, board_size * 0.6),      # Right component
				Vector2(board_size * elongated_factor * 0.3, board_size * 1.1),      # Bottom right
				Vector2(-board_size * elongated_factor * 0.2, board_size * 0.9),     # Bottom component
				Vector2(-board_size * elongated_factor * 0.7, board_size * 0.4),     # Bottom left
				Vector2(-board_size * elongated_factor * 1.2, board_size * 0.1),     # Left edge
				Vector2(-board_size * elongated_factor * 0.8, -board_size * 0.2)     # Back to start
			])
		4:  # Elongated fractured rectangle - Shattered panel with jagged edges
			var jagged_factor = 0.15
			var elongated_factor = 2.8  # Very elongated
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.3 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x * elongated_factor + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), -half_size.y * 0.7 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.4 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(half_size.x * elongated_factor * 0.6 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x * elongated_factor * 0.2 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y),
				Vector2(-half_size.x * elongated_factor, half_size.y * 0.6 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x * elongated_factor * 0.8 + randf_range(-jagged_factor * half_size.x, jagged_factor * half_size.x), half_size.y * 0.2 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y)),
				Vector2(-half_size.x * elongated_factor, -half_size.y * 0.3 + randf_range(-jagged_factor * half_size.y, jagged_factor * half_size.y))
			])
		5:  # Elongated fractured rectangle - Broken structural beam with missing chunks
			var elongated_factor = 3.0  # Very elongated
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.4, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.4, -half_size.y * 0.3),
				Vector2(half_size.x * elongated_factor * 0.7, -half_size.y * 0.3),
				Vector2(half_size.x * elongated_factor * 0.7, -half_size.y * 0.1),
				Vector2(half_size.x * elongated_factor, -half_size.y * 0.1),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.2),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y * 0.2),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.3, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.3, half_size.y * 0.7),
				Vector2(-half_size.x * elongated_factor, half_size.y * 0.7),
				Vector2(-half_size.x * elongated_factor, half_size.y * 0.4),
				Vector2(-half_size.x * elongated_factor * 0.6, half_size.y * 0.4),
				Vector2(-half_size.x * elongated_factor * 0.6, -half_size.y * 0.2),
				Vector2(-half_size.x * elongated_factor, -half_size.y * 0.2)
			])
		6:  # Elongated fractured rectangle - Exploded equipment with irregular holes
			var elongated_factor = 2.5  # Elongated
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.2, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.2, -half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor * 0.5, -half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor * 0.5, -half_size.y * 0.8),
				Vector2(half_size.x * elongated_factor * 0.8, -half_size.y * 0.8),
				Vector2(half_size.x * elongated_factor * 0.8, -half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor, -half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.3),
				Vector2(half_size.x * elongated_factor * 0.7, half_size.y * 0.3),
				Vector2(half_size.x * elongated_factor * 0.7, half_size.y * 0.7),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.7),
				Vector2(half_size.x * elongated_factor, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.4, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.4, half_size.y * 0.5),
				Vector2(-half_size.x * elongated_factor * 0.7, half_size.y * 0.5),
				Vector2(-half_size.x * elongated_factor * 0.7, half_size.y * 0.2),
				Vector2(-half_size.x * elongated_factor, half_size.y * 0.2),
				Vector2(-half_size.x * elongated_factor, -half_size.y * 0.4),
				Vector2(-half_size.x * elongated_factor * 0.6, -half_size.y * 0.4),
				Vector2(-half_size.x * elongated_factor * 0.6, -half_size.y)
			])
		7:  # Elongated fractured rectangle - Severed pipe with jagged break
			var _break_factor = 0.3
			var elongated_factor = 2.8  # Very elongated
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.3, -half_size.y),
				Vector2(half_size.x * elongated_factor * 0.3, -half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor * 0.6, -half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor * 0.6, -half_size.y * 0.2),
				Vector2(half_size.x * elongated_factor, -half_size.y * 0.2),
				Vector2(half_size.x * elongated_factor, half_size.y * 0.1),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y * 0.1),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor * 0.5, half_size.y * 0.4),
				Vector2(half_size.x * elongated_factor * 0.5, half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y * 0.6),
				Vector2(half_size.x * elongated_factor * 0.8, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.2, half_size.y),
				Vector2(-half_size.x * elongated_factor * 0.2, half_size.y * 0.7),
				Vector2(-half_size.x * elongated_factor * 0.5, half_size.y * 0.7),
				Vector2(-half_size.x * elongated_factor * 0.5, half_size.y * 0.3),
				Vector2(-half_size.x * elongated_factor * 0.8, half_size.y * 0.3),
				Vector2(-half_size.x * elongated_factor * 0.8, -half_size.y * 0.1),
				Vector2(-half_size.x * elongated_factor, -half_size.y * 0.1)
			])
		8:  # Elongated shattered panel with protruding fragments
			var panel_size = randf_range(4 * scale_factor, size.x * 0.8)
			var panel_half_size = Vector2(panel_size * 2.5, panel_size) / 2  # Elongated
			return PackedVector2Array([
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
		9:  # Elongated twisted structural beam with multiple bends
			var beam_length = randf_range(10 * scale_factor, size.x * 2.5)  # Much longer
			var beam_width = randf_range(2 * scale_factor, size.x * 0.2)    # Thinner
			return PackedVector2Array([
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
			var equip_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var pipe_radius = randf_range(2 * scale_factor, size.x * 0.6)
			var num_points = 16
			var points = PackedVector2Array()
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
				points.append(point)
			return points
		12:  # Fractured solar panel with broken cells
			var panel_size = randf_range(5 * scale_factor, size.x)
			var solar_half_size = Vector2(panel_size * 1.3, panel_size * 0.4) / 2
			return PackedVector2Array([
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
			var board_size = randf_range(3 * scale_factor, size.x * 0.8)
			return PackedVector2Array([
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
			var hull_size = randf_range(4 * scale_factor, size.x)
			var hull_half_size = Vector2(hull_size * 1.2, hull_size * 1.1) / 2
			return PackedVector2Array([
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
			var nozzle_size = randf_range(3 * scale_factor, size.x * 0.7)
			var num_points = 14
			var points = PackedVector2Array()
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
				points.append(point)
			return points
		16:  # Destroyed life support with exposed internals
			var life_size = randf_range(4 * scale_factor, size.x)
			var life_half_size = Vector2(life_size * 1.3, life_size * 0.9) / 2
			return PackedVector2Array([
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
			var antenna_length = randf_range(6 * scale_factor, size.x * 1.3)
			var antenna_width = randf_range(1 * scale_factor, size.x * 0.2)
			return PackedVector2Array([
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
			var container_size = randf_range(4 * scale_factor, size.x)
			var container_half_size = Vector2(container_size * 1.2, container_size * 1.0) / 2
			return PackedVector2Array([
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
			var conduit_length = randf_range(5 * scale_factor, size.x * 1.2)
			var conduit_width = randf_range(2 * scale_factor, size.x * 0.4)
			return PackedVector2Array([
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
			var reactor_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var nav_size = randf_range(5 * scale_factor, size.x * 1.1)
			return PackedVector2Array([
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
			var tank_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var dish_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var cargo_size = randf_range(5 * scale_factor, size.x * 1.2)
			return PackedVector2Array([
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
			var window_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var airlock_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var med_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
			var nacelle_size = randf_range(5 * scale_factor, size.x * 1.3)
			return PackedVector2Array([
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
			var console_size = randf_range(4 * scale_factor, size.x)
			return PackedVector2Array([
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
		_:  # Fallback to simple elongated rectangle
			var elongated_factor = randf_range(1.5, 3.0)  # Random elongation
			return PackedVector2Array([
				Vector2(-half_size.x * elongated_factor, -half_size.y),
				Vector2(half_size.x * elongated_factor, -half_size.y),
				Vector2(half_size.x * elongated_factor, half_size.y),
				Vector2(-half_size.x * elongated_factor, half_size.y)
			]) 