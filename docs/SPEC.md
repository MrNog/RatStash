# RatStash — spec

Bag + bank addon for WoW 3.3.5a (Interface 30300). Bagnon look, AdiBags sorting, kept simple.
Mock: `docs/mock.html`.

## Windows
- Two windows: **Bags** and **Bank**, Bagnon style (one frame, title, search, money, free count).
- **Search** box per window: dims items that don't match.
- **Bags** button: shows the bag slots bar (backpack + 4 bags / bank + 7 bags). Drag a bag onto a slot to swap it; empty bank slots show "Buy".
- Bank is viewable offline (cached per character).

## Auto sort (always on, display only)
- Items are never moved inside the real bags; only the drawn order changes (like AdiBags). Works in combat.
- Fixed hidden order: pinned → raid loot → set pieces → gear → consumables → trade goods → quest → junk → empty slots.
- Inside a block, a fixed kind order: food → flask → elixir → potion → bandage → scroll → enhancement; gems → ore → herb → cloth → leather → meat → elemental…; gear in character-sheet slot order.
- Hearthstone is pinned by default (unpinning is remembered).
- New items slide in next to their kind; neighbours shift to make room.
- Stack overflow (e.g. fish 17 + 6) tops up the stack, remainder becomes a new stack right next to it.

## Layout setting (per window)
- **One grid**: everything in one grid, no headers.
- **One grid + sets** (bags default): one group per saved Equipment Manager set (pieces in bags only; worn pieces are NOT shown), then one grid.
- **Groups** (bank default): AdiBags-style blocks per category, always the same order; blocks with ≤4 items share a row; free space folded into one slot with a count.

## Pinned
- Alt-click or right-click an item to pin/unpin. Pinned items always come first (Hearthstone etc.). Small blue dot.

## Raid loot
- Items looted inside the current raid instance glow green (and show the BoP trade timer when there is one).
- Tracked by loot count per item, so 1 raid Primordial Saronite stays apart from your own 6.
- **Keep raid loot** merges them into your own stacks.
- Setting: when you are **master looter**, raid loot gets its own group ("N to hand out").
- With Okanvil loaded, as master looter the raid loot splits in two: **[HR] Reserved** (whatever `Okanvil.SoftRes.Blocked` refuses to roll: hard reserves, reserved BoE/Orb/Pattern/Frag) and **Raid loot** (free to roll; soft-reserved items stay here since they are still rolled).

## Item badges
- Gear: item level at the bottom, in the item's quality color.
- Gold **BoE** tag top-left on bind-on-equip gear.

## Virtual stacks (same rules as AdiBags `ShouldStack`)
- Merge unstackable items (3 identical rings → one slot "3").
- Merge stackable items (full stacks), optional "… including incomplete stacks".
- At vendor, bank, mail or trade: keep merged / split unstackable (default) / split incomplete too / split everything.
- Clicking a merged slot uses the first real slot.

## Out of scope
- Upgrade arrows / "is this an upgrade" (belongs to Okanvil loot, if ever).
- Guild bank, keyring.

## 3.3.5a notes
- No SetShown/SetEnabled — use Show/Hide.
- Equipment sets: GetNumEquipmentSets / GetEquipmentSetInfo / GetEquipmentSetItemIDs.
- Master looter: check raid ML before party ML (GetLootMethod).
- BoE / trade timer: tooltip scan.
- Never auto-focus the search box (it would eat W/A/S/D).
