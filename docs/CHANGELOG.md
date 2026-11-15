# Changelog

Versions are the published artifact versions of `game/index.html`. Earlier history was not tracked here.

## Unreleased
- Project turned into a repository (this commit history starts here).
- Roblox: combat (sword swing, staff bolt with blast, piercing arrows) worked out on the server; class picker; a generated test tower (Dungeon 1) with sleeping enemies and a boss that slams, summons help and enrages; dying with the egg loses it.
- Roblox: class abilities on Q (Shield Slam, Blink Burst, Arrow Volley), with a phone button that shows the cooldown.
- Roblox: Dungeons 1 to 9 south of town, each gate locked until you beat the one before (red/green per player), and the boss charge attack.
- Roblox: shops and screens. Town huts for the Blacksmith (weapon tiers), Trainer (health, speed, ability upgrades) and World Gate; the pen sign opens upgrade, sell and equip-best; the Rebirth button shows the requirements first.
- Roblox: `roblox/tools/luau_check.sh` type-checks the scripts with luau-lsp; `docs/TESTING.md` lists what to try per slice.
- Roblox: eggs are backpack items (one per rarity, with a count). Equip one and click in your pen to place it; it counts down, then press E to hatch it. Placed eggs are saved. The old Hatch button is gone. Asked for by Lorenzo after the first Play test.
- Roblox: fixes from the first Play test that Claude ran on Studio itself. Enemies no longer follow you across the map (they stay near where they spawned, unless you carry an egg); tower doors face the town; the boss egg's "Take" prompt can't be hidden by a nearby sign; shop windows fit small screens and sit in front of the HUD; class buttons no longer overlap.
- Roblox: fixes from a code review (remotes made before anything can wait, no endless wait without a Plots folder, saving off cleanly in an unpublished place, test cheats that actually reach the game's data, World 1 boss numbers matching the JS nerf).

## v55
- Sword and bow made smaller to match the staff; their glow effects shrunk too.

## v54
- Staff orb about 40% smaller, with smaller claws, ring, gems and glow.

## v53 - v52
- Characters and zombies use rounded geometry instead of sharp boxes, then smoother and rounder (heads nearly spherical).

## v51
- New Wizard staff (claw head, gold bands, pulsing orb glow, floating ring) and robe, cuffs, beard and hat details.

## v50
- Characters: belts, boots, gloves, capes, helmets, hair, quiver details.
- Terrain: soft light/dark ground patches, dirt patches, lava cracks in World 2, mushrooms, stumps, logs, ember crystals.

## v49 - v48
- Trees about 2.6x bigger, darker foliage, ground shadow under each tree, wider shadow area, wider trunks and spacing.

## v47
- World 1 bosses nerfed (less health, damage, slam and charge frequency, softer enrage).
