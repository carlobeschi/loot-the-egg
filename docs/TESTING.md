# Roblox test checklist

What to try after pulling `main`, one section per slice. Press **Play** in Studio with `rojo serve` running and
View > Output open. Paste anything red or orange back into the project thread.

Cheats (Studio only): switch to **Server** view, open View > Command Bar, and run for example
`print(game.ServerStorage.Cheat:Invoke("coins", 1000000))`. All commands are in `roblox/studio-tools/TestCheats.lua`.
If the Command Bar runs on the Client even with Server selected (newer Studio does this), use the same commands from the
client: `print(game.ReplicatedStorage.StudioCheat:InvokeServer("coins", 1000000))`. It only exists in Studio.

Claude can also run these checks itself on Carlo's Mac (Studio in Play mode, driven through the Command Bar).
Last run: 2026-11-15, slices 1 to 5 passed after the fixes in the "first Studio test" PR, and slice 6 passed
in full (including clearing Dungeon 10 and banking its egg in the World 2 town).

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
- [ ] Tower doors face the town. Walk out of a dungeon and away: the enemies stop following you after
      about 45 studs and walk back (unless you carry an egg, then they chase you all the way).
- [ ] The boss sometimes shows a red strip on the floor and then dashes along it; getting hit knocks you back.

## Slice 5: class abilities
- [ ] Press Q (or the Ability button on a phone, Y on a controller). The button counts down the cooldown (7 s,
      shorter with Trainer "Ability" levels).
- [ ] Knight, Shield Slam: a gold ring, nearby enemies get hurt and pushed back (the boss only a little).
- [ ] Wizard, Blink Burst: a purple blast where you stand, then you jump forward; you never go through walls.
- [ ] Bowman, Arrow Volley: a fan of 7 arrows (more with Ability levels) that each go through 2 enemies.

## Slice 6: World 2 (Ember Wastes)
- [ ] Unlock World 2 (cheat: `Invoke("world2")`), open the World Gate: there is a "Ember Wastes: Dungeons 10 to 18"
      row with a Travel button. Travel puts you in the World 2 town with orange, smoky light.
- [ ] Dungeon 10 (straight south of the town) fills with enemies when you walk in. Dungeon 11 is locked and pushes
      you back out. Cheat: `Invoke("depth2", 3)` opens Dungeons 10 to 13.
- [ ] Clear a World 2 dungeon, take the egg and bring it to the World 2 town plaza: it goes in your backpack, and
      the next dungeon opens. Cheat for a quick clear: walk in so it fills, then `Invoke("kill", 10)`.
- [ ] You can't travel while carrying an egg ("Bring the egg to town first!").
- [ ] Die in World 2: you come back in the World 2 town, not at home.
- [ ] The portal behind the town sign ("Go home", press E) takes you back to your plot with normal light.

## Slice 7: ready for more than one player
- [ ] Save lock: in Studio, NOT in Play mode, paste `roblox/studio-tools/TestSaveLock.lua` into the Command Bar.
      Every line says PASS.
- [ ] Egg alarm: take an egg from one dungeon. Only that dungeon's enemies wake up and chase you; enemies in other
      dungeons stay asleep. Banking it calms them down.
- [ ] With a published place and two players (Test > Clients and Servers, 2 players): one player's egg doesn't
      wake the dungeon the other player is in.
