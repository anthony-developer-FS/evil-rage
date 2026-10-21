# Evil Rage

A punishing 2D precision platformer where the levels lie to you. Built with Godot 4.5.

## Run it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, no .NET needed).
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press F5. The test room loads.

Controls: A/D or arrows to move, Space/K/Up to jump, R to restart. Gamepad works too (stick or d-pad, A to jump).

## Layout

| Path | What it is |
| --- | --- |
| `scripts/player.gd` | Kinematic controller: run, variable jump, coyote time, jump buffer, wall slide and wall jump |
| `resources/default_tuning.tres` | Every movement number. Edit it in the inspector to retune feel |
| `scripts/game.gd` | Autoload that keeps death counters and taunts across room reloads |
| `scripts/room.gd` | Base for every room: spawns the player, reloads the room on death |
| `scenes/objects/` | Reusable pieces: player, block, hazard (spikes), goal, HUD |
| `scenes/rooms/test_room.tscn` | Movement test room |
| `tests/movement_test.tscn` | Headless movement checks |

Rooms reload entirely on death, so every troll trap resets for free. A new room is a scene whose root uses `room.gd` and contains `Player`, `Spawn`, `Goal` and `Hud`.

## Tests

```
godot --headless --path . res://tests/movement_test.tscn
```

Exits 0 when all checks pass.
