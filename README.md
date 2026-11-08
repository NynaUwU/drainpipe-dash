# Drainpipe Dash (Godot 4)

A fast sewer-pipe slide game with a PS2-era look. Everything (pipe, textures, sounds) is generated in code, so there are no asset files.

## Run it
1. Get Godot 4.3 or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot → **Import** → pick `project.godot` in this folder.
3. Press **F5** (Play).

To make a standalone `.exe`: Project → Export → Add "Windows Desktop" (Godot will offer to download export templates) → Export Project.

## Levels
1. **Gearworks** — brick and dark-steel pipes and machinery halls. Giant extraction fans to slip between, floating junk bobbing in the stream, sharp S-bends lined with steering walls, blue guide markers.
2. **Drip Yard** — broken, leaking pipes (green hissing spray) and open wooden scaffold decks: no walls, different handling, and you can fall off the edge. Rusted-out gaps that need an edge jump, big wooden crates.
3. **Grand Outfall** — high wooden walkways under a midnight-blue sky with a city skyline and oversized junk, then big swooping steel channels with low grates (hop) and crossbeams (stay low). Ends with a dive down a huge vertical shaft: steer past beams onto the blue target for a bonus.
4. **Scullery Drain** — narrow copper pipes with blind drops into sharp turns, wooden subfloor corridors, wide concrete basements. Water gushers shove you sideways and splash the lens; slime pools kill your speed before ramp jumps over wide gaps.

Developer smoke test: `godot --path . -- --autotest [--level=N]` plays each level briefly and saves screenshots to `../shots`.

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Steer around the pipe | ← → / A D | Left stick / D-pad |
| Jump | Space | A |
| Faster / brake | ↑ ↓ / W S | RT / LT |
| Pause | Esc / P | Start |
| Mute | M | |
| Fullscreen | F11 | |

## What makes it look and feel the way it does
- 640×360 internal resolution scaled up, ordered dithering, colour quantising and interlace lines (`shaders/post.gdshader`)
- Bloom, depth fog and volumetric fog lit by lamps, your headlamp and daylight beams through ceiling grates
- Speed effects: FOV widens with speed, radial blur, chromatic split on boosts, speed streaks, camera shake, steep drops that accelerate you
- Flowing water shader, splashes, ceiling drips, outflow pipes and waterfalls pouring into the gaps
- Sewer soundscape on a reverb bus: rushing water, drone, drips, distant pipe groans and clanks

## Files
- `scripts/main.gd` — game flow, physics, camera, effects, HUD
- `scripts/track.gd` — pipe path, course generator, mesh building
- `scripts/textures.gd` — procedural brick, rust, hazard textures
- `scripts/audio_synth.gd` — synthesised sound effects
- `shaders/` — post-process, water, boost pads
