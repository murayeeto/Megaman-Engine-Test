# Needed Sprites for Megaman X Engine Template

## Player Sprites
The following sprites are needed for the player character animations. All sprites should be approximately 24x32 pixels for proper scaling.

### Animation Frames Needed:

#### Idle Animation (6 frames, 6 FPS)
- `player_idle_01.png` - Standing pose, buster cannon at rest
- `player_idle_02.png` - Slight movement/breathing animation
- `player_idle_03.png` - Continue breathing cycle
- `player_idle_04.png` - Peak of breathing animation
- `player_idle_05.png` - Return to neutral
- `player_idle_06.png` - Complete breathing cycle

#### Running Animation (8 frames, 12 FPS)
- `player_run_01.png` - Starting run pose
- `player_run_02.png` - Left foot forward
- `player_run_03.png` - Mid-stride left
- `player_run_04.png` - Right foot forward
- `player_run_05.png` - Mid-stride right
- `player_run_06.png` - Left foot forward again
- `player_run_07.png` - Mid-stride variation
- `player_run_08.png` - Complete cycle

#### Jump Animation (4 frames, 10 FPS, no loop)
- `player_jump_01.png` - Crouch/preparation
- `player_jump_02.png` - Launch pose
- `player_jump_03.png` - Mid-air pose 1
- `player_jump_04.png` - Peak jump pose

#### Fall Animation (3 frames, 8 FPS)
- `player_fall_01.png` - Beginning fall
- `player_fall_02.png` - Mid-fall pose
- `player_fall_03.png` - Terminal velocity pose

#### Dash Animation (3 frames, 12 FPS)
- `player_dash_01.png` - Dash start pose (horizontal)
- `player_dash_02.png` - Mid-dash blur effect
- `player_dash_03.png` - Dash end pose

#### Wall Slide Animation (2 frames, 6 FPS)
- `player_wall_slide_01.png` - Sliding down wall, one hand on wall
- `player_wall_slide_02.png` - Slight variation for animation

## Player Shot Sprites

#### Normal Shot
- `player_shot_normal.png` - Small blue energy projectile (8x8 pixels)

#### Charged Shot
- `player_shot_charged.png` - Larger cyan energy projectile (12x12 pixels)

## Particle Effects (Optional - can use colored squares)
- `dash_particle.png` - Small blue/white particle for dash trail
- `wall_slide_particle.png` - Small gray/brown particle for wall friction
- `shot_hit_particle.png` - Small explosion effect particle

## Audio Files Needed
While the template uses placeholder AudioStreamGenerator, you may want to replace with actual sound files:

### Player Audio
- `jump.ogg` - Jump sound effect
- `dash.ogg` - Dash sound effect  
- `land.ogg` - Landing sound effect
- `wall_slide.ogg` - Wall sliding friction sound
- `shot_normal.ogg` - Normal shot firing sound
- `shot_charged.ogg` - Charged shot firing sound
- `charge_loop.ogg` - Charging sound loop

### Shot Audio
- `shot_hit.ogg` - Shot impact sound

## Notes
- All player sprites should face right by default (the code handles flipping for left movement)
- Sprites should have consistent proportions and style matching Megaman X aesthetic
- Consider using a consistent color palette (blues, whites, some red accents)
- Particle sprites can be simple geometric shapes if needed
- All audio should be in .ogg format for best Godot compatibility

## Implementation Notes
Once sprites are ready:
1. Create SpriteFrames resources for the AnimatedSprite2D
2. Import sprites and add them to the appropriate animation frames
3. Replace the placeholder icon.svg texture in particle systems
4. Replace AudioStreamGenerator with actual audio files
5. Adjust timing and frame counts as needed for your art style