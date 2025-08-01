# 🚀 Kessler Syndrome - Space Debris Survival

A vibe-coded, assetless, code-only space-themed endless runner built with Godot 4.4. Navigate through increasingly dense space debris while avoiding catastrophic collisions in this minimalist, procedurally generated experience.

![Game Screenshot](assets/gameplay_screenshot.png)

## 🎮 Game Overview

**Kessler Syndrome** is a vibe-coded, assetless endless runner where you pilot a spaceship through procedurally generated space debris. Built entirely with code and minimalism in mind, the game features:

- **Procedural Generation**: Endless, dynamically generated obstacle patterns
- **Physics-Based Gameplay**: Realistic momentum, gravity, and collision physics
- **Code-Only Visuals**: All graphics generated programmatically with no external assets
- **Progressive Challenge**: Survive as long as possible in an ever-increasingly hostile environment

## 🎯 How to Play

### Controls
- **WASD** or **Arrow Keys**: Move the spaceship
- **R**: Restart after game over

### Objective
- Navigate through procedurally generated space debris without colliding
- Survive as long as possible in this endless runner
- Your distance traveled is your score
- Difficulty increases over time with more complex patterns

### Health System
- **3 Hit Points**: Each collision reduces health
- **Visual Damage**: Sparks and smoke indicate damage level
- **Speed Reduction**: Damaged ships move slower
- **Final Explosion**: Dramatic particle explosion on death

## 🛠️ Technical Features

### Engine & Performance
- **Godot 4.4**: Latest engine with modern rendering
- **Object Pooling**: Optimized performance for particle systems
- **20-Layer Parallax**: Extreme depth and visual richness
- **Physics-Based**: Realistic space physics with momentum and drag
- **Assetless Design**: No external textures, sounds, or assets required

### Visual Systems
- **Code-Generated Graphics**: All visuals created programmatically with no external assets
- **Dynamic Color Scheme**: Debris and ship colors change over time
- **Spotlight System**: Dynamic lighting in shadowed areas
- **Particle Effects**: Explosions, sparks, smoke, and exhaust flames
- **Camera Shake**: Immersive feedback for collisions and explosions

### Gameplay Systems
- **10 Obstacle Types**: Varied shapes and sizes for challenge
- **Procedural Generation**: Endless, dynamically generated obstacle patterns
- **Planet Gravity**: Realistic gravitational effects
- **Shadow System**: Dynamic shadows near the planet
- **Progressive Difficulty**: Obstacles spawn faster and rotate more over time

## 🚀 Getting Started

### Prerequisites
- **Godot 4.4** or later
- **Windows 10/11** (tested on Windows)

### Installation
1. Clone this repository:
   ```bash
   git clone https://github.com/Bl4ckh34d/KesslerSyndrome.git
   cd KesslerSyndrome
   ```

2. Open the project in Godot:
   - Launch Godot 4.4
   - Click "Import" and select the `project.godot` file
   - Click "Import & Edit"

3. Run the game:
   - Press F5 or click the "Play" button
   - The game will start with the main scene

### Building for Distribution
1. In Godot, go to **Project → Export**
2. Select the "Windows Desktop" preset
3. Click "Export Project" and choose your output location

## 📁 Project Structure

```
KesslerSyndrome/
├── scenes/
│   ├── Main.tscn          # Main game scene
│   └── Obstacle.tscn      # Obstacle prefab
├── scripts/
│   ├── GameManager.gd     # Game state and UI management
│   ├── Spaceship.gd       # Player controller and physics
│   ├── ObstacleGenerator.gd # Obstacle spawning and management
│   ├── Obstacle.gd        # Individual obstacle behavior
│   └── BackgroundParallax.gd # Parallax background system
├── assets/                # Game assets (textures, sounds, etc.)
├── spotlight_light.tscn   # Spotlight component
├── project.godot         # Godot project configuration
└── export_presets.cfg    # Build configuration
```

## 🎨 Game Systems

### Spaceship Controller
- **Code-generated triangle-shaped** spaceship with dynamic exhaust effects
- **Physics-based movement** with momentum and screen boundaries
- **Health system** with visual damage progression
- **Particle systems** for damage feedback and explosions

### Obstacle System
- **Object pooling** for performance optimization
- **10 different shapes** with varied collision patterns
- **Progressive difficulty** scaling over time
- **Physics-based movement** with realistic space physics

### Background System
- **20-layer parallax** for extreme visual depth
- **Procedurally generated** space environment
- **Dynamic color scheme** that evolves over time
- **Planet gravity** affecting player movement
- **Shadow system** with dynamic spotlight activation

## 🔧 Development

### Key Scripts
- **`GameManager.gd`**: Handles game state, UI updates, and restart logic
- **`Spaceship.gd`**: Player controller with physics, particles, and spotlight integration
- **`ObstacleGenerator.gd`**: Manages obstacle spawning, pooling, and difficulty progression
- **`BackgroundParallax.gd`**: Complex parallax system with planet, shadows, and color management
- **`Obstacle.gd`**: Individual obstacle physics and collision handling

### Performance Optimizations
- **Object pooling** for particles and obstacles
- **Efficient collision detection** with proper layer masks
- **Optimized parallax rendering** with smart object management
- **Memory management** for particle systems

## 🎯 Future Enhancements

### Planned Features
- [ ] Procedurally generated sound effects
- [ ] Power-ups and special abilities
- [ ] Multiple procedurally generated ship types
- [ ] Leaderboard system
- [ ] Mobile support
- [ ] Multiplayer mode

### Technical Improvements
- [ ] Enhanced particle effects
- [ ] More obstacle types
- [ ] Advanced lighting effects
- [ ] Performance optimizations
- [ ] Accessibility features

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Godot Engine](https://godotengine.org/)
- Inspired by classic endless runners and minimalist game design
- Special thanks to the Godot community for excellent documentation and support
- A testament to what can be achieved with pure code and creativity

## 📞 Contact

- **Developer**: Daniel Schmidt
- **Project Link**: [https://github.com/Bl4ckh34d/KesslerSyndrome](https://github.com/Bl4ckh34d/KesslerSyndrome)

---

**Enjoy surviving the Kessler Syndrome!** 🚀💥 