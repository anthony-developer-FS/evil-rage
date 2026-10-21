extends Node
## Proves every prototype room can be beaten by playing a scripted run through it,
## and that the obvious naive route fails because of the troll. Run with:
##   godot --headless --path . res://tests/level_test.tscn
## Pass room names after "--" to check only those rooms, e.g. "-- room_07 room_08".
## Set LEVEL_KIND=solve or LEVEL_KIND=naive to play only that run.
## Exits with code 0 when every check passes, 1 otherwise.
##
## Script commands: ["right", x] / ["left", x] hold a direction until the player
## crosses x. ["jump", frames] holds jump for that many physics frames, keeping the
## current direction, or switches to the direction given as a third element, e.g.
## ["jump", 60, "left"]. ["hold", frames] keeps the direction. ["idle", frames] lets go.
## ["key", "left", x] holds that key until the player crosses x from either side,
## for when mirrored controls make the left key walk right.
## After the script ends the current direction is held until the run resolves.
##
## Rooms with Death or ghosts need the player to react, as a person would:
## ["until_cast"] keeps going until Death next lets something fly, ["until_near", px]
## until a saw, bullet or ghost comes within px of the player, ["until_clear"] until no
## saw or bullet is left flying, and ["tap", "left"]
## turns the player round without walking anywhere. ["warp"] keeps going until a
## portal moves the player, or walks that way first with ["warp", "right"].
## ["reflex", px] makes the player hop whenever a saw or bullet comes within px,
## whatever else the script is doing, until ["reflex", 0]. Death appears at a random spot,
## so rooms with him are played with several seeds; every one has to pass.
##
## Rooms that change after a death also get "retry_solve" and "retry_naive" runs,
## played as if the player had already died once in the room.

## Room 9: walk into the shaft, then wall jump between its walls until the top.
const SHAFT_CLIMB := [
	["right", 162.5], ["jump", 20], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8],
]

