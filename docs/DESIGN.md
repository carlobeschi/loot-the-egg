# Design decisions

Things the game's owner asked for, kept here so they survive between sessions.

## Core loop
- Pick a class: Knight (sword), Wizard (staff) or Bowman (bow). Eerie music starts on class pick.
- Big forest map in 3D with first-person and third-person views and a Roblox-like blocky look (characters are rounded blocks).
- Dungeons are real-size towers scattered across the map, no portals. Floors are stacked and joined by stairs. Towers are spooky inside and have triangular detail outside.
- Each dungeon has a boss. The boss drops an egg. Deeper dungeons drop rarer eggs, and rare eggs are only an occasional drop. Taking an egg wakes everything, and you must run home.
- Beating a dungeon unlocks the next one on the map.
- Eggs cannot be bought. They hatch into pets that live in the pen and earn coins.

## Economy
- Pen has a pet limit, an upgrade sign and pad. The pen changes colour with each level.
- Coins buy health, speed and ability upgrades (the damage upgrade was removed) and weapon upgrades from a separate weapon shop building. There is also a general shop.
- 8 pet rarities. Higher dungeons make commons less likely.
- Rebirth: 12 levels, multiplier x1 up to x7 in 0.5 steps. Pets are kept. Easier than the first version.
- Equip Best button puts your best pets in the pen.
- Settings panel can show or hide pets.

## Worlds
- World 1: 3200x2080 map, 5 dungeon towers at a time (a sliding window over depths).
- World 2 (Ember Wastes): 4000x2600 map, 9 towers (depths 10-18, 5 floors each). Unlocked at the World Gate: 5 rebirths, a mythic pet, a certain fence level and cash. World 2 bosses are a bit easier.
- Pen plots for other players exist as a placeholder layout, for a later Roblox release.

## Balance (latest)
- 12 weapon tiers per class. Damage multiplier 1.6 (knight) or 1.7 (staff, bow) times (1 + 0.35 * tier).
- World 1 bosses were nerfed: health about 20% lower, hits about 25% lower, slams and charges less often, softer enrage. See CHANGELOG.

## Platform plan
- The JavaScript game is the working prototype and the source of truth for numbers.
- The goal is to post it on Roblox, rebuilt in Luau (see `roblox/`). `roblox/tools/export_config.js` copies the numbers over.
