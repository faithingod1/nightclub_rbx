# AGENTS.md — 2D Isometric Nightclub City Remake (Roblox Luau)

## 1. Project Vision
We are building a pure 2D isometric club-management game inspired by the 2010 Facebook Flash game *Nightclub City*, running inside Roblox via Rojo.
- **ZERO 3D Roblox elements:** `Players.CharacterAutoLoads` MUST remain `false`. Never use 3D `BasePart`, `Model`, `Humanoid`, or `Workspace` physics.
- **100% 2D UI Engine:** Render the entire isometric club, floor tiles, furniture, cartoon guests, staff, and Facebook-style bottom HUD inside `ScreenGui` instances (`IgnoreGuiInset = true`) created via Luau code.

## 2. Strict Roblox Compliance Rules (Non-Negotiable)
- **No Alcohol / Intoxication:** All bars are **"Mocktail / Neon Fizz / Energy Bars"**. Never use words like liquor, beer, vodka, drunk, wasted, or vomit. Troublemaker NPCs are called **"Rowdy Crashers"** (too much sugar rush / blocking the vibe).
- **No Romantic / Dating Animations:** Guests only queue, dance, chat, sit in VIP booths, drink mocktails, and tip cash.
- **Original Assets & Safe Audio:** Only reference `rbxassetid://` IDs stored in `GameConfig.luau`. Always render clean procedural UI fallback shapes/colors whenever an `AssetId` is `""` so every feature is immediately playable before final sprite sheets are uploaded.

## 3. Strict Roblox Luau Coding Standards
- Put `--!strict` at the top of every `.luau` file and share types via `ReplicatedStorage.Shared.Types`.
- Use `task.wait()`, `task.spawn()`, `task.delay()`, and `os.clock()`. **NEVER** use deprecated `wait()`, `spawn()`, `delay()`, or standard desktop Lua libraries (`io`, `os.execute`).
- Never use the deprecated 2nd parent argument of `Instance.new()`; always set `.Parent` last.
- Build ALL UI programmatically in Luau modules. Never rely on manual Studio `.rbxm` GUI instances.
- **Sprite Sheet Resolution Limit:** Roblox caps images at `1024x1024`. Animate 2D cartoon characters using `ImageLabel.ImageRectSize` and `ImageLabel.ImageRectOffset` on grid sprite sheets (e.g., `4x4` frames of `256x256`).
- **Isometric Depth Sorting (`ZIndex`):** Every object on tile `(gx, gy)` must compute `ZIndex = (gx + gy) * 10 + layerOffset` (`1` = floor tile, `3` = dancefloor pad, `5` = furniture & walking NPCs, `9` = floating cash/vibe popups).

## 4. Client / Server Split Architecture
- **Server (`src/server`):** Owns player Cash, Mocktail Stock, DJ Set Timer, Grid Placement validation, Popularity & Luxury totals, and DataStore persistence. Do NOT run per-frame NPC movement on the server.
- **Client (`src/client`):** Renders the draggable/zoomable 2D isometric canvas, animates 30–60 cartoon NPCs smoothly at 60 FPS via `RunService.RenderStepped`, plays music sets, and fires `RemoteFunction` / `RemoteEvent` requests for building, restocking, and DJ skills.