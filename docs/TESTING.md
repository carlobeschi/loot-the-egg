# Roblox test checklist

What to try after pulling `main`, one section per slice. Press **Play** in Studio with `rojo serve` running and
View > Output open. Paste anything red or orange back into the project thread.

Cheats (Studio only): switch to **Server** view, open View > Command Bar, and run for example
`print(game.ServerStorage.Cheat:Invoke("coins", 1000000))`. All commands are in `roblox/studio-tools/TestCheats.lua`.

## Slice 1: combat, test tower, boss (PR #1)
- [ ] You spawn at your pen; the sign shows your name; coins show top left.
- [ ] Knight / Wizard / Bowman buttons (bottom left) switch weapon, health and speed.
- [ ] Walk south into "Dungeon 1": enemies appear, you can go up the ramps.
- [ ] Clicking hurts enemies with all three weapons.
- [ ] The boss slams (red ring), calls for help and gets enraged below half health.

## Slice 2: eggs as items (PR #1)
- [ ] Beating the boss drops an egg; taking it wakes everything; reaching the middle banks it.
- [ ] The egg shows in the backpack bar as "<Rarity> Egg".
- [ ] Equipping it shows a green preview egg in your pen (red outside it); clicking places it.
- [ ] The placed egg counts down, wobbles when ready, and E hatches it into a pet.
- [ ] Leave and rejoin: placed eggs are still there. Cheat: `Invoke("eggs", 2)`.

## Slice 3: shops and screens
- [ ] Town has three huts: Blacksmith (red roof, west), Trainer (blue roof, east), World Gate (purple, north).
- [ ] Press E at the Blacksmith counter: one row per class, buying the next weapon takes the coins and
      changes the weapon in your hand. Tiers stop at 5 until World 2 is unlocked. Cheat: `Invoke("coins", 1000000)`.
- [ ] Press E at the Trainer: health, speed and ability levels for your current class; buying health raises
      max health, speed makes you faster.
- [ ] Press E at your pen's sign: Equip best, Upgrade pen (fence changes color, capacity +2), Sell (asks twice).
      Another player's sign says "This isn't your pen."
- [ ] The HUD's Rebirth button opens the Rebirth window with the requirements; it only works when both are met.
- [ ] World Gate shows the four requirements. Cheats for a quick check: `Invoke("rebirths", 5)`, `Invoke("pen", 7)`,
      `Invoke("coins", 20000000)` and a Mythic pet (hatch eggs from `Invoke("eggs", 2)`). Then Unlock, and the
      Blacksmith sells up to tier 11.

## Slice 4: Dungeons 1 to 9, locked doors, boss charge
- [ ] Nine towers south of town: Dungeons 1 to 5 in the first row, 6 to 9 further south. Signs say "Dungeon N".
- [ ] On a new save only Dungeon 1's gate is green; the others are red and solid, and walking in says
      "Dungeon N is locked". Cheat: `Invoke("depth", 4)` opens Dungeons 1 to 5.
- [ ] Beating Dungeon 1's boss says "Dungeon 2 is open now!" and its gate turns green.
- [ ] Deeper dungeons have more floors (up to 4) and tougher enemies.
- [ ] The boss sometimes shows a red strip on the floor and then dashes along it; getting hit knocks you back.
