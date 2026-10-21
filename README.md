# Evil Rage

A punishing 2D precision platformer where the levels lie to you. Built with Godot 4.5.

## Run it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, no .NET needed).
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press F5. Room 1 of the prototype level loads. Beat all six rooms.

Controls: A/D or arrows to move, Space/K/Up to jump, R to restart, F11 or Alt+Enter to toggle fullscreen. Gamepad works too (stick or d-pad, A to jump).

## Resolution

The game is drawn at 320x180 and scaled up by whole numbers, so pixels stay sharp: 6x at 1080p, 8x at 1440p and 12x at 4K. It starts fullscreen at the monitor's native resolution. Windowed mode opens at 1280x720 and can be resized.

## Layout

| Path | What it is |
| --- | --- |
| `scripts/player.gd` | Kinematic controller: run, variable jump, coyote time, jump buffer, wall slide and wall jump |
| `resources/default_tuning.tres` | Every movement number. Edit it in the inspector to retune feel |
| `scripts/game.gd` | Autoload that keeps death counters and taunts across room reloads |
| `scripts/room.gd` | Base for every room: spawns the player, reloads the room on death |
| `scenes/objects/` | Reusable pieces: player, block, hazard (spikes), goal, HUD |
| `scenes/trolls/` | Troll traps, each a drop-in scene (see below) |
| `scenes/rooms/room_01.tscn` to `room_06.tscn` | Prototype level, one troll per room, then all of them |
| `scenes/rooms/test_room.tscn` | Movement sandbox |
| `tests/` | Headless tests for movement, traps and level beatability |

## Troll traps

Drop a trap scene into a room and set its `size` in the inspector. In the editor each trap draws an orange outline of its trigger area; in game it is invisible or looks like a normal block.

| Trap | What it does | Tweak |
| --- | --- | --- |
| Fake floor | Looks like a block, vanishes when stood on | `delay` adds a shake before it drops |
| Pop spikes | Hidden until the player enters the trigger, then shoot up | `trigger` rect |
| Runaway goal | The exit hops to the next point when approached | `flee_points`, `flee_radius` |
| Invisible block | Appears when hit from below and bonks the player | none |
| Falling ceiling | Drops when the player walks under, crushes, then becomes a block | `trigger_depth`, `gravity` |

Rooms reload entirely on death, so every troll trap resets for free. A new room is a scene whose root uses `room.gd` and contains `Player`, `Spawn`, `Goal` and `Hud`. Set the goal's `next_room` to chain rooms; leave it empty on the last room.

## Tests

```
GODOT=/path/to/godot ./run_tests.sh
```

Three suites: `movement_test` checks the controller, `troll_test` checks each trap, and `level_test` plays a scripted run through every room to prove it can be beaten, plus a naive run to prove the troll gets you. If you change a room, update its runs in `tests/level_test.gd`.
