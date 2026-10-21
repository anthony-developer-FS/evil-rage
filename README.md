# Evil Rage

A punishing 2D precision platformer where the levels lie to you. Built with Godot 4.5.

## Run it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, no .NET needed).
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press F5. Room 1 loads. Beat all twelve rooms.

Controls: A/D or arrows to move, Space/K/Up to jump, R to restart, F11 or Alt+Enter to toggle fullscreen. Gamepad works too (stick or d-pad, A to jump).

## Resolution

The world is drawn into a 320x180 viewport and scaled up by whole numbers, so pixel art stays blocky and sharp: 6x at 1080p, 8x at 1440p and 12x at 4K. The HUD (death counter, taunts, room title) sits outside that viewport and is drawn at the screen's native resolution, so text stays crisp. The game starts fullscreen. Windowed mode opens at 1280x720 and can be resized.

`scenes/main.tscn` is the entry point: it owns the world viewport and the HUD and loads rooms into the viewport. A room run on its own with F6 adds its own HUD, so rooms are still easy to test in the editor. Put text a player reads in the HUD, not in a room, or it will be pixelated.

## Layout

| Path | What it is |
| --- | --- |
| `scripts/player.gd` | Kinematic controller: run, variable jump, coyote time, jump buffer, wall slide and wall jump |
| `resources/default_tuning.tres` | Every movement number. Edit it in the inspector to retune feel |
| `scripts/game.gd` | Autoload that keeps death counters and taunts across room reloads |
| `scenes/main.tscn` | Entry point: 320x180 world viewport plus a native-resolution HUD |
| `scripts/room.gd` | Base for every room: spawns the player, reloads the room on death |
| `scenes/objects/` | Reusable pieces: player, block, hazard (spikes), goal, spring, HUD |
| `scenes/trolls/` | Troll traps, each a drop-in scene (see below) |
| `scenes/rooms/room_01.tscn` to `room_06.tscn` | Part one: one troll per room, then all of them |
| `scenes/rooms/room_07.tscn` to `room_12.tscn` | Part two: decoy exits, springs, a wall-jump shaft and a crumbling bridge, then a finale that mixes them |
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
| Decoy goal | Looks exactly like the exit, kills on touch | none |

A spring (`scenes/objects/spring.tscn`) is not a trap but rooms use it as one. Place it on the floor: walking onto it gives a short hop, and landing on it with jump held launches the player about `power² / 1800` pixels. Rooms 8 and 10 lean on that difference.

Rooms reload entirely on death, so every troll trap resets for free. A new room is a scene whose root uses `room.gd` and contains `Player`, `Spawn`, `Goal` and `Hud`. Set the goal's `next_room` to chain rooms; leave it empty on the last room.

## Tests

```
GODOT=/path/to/godot ./run_tests.sh
```

Three suites: `movement_test` checks the controller, `troll_test` checks each trap, and `level_test` plays a scripted run through every room to prove it can be beaten, plus a naive run to prove the troll gets you. If you change a room, update its runs in `tests/level_test.gd`. To check only some rooms, pass their names: `godot --headless --path . res://tests/level_test.tscn -- room_09 room_10`. Set `LEVEL_TRACE=1` to print the player's path while you write a run.
