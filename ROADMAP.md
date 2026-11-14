# Antigravity Build Roadmap (Execute One Phase at a Time)

## Phase 1 — Isometric Viewport, Zoom & Hover Ghost Preview [COMPLETED]
Read `AGENTS.md` and inspect `src/`. Add mouse-wheel zoom (`UIScale` clamped between `0.5` and `1.8` on `IsometricWorld`), a glowing isometric hover cursor on the tile under the mouse when `SelectedBuildItem` is active, and a `Remove / Move Item` edit mode synced with `ClubServer`.

## Phase 2 — Full 2D Sprite Sheet Animator & Glossy Vector UI [COMPLETED]
Create `src/client/SpriteAnimator.luau` supporting `1024x1024` sprite sheets (`4x4` frames of `256x256` via `ImageRectOffset`/`ImageRectSize`) with automatic cartoon vector UI fallbacks when `AssetId == ""`. Style `TopHud` and `BottomDock` into a glossy 2010 Facebook Flash HUD with animated floating `+$Cash` popups.

## Phase 3 — Authentic Nightclub City Crowd AI & Bouncer AoE [COMPLETED]
Create `src/client/GuestController.luau`. Implement an entrance queue outside tile `(1,1)`, guests walking onto `DancePad` tiles to dance, `VIP` High Rollers seeking `VelvetVIPBooth` items, and occasional `RowdyCrasher` guests that lower nearby guest happiness unless covered by a `BouncerStation` red AoE ring (`EffectRadius`) that escorts them out.

## Phase 4 — Genre Playlists, Parody Celebrities & Club Expansion [COMPLETED]
Add a DJ Genre Selector modal (`Electro`, `HipHop`, `SynthPop`) hooked up to `SoundService`, parody celebrity VIP visits (e.g., 'Builderman VIP', 'DJ Blox') with bonus payout missions, and cash upgrades to expand `GridWidth`/`GridHeight` from `10x10` up to `20x20`.

## Phase 5 — DataStoreService Save/Load & Visiting Friends' Clubs [COMPLETED]
Create `src/server/DataManager.luau` using `DataStoreService` with session locking and `BindToClose` auto-save for `ClubState`. Add a Friends Bar along the bottom HUD (just like the Facebook original) that fetches online/saved club layouts so players can visit a friend's 2D club and tip their DJ booth.
## Phase 6 ? Visual Remake & Playable Polish [IMPLEMENTED ? STUDIO REVIEW PENDING]
Procedural 2:1 room floor, back walls, city facades and streets; recognizable furniture and animated dance pads; varied big-headed cartoon guests; illustrated shop cards and quieter guest labels. Cache room rendering across economic updates. Studio visual and performance review remains pending.