var runs := {
	"room_01": {
		"solve": [["right", 84], ["jump", 60], ["idle", 20], ["right", 142], ["jump", 60], ["right", 400]],
		"naive": [["right", 84], ["jump", 60], ["idle", 20], ["right", 148], ["jump", 8], ["right", 400]],
	},
	"room_02": {
		"solve": [["right", 66], ["jump", 40], ["right", 132], ["jump", 40], ["right", 188], ["jump", 60], ["right", 400]],
		"naive": [["right", 66], ["jump", 40], ["right", 132], ["jump", 40], ["right", 400]],
	},
	"room_03": {
		"solve": [["right", 275], ["idle", 30], ["left", 200], ["idle", 30], ["right", 220], ["jump", 60], ["idle", 30], ["right", 248], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_04": {
		"solve": [["right", 100], ["jump", 60], ["right", 400]],
		"naive": [["right", 113], ["jump", 60], ["right", 400]],
	},
	"room_05": {
		"solve": [["right", 136], ["idle", 1], ["left", 110], ["idle", 60], ["right", 128], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_06": {
		"solve": [["right", 50], ["jump", 60], ["right", 148], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_07": {
		"solve": [["right", 84], ["jump", 60], ["right", 150], ["jump", 60], ["right", 200], ["jump", 60], ["idle", 40], ["left", 240], ["jump", 60], ["left", 0]],
		"naive": [["right", 84], ["jump", 60], ["right", 400]],
	},
	"room_08": {
		"solve": [["right", 400]],
		"naive": [["right", 100], ["jump", 200], ["right", 400]],
	},
	"room_09": {
		# Same climb both times. Hopping off it onto the trapdoor is the trap.
		"solve": SHAFT_CLIMB + [["right", 175], ["idle", 30], ["right", 177], ["jump", 60], ["right", 400]],
		"naive": SHAFT_CLIMB + [["right", 400]],
	},
	"room_10": {
		"solve": [["right", 40], ["jump", 200], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_11": {
		"solve": [["right", 236], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_12": {
		"solve": [["right", 48], ["jump", 60], ["right", 140], ["jump", 60], ["right", 196], ["jump", 200], ["right", 400]],
		"naive": [["right", 76], ["jump", 60], ["right", 400]],
	},
	"room_13": {
		# Hop the rubble. The face only shoots along the floor.
		"solve": [["right", 70], ["jump", 60], ["right", 122], ["jump", 60], ["right", 186], ["jump", 60],
			["right", 240], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_14": {
		# Jump from the second stone straight to the fourth.
		"solve": [["right", 76], ["jump", 30], ["right", 128], ["jump", 60], ["right", 192], ["idle", 10],
			["right", 200], ["jump", 30], ["right", 400]],
		"naive": [["right", 76], ["jump", 30], ["right", 128], ["jump", 20], ["right", 160], ["jump", 20], ["right", 400]],
	},
	"room_15": {
		# Peek off the edge to set it off, back up onto the dais, wait out the volley.
		"solve": [["right", 44], ["left", 30], ["idle", 360], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_16": {
		"solve": [["right", 92], ["jump", 8], ["right", 188], ["jump", 8], ["right", 400]],
		"naive": [["right", 92], ["jump", 60], ["right", 188], ["jump", 60], ["right", 400]],
	},
	"room_17": {
		"solve": [["left", 0]],
		"naive": [["right", 400]],
	},
	"room_18": {
		# Run the bridge, then stop the moment the portcullis drops and hop over it.
		"solve": [["right", 214], ["idle", 30], ["right", 240], ["idle", 60], ["left", 226], ["idle", 20],
			["right", 230], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_19": {
		# Each hole fires as you get near it. Stop, let the darts land, move on.
		"solve": [["right", 48], ["idle", 80], ["right", 110], ["idle", 80], ["right", 174], ["idle", 80], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_20": {
		# Land on the spring with jump held, steer left onto the ledge, walk into the wall.
		"solve": [["right", 30], ["jump", 75], ["jump", 90, "left"], ["left", 0]],
		"naive": [["right", 400]],
	},
	"room_21": {
		# Wait for the lift to come back down, step on, and lean on the cliff until it is level.
		"solve": [["right", 100], ["idle", 300], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_22": {
		# Poke the trigger, back off, then run under while the press is up.
		"solve": [["right", 120], ["left", 100], ["idle", 100], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_23": {
		"solve": [["right", 70], ["idle", 60], ["right", 88], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_24": {
		# Let each press slam before going under it, waiting in the gaps between them.
		"solve": [["right", 70], ["idle", 70], ["right", 140], ["idle", 60], ["right", 212], ["idle", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_25": {
		"solve": [["right", 88], ["jump", 60], ["right", 240], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_26": {
		"solve": [["right", 76], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_27": {
		# Step off, hang in the gap until under the first shelf, then drift right.
		"solve": [["right", 60], ["idle", 150], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_28": {
		# Hop stone to stone without stopping, and skip the narrow one.
		"solve": [["right", 42], ["jump", 20], ["right", 82], ["jump", 20], ["right", 122], ["jump", 14],
			["right", 178], ["jump", 20], ["right", 220], ["jump", 20], ["right", 236], ["jump", 20], ["right", 250], ["jump", 120], ["right", 400]],
		"naive": [["right", 42], ["jump", 20], ["right", 82], ["jump", 20], ["right", 124], ["jump", 8],
			["right", 400]],
	},
	"room_29": {
		"solve": [["right", 92], ["jump", 8], ["right", 400]],
		"naive": [["right", 92], ["jump", 120], ["right", 400]],
	},
	"room_30": {
		# Board the ferry before it leaves, chase the exit off the island, jump into the
		# draft and float right past the crumbly lip of the rock.
		"solve": [["right", 80], ["idle", 300], ["right", 190], ["jump", 120], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_31": {
		# Jump the pit and swap to left the moment the mirror flips you.
		"solve": [["right", 112], ["jump", 30], ["right", 143], ["key", "left", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_32": {
		# Walk until the hidden mirror turns you round, then swap keys before the spikes.
		"solve": [["right", 157], ["key", "left", 400]],
		"naive": [["right", 400]],
	},
	"room_33": {
		# First try: the patch over the pit is rotten, so jump it. After a death it is
		# solid, and jumping it lands on spikes instead.
		"solve": [["right", 150], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
		"retry_solve": [["right", 400]],
		"retry_naive": [["right", 150], ["jump", 60], ["right", 400]],
	},
	"room_34": {
		# Swap to left over the first pit, back to right over the second, and to left
		# again when the hidden one turns you round at the end.
		"solve": [["right", 88], ["jump", 30], ["right", 112], ["key", "left", 196], ["jump", 30],
			["key", "left", 224], ["right", 273], ["key", "left", 400]],
		"naive": [["right", 88], ["jump", 30], ["right", 400]],
	},
	"room_35": {
		"solve": [["key", "left", 136], ["jump", 60], ["key", "left", 400]],
		"naive": [["right", 400]],
		"retry_solve": [["right", 136], ["jump", 14], ["key", "left", 400]],
		"retry_naive": [["key", "left", 136], ["jump", 60], ["key", "left", 400]],
	},
	"room_36": {
		# On the ceiling a jump goes down: hop the hole in it.
		"solve": [["right", 170], ["jump", 30], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_37": {
		"solve": [["right", 96], ["jump", 30], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_38": {
		# A short hop stays under the hidden field.
		"solve": [["right", 112], ["jump", 8], ["right", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_39": {
		# Let each piston stab the ceiling before walking over it.
		"solve": [["right", 96], ["idle", 72], ["right", 168], ["idle", 36], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_40": {
		# Ride the lift, jump into the draft, swap keys at the mirror, hop the biting
		# door into the flip, then walk back along the ceiling to the real exit.
		"solve": [["right", 80], ["idle", 300], ["right", 136], ["jump", 60], ["right", 200], ["key", "left", 264],
			["jump", 40], ["key", "left", 306], ["key", "right", 200]],
		"naive": [["right", 400]],
	},
	"room_41": {
		# Creep up until the sinkhole slides ahead to where you would have landed,
		# then jump it there.
		"solve": [["right", 116], ["idle", 60], ["right", 176], ["jump", 60], ["right", 400]],
		"naive": [["right", 130], ["jump", 60], ["right", 400]],
	},
	"room_42": {
		# Every jump moves the hole. Hop on the spot to send it ahead, walk over where
		# it was, then jump it so it goes back behind you.
		"solve": [["jump", 10], ["idle", 60], ["right", 151], ["jump", 60], ["right", 400]],
		"naive": [["right", 104], ["jump", 60], ["right", 400]],
	},
	"room_43": {
		# Take the boots, leap before the hole notices you, and jump again in the air.
		"solve": [["right", 100], ["jump", 24], ["hold", 3], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_44": {
		"solve": [["jump", 10], ["idle", 60], ["right", 122], ["jump", 60], ["right", 186], ["idle", 40],
			["right", 242], ["jump", 60], ["right", 400]],
		"naive": [["right", 82], ["jump", 60], ["right", 400]],
	},
	"room_45": {
		# Jump the first hole before it lunges. That jump sends the second one ahead.
		"solve": [["right", 74], ["jump", 60], ["right", 242], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_46": {
		# Stand on the mark until the frost sinks, then run before it comes back.
		"solve": [["right", 164], ["idle", 476], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_47": {
		# Grab the amulet, back onto the square, then run and vault the crates.
		"solve": [["right", 124], ["left", 88], ["idle", 456], ["right", 156], ["jump", 40], ["right", 228],
			["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_48": {
		# Ignore the mark and the boots. Watch where the frost leaves a gap.
		"solve": [["right", 212], ["idle", 490], ["right", 244], ["jump", 60], ["right", 400]],
		"naive": [["right", 104], ["idle", 900]],
	},
	"room_49": {
		"solve": [["right", 124], ["idle", 420], ["right", 194], ["jump", 40], ["right", 228], ["jump", 40],
			["right", 260], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_50": {
		# Hop the mimic, wait it out on the pillar, then run.
		"solve": [["right", 98], ["jump", 60], ["right", 190], ["jump", 40], ["right", 204], ["idle", 320],
			["right", 400]],
		"naive": [["right", 400]],
	},
	"room_51": {
		# Jump over the loose plate instead of walking on it.
		"solve": [["right", 100], ["jump", 60], ["right", 166], ["jump", 60], ["right", 400]],
		"naive": [["right", 166], ["jump", 60], ["right", 400]],
	},
	"room_52": {
		# Hop the chest, then bound stone to stone without ever stopping.
		"solve": [["right", 36], ["jump", 12], ["right", 90], ["jump", 60], ["right", 156], ["jump", 60],
			["right", 222], ["jump", 60], ["right", 400]],
		"naive": [["right", 36], ["jump", 12], ["right", 90], ["jump", 60], ["right", 156], ["jump", 60],
			["right", 214], ["idle", 60], ["right", 400]],
	},
	"room_53": {
		# Wake the wall from the edge, then jump onto it.
		"solve": [["right", 104], ["idle", 40], ["right", 112], ["jump", 60], ["right", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_54": {
		"solve": [["right", 124], ["jump", 60], ["right", 182], ["jump", 60], ["right", 232], ["jump", 24], ["hold", 3],
			["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_55": {
		# Over the plate, wake the wall and climb it, then leap off the end without stopping.
		"solve": [["right", 36], ["jump", 60], ["right", 96], ["idle", 90], ["right", 106], ["jump", 60],
			["right", 228], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_56": {
		# Moon boots: how long jump is held decides the height. Enough for the wall,
		# not so much that the ceiling gets you.
		"solve": [["right", 100], ["jump", 20], ["right", 400]],
		"naive": [["right", 100], ["jump", 60], ["right", 400]],
	},
	"room_57": {
		# Tap over the chest, tap over the pit.
		"solve": [["right", 40], ["jump", 1], ["right", 128], ["jump", 4], ["right", 400]],
		"naive": [["right", 128], ["jump", 4], ["right", 400]],
	},
	"room_58": {
		"solve": [["right", 104], ["idle", 20], ["jump", 40], ["right", 140], ["right", 400]],
		"naive": [["right", 104], ["idle", 20], ["jump", 60], ["right", 400]],
	},
	"room_59": {
		"solve": [["right", 48], ["jump", 8], ["right", 150], ["jump", 10], ["right", 190], ["jump", 1], ["right", 236],
			["jump", 1], ["right", 400]],
		"naive": [["right", 48], ["jump", 60], ["right", 400]],
	},
	"room_60": {
		# Hop to send the hole ahead, jump it so it goes back, climb the wall, skip the chest.
		"solve": [["jump", 1], ["idle", 60], ["right", 140], ["jump", 10], ["hold", 80], ["jump", 22], ["right", 268],
			["jump", 1], ["right", 400]],
		"naive": [["right", 98], ["jump", 4], ["right", 400]],
	},
	# The Rift Ruins: the first portals are honest. Jumping over them is what kills.
	"room_61": {
		"solve": [["right", 400]],
		"naive": [["right", 100], ["jump", 60], ["right", 400]],
	},
	"room_62": {
		"solve": [["right", 400]],
		"naive": [["right", 56], ["jump", 60], ["right", 400]],
	},
	"room_63": {
		"solve": [["right", 400]],
		"naive": [["right", 196], ["jump", 60], ["right", 400]],
	},
	"room_64": {
		# Hop the portal and climb the stairs. The portal leads to a door that bites.
		"solve": [["right", 36], ["jump", 60], ["right", 92], ["jump", 60], ["right", 132], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_65": {
		# Only the third portal goes to the vault.
		"solve": [["right", 60], ["jump", 60], ["right", 132], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	# The Rift Labyrinth. In every cell, walk into the middle portal or jump it for
	# the one at the end. Only one string of choices reaches the exit.
	"room_66": {
		"solve": [["right", 30], ["jump", 30], ["warp"], ["warp", "right"], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_67": {
		"solve": [["warp", "right"], ["right", 246], ["jump", 30], ["warp"], ["warp", "right"], ["right", 400]],
		"naive": [["right", 30], ["jump", 30], ["right", 400]],
	},
	"room_68": {
		# Every portal wears the color of where it goes, and red ones go to the spikes.
		"solve": [["warp", "right"], ["right", 30], ["jump", 30], ["warp"], ["warp", "right"], ["right", 246],
			["jump", 30], ["warp"], ["warp", "right"], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_69": {
		# Same colors as 68, all lies: the red ones are the way.
		"solve": [["right", 246], ["jump", 30], ["warp"], ["warp", "right"], ["right", 138], ["jump", 30], ["warp"],
			["warp", "right"], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_70": {
		# Walking everywhere goes round in circles; jumping everywhere hits the spikes.
		"solve": [["warp", "right"], ["right", 138], ["jump", 30], ["warp"], ["warp", "right"], ["right", 246],
			["jump", 30], ["warp"], ["warp", "right"], ["right", 30], ["jump", 30], ["warp"], ["right", 400]],
		"naive": [["right", 30], ["jump", 30], ["right", 400]],
	},
	# The Golden Hoard. The first coins are honest, and show where to jump.
	"room_71": {
		"solve": [["right", 112], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_72": {
		"solve": [["right", 40], ["jump", 60], ["right", 92], ["jump", 60], ["right", 148], ["jump", 60],
			["right", 220], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_73": {
		"solve": [["right", 146], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_74": {
		# The spinning coins in the bridge are just coins. Jump them.
		"solve": [["right", 140], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_75": {
		# Edge up to the coin under the low ceiling, back off while it blows, then
		# hop the bomb in the bridge.
		"solve": [["right", 118], ["left", 80], ["idle", 60], ["right", 212], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	# The Reaper's Crypt. Death rises across the room from the player. His saws go
	# where the player was when he threw them, so step aside each time, and never wait
	# in one spot.
	"room_76": {
		"solve": [["right", 104], ["idle", 1], ["until_cast"], ["left", 80], ["idle", 1], ["until_cast"], ["right", 104],
			["idle", 30], ["right", 136], ["idle", 230], ["right", 400]],
		"naive": [["right", 108], ["idle", 300], ["right", 136], ["idle", 230], ["right", 400]],
	},
	"room_77": {
		# His growing saws stay where the player stood. Bait them away from the lift.
		"solve": [["idle", 1], ["until_cast"], ["right", 60], ["idle", 1], ["until_cast"], ["right", 216], ["idle", 150],
			["right", 400]],
		"naive": [["right", 216], ["idle", 350], ["right", 400]],
	},
	"room_78": {
		# His chasing saws are faster than the player and steer, but break on the ground.
		# Duck into each grave until one does, then go.
		"solve": [["right", 88], ["idle", 1], ["until_cast"], ["until_clear"], ["jump", 60, "right"], ["right", 168],
			["idle", 1], ["until_cast"], ["until_clear"], ["jump", 60, "right"], ["right", 240], ["idle", 1], ["until_cast"],
			["until_clear"], ["jump", 60, "right"], ["right", 400]],
		"naive": [["right", 72], ["jump", 30], ["right", 152], ["jump", 30], ["right", 224], ["jump", 30], ["right", 400]],
	},
	"room_79": {
		# Hop the bullets as they come.
		"solve": [["reflex", 48], ["right", 112], ["jump", 60], ["right", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_80": {
		# Duck each saw and each bullet in a grave, but not the last grave.
		"solve": [["right", 104], ["idle", 1], ["until_cast"], ["until_clear"], ["until_cast"], ["until_clear"],
			["jump", 60, "right"], ["right", 184], ["idle", 1], ["until_cast"], ["until_clear"], ["until_cast"],
			["until_clear"], ["jump", 60, "right"], ["right", 236], ["jump", 60], ["right", 400]],
		"naive": [["right", 88], ["jump", 30], ["right", 168], ["jump", 30], ["right", 240], ["jump", 30], ["right", 400]],
	},
	# The Haunted Manor. Ghosts only come while the player looks away from them.
	"room_81": {
		# Face the ghost while the ferry comes.
		"solve": [["right", 104], ["tap", "left"], ["idle", 470], ["right", 128], ["idle", 200], ["right", 400]],
		"naive": [["right", 104], ["idle", 470], ["right", 128], ["idle", 200], ["right", 400]],
	},
	"room_82": {
		# One on each side: watch one, then the other, until the lift goes.
		"solve": [["idle", 120], ["tap", "left"], ["idle", 400], ["right", 400]],
		"naive": [["idle", 520], ["right", 400]],
	},
	"room_83": {
		# The coin over the bridge is a bomb. Set it off and back away, which faces
		# the ghost, then cross once it has gone.
		"solve": [["right", 146], ["left", 110], ["idle", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_84": {
		# Face the ghost and hop his bullets while the ferry comes.
		"solve": [["reflex", 30], ["right", 104], ["tap", "left"], ["idle", 470], ["right", 148], ["idle", 200],
			["reflex", 56], ["right", 400]],
		"naive": [["reflex", 30], ["right", 104], ["idle", 470], ["right", 148], ["idle", 200], ["right", 400]],
	},
	"room_85": {
		# Jump the first portal, which only goes back. Over the wall, duck each saw in a
		# grave, facing back the way you came for the ghost.
		"solve": [["right", 70], ["jump", 60], ["warp"], ["right", 208], ["idle", 1], ["tap", "left"], ["until_cast"],
			["until_clear"], ["jump", 60, "right"], ["right", 256], ["idle", 1], ["tap", "left"], ["until_cast"],
			["until_clear"], ["jump", 60, "right"], ["right", 400]],
		"naive": [["right", 400]],
	},
}

## Seeds for rooms where Death picks his spot at random.
const SEEDS := [1, 2, 3, 4, 5]

var _failures := 0


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	for room_name in runs:
		if not only.is_empty() and not room_name in only:
			continue
		var seeds := SEEDS if _has_reaper(room_name) else [0]
		for kind: String in runs[room_name]:
			if OS.get_environment("LEVEL_KIND") not in ["", kind, kind.trim_prefix("retry_")]:
				continue
			var deaths := 1 if kind.begins_with("retry_") else 0
			for s: int in seeds:
				seed(s)
				var result: String = await _play(room_name, runs[room_name][kind], deaths)
				var ok: bool = (result == "goal") == kind.ends_with("solve")
				var label := kind if seeds.size() == 1 else "%s (seed %d)" % [kind, s]
				print("%s  %s %s -> %s" % ["ok  " if ok else "FAIL", room_name, label, result])
				if not ok:
					_failures += 1
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _play(room_name: String, script: Array, deaths := 0) -> String:
	var path := "res://scenes/rooms/%s.tscn" % room_name
	# Pretend the player is already in this room with that many deaths, so
	# retry variants pick their layout and the room keeps the count.
	Game.enter_room(path)
	Game.room_deaths = deaths
	var room: Room = load(path).instantiate()
	# Keep the run inside this test: no scene changes, no reloads.
	room.get_node("Goal").next_room = ""
	add_child(room)
	room.player.died.disconnect(room._on_player_died)
	var state := {"result": ""}
	room.player.died.connect(func() -> void: state.result = "dead")
	room.get_node("Goal").reached.connect(func() -> void: state.result = "goal")
	# Set LEVEL_TRACE=1 to print the player's path while writing a run.
	var start_frame := Engine.get_physics_frames()
	var trace := func() -> void:
		if Engine.get_physics_frames() % 6 == 0 and state.result == "":
			var t := (Engine.get_physics_frames() - start_frame) / 120.0
			var line := "      %5.2fs %s v%s" % [t, room.player.global_position.round(), room.player.velocity.round()]
			for node in room.get_children():
				if node is Saw or node is Bullet or node is Ghost or node is Reaper:
					line += "  %s%s" % [node.get_class() if node.get_script() == null else node.get_script().get_global_name(), node.global_position.round()]
			print(line)
	if OS.get_environment("LEVEL_TRACE") != "":
		get_tree().physics_frame.connect(trace)

	var warps := [0]
	room.player.teleported.connect(func() -> void: warps[0] += 1)
	var casts := [0]
	for node in room.get_children():
		if node is Reaper:
			node.cast.connect(func(_what: StringName) -> void: casts[0] += 1)

	# Reflex hops: [reach in px, frames left holding jump].
	var reflex := [0.0, 0]
	var reflexes := func() -> void:
		if reflex[1] > 0:
			reflex[1] -= 1
			if reflex[1] == 0:
				Input.action_release("jump")
		elif reflex[0] > 0.0 and room.player.is_on_floor() and _nearest_threat(room, false) < reflex[0]:
			Input.action_press("jump")
			reflex[1] = 20
	get_tree().physics_frame.connect(reflexes)

	var dir := ""
	for cmd in script:
		if state.result != "":
			break
		match cmd[0]:
			"right", "left":
				_set_dir(cmd[0])
				dir = cmd[0]
				for i in 600:
					var x := room.player.global_position.x
					if (dir == "right" and x >= cmd[1]) or (dir == "left" and x <= cmd[1]) or state.result != "":
						break
					await get_tree().physics_frame
			"key":
				_set_dir(cmd[1])
				dir = cmd[1]
				var was_left: bool = room.player.global_position.x < cmd[2]
				for i in 600:
					if (room.player.global_position.x < cmd[2]) != was_left or state.result != "":
						break
					await get_tree().physics_frame
			"jump":
				if cmd.size() > 2:
					_set_dir(cmd[2])
					dir = cmd[2]
				Input.action_press("jump")
				await _frames(cmd[1], state)
				Input.action_release("jump")
			"hold":
				await _frames(cmd[1], state)
			"warp":
				if cmd.size() > 1:
					_set_dir(cmd[1])
					dir = cmd[1]
				var before: int = warps[0]
				for i in 600:
					if warps[0] > before or state.result != "":
						break
					await get_tree().physics_frame
			"until_cast":
				var before: int = casts[0]
				for i in 1200:
					if casts[0] > before or state.result != "":
						break
					await get_tree().physics_frame
			"until_clear":
				for i in 1200:
					if _nearest_threat(room, false) == INF or state.result != "":
						break
					await get_tree().physics_frame
			"until_near":
				for i in 1200:
					if _nearest_threat(room) < cmd[1] or state.result != "":
						break
					await get_tree().physics_frame
			"reflex":
				reflex[0] = float(cmd[1])
			"tap":
				_set_dir(cmd[1])
				await _frames(1, state)
				_set_dir(dir)
			"idle":
				_set_dir("")
				dir = ""
				await _frames(cmd[1], state)
	await _frames(600, state)
	if state.result == "":
		print("      timed out with player at ", room.player.global_position, " goal at ", room.get_node("Goal").global_position)
	if get_tree().physics_frame.is_connected(trace):
		get_tree().physics_frame.disconnect(trace)
	get_tree().physics_frame.disconnect(reflexes)
	_set_dir("")
	Input.action_release("jump")
	room.queue_free()
	await get_tree().physics_frame
	return state.result if state.result != "" else "timeout"


func _has_reaper(room_name: String) -> bool:
	var room: Node = load("res://scenes/rooms/%s.tscn" % room_name).instantiate()
	var found := room.get_children().any(func(node: Node) -> bool: return node is Reaper)
	room.free()
	return found


## How far the closest saw, bullet or awake ghost is from the middle of the player.
func _nearest_threat(room: Room, ghosts := true) -> float:
	var me := room.player.global_position + Vector2(0, -7)
	var best := INF
	for node in room.get_children():
		if node is Saw or node is Bullet or (ghosts and node is Ghost and node.awake):
			best = minf(best, me.distance_to(node.global_position))
	return best


func _set_dir(dir: String) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if dir != "":
		Input.action_press("move_" + dir)


func _frames(n: int, state: Dictionary) -> void:
	for i in n:
		if state.result != "":
			return
		await get_tree().physics_frame
