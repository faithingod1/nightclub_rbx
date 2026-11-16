# CARBON.md — Complete Technical Specification & Codebase Reference
**Project:** NeonClubCity2D (2D Isometric Nightclub City Remake in Roblox Luau)  
**Target Engine:** Roblox (via Rojo), 100% 2D UI inside `ScreenGui`  
**Compliance Standard:** Strict Luau (`--!strict`), Roblox Community Standards (Clean / Mocktail Only)  
**Repository:** `https://github.com/faithingod1/nightclub_rbx.git`

---

## 1. Project Vision & Architecture Principles

### 1.1 The Core Concept
A faithful remake of the classic 2010 Facebook Flash game *Nightclub City*, running completely inside Roblox. Players build, expand, customize, and operate their own 2D isometric neon nightclub:
- Serving non-alcoholic Mocktails / Neon Fizz energy drinks.
- Managing DJ sets, playlists, and interactive DJ skills (`RefreshSet`, `DropTheBass`, `MicShoutout`).
- Hiring bouncers to protect guest happiness from Rowdy Crashers.
- Hosting parody celebrity VIP visits (Builderbeat VIP, DJ Blox, Pixel Popstar).
- Customizing their avatar using 2D cartoon chibi character artwork.
- Visiting friends' clubs to view layouts and tip their DJ booths.

### 1.2 The 100% 2D ScreenGui Mandate (Non-Negotiable)
- **ZERO 3D Roblox Elements:** `Players.CharacterAutoLoads` is set to `false` on both server and client.
- **Never instantiate:** `BasePart`, `MeshPart`, `Model`, `Humanoid`, `SpecialMesh`, or 3D `Workspace` physics.
- **Render Surface:** Everything runs inside a single root `ScreenGui` with:
  ```luau
  Screen.ResetOnSpawn = false
  Screen.IgnoreGuiInset = true
  Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
  ```
- **World Canvas:** Isometric tiles, furniture, walls, drop shadows, guests, and bouncers are all 2D GUI elements (`Frame`, `ImageLabel`, `TextLabel`) parented to an `IsometricWorld` canvas.
- **Zooming:** Handled via a `UIScale` component on `IsometricWorld`, clamped strictly between `0.5` and `1.8`.

### 1.3 Strict Roblox Compliance Rules
- **No Alcohol or Intoxication:** All bars are **"Mocktail / Neon Fizz / Energy Bars"**. Never reference liquor, beer, wine, vodka, getting drunk, wasted, or vomiting.
- **No Romantic or Dating Tropes:** Guests dance, queue, chat, drink energy fizz, sit in VIP lounges, and tip cash.
- **No Violence:** Troublemakers are **"Rowdy Crashers"** (high on sugar/energy, blocking the dancefloor vibe). Bouncers politely escort them to the street exit.
- **Original Assets & Procedural Fallbacks:** Roblox `rbxassetid://` IDs are stored only in `GameConfig.luau`. When `AssetId == ""` (the default), procedural vector UI fallbacks render clean, glossy, fully animated graphics. Never invent mock or unverified asset IDs.

---

## 2. Directory & File Organization

```
nightclub_roblox/
├── default.project.json             # Rojo project file mapping shared, server, client
├── aftman.toml                      # Toolchain manager (rojo, stylua)
├── AGENTS.md                        # Master project guidelines & coding standards
├── ROADMAP.md                       # Phase-by-phase implementation status
├── CARBON.md                        # Complete project architectural reference (this file)
├── nightclub_roblox.rbxlx           # Compiled Roblox Studio XML place file
│
├── assets/
│   └── characters/
│       ├── README.md                # Decal upload guide & sprite sheet layout documentation
│       ├── guest-ponytail-1024.png  # Female guest transparent 1024x1024 4x4 atlas (32bpp ARGB)
│       └── guest-teal-1024.png      # Male guest transparent 1024x1024 4x4 atlas (32bpp ARGB)
│
├── src/
│   ├── shared/
│   │   ├── Types.luau               # Central Luau type declarations (--!strict)
│   │   ├── GameConfig.luau          # Master constants, catalog, palettes, pricing, DJ skills
│   │   ├── IsometricMath.luau       # 2D isometric projection, coordinate math, ZIndex sorting
│   │   └── Appearance.luau          # Character appearance validation, bounds, and defaults
│   │
│   ├── client/
│   │   ├── ClubClient.client.luau   # Main client controller: input, render loop, pan/zoom, HUD
│   │   ├── SpriteAnimator.luau      # 2D character animator (dual atlas/procedural vector engine)
│   │   ├── CharacterCreator.luau    # "MY LOOK" 3x live preview modal & appearance editor
│   │   ├── GuestController.luau     # Crowd simulation, queues, bouncer AoE, VIP routing
│   │   ├── GuestNavigation.luau     # 2D grid BFS pathfinding around placed furniture
│   │   ├── MusicController.luau     # SoundService playlist sequencer with genre fallbacks
│   │   ├── SocialPanel.luau         # Friends bar, visiting clubs, tipping DJ, mission HUD
│   │   ├── ClubArt.luau             # Procedural room geometry (walls, neon strips, furniture)
│   │   ├── GlossyUI.luau            # 2010 Flash-style metallic/glossy UIGradient button styler
│   │   └── HudIcons.luau            # Procedural vector toolbar icons (records, speakers, mugs)
│   │
│   └── server/
│       ├── ClubServer.server.luau   # Player lifecycle, remote handlers, economy ticks, autosave
│       ├── ClubRules.luau           # Club state validation, starter layouts, expansion, celebrities
│       └── DataManager.luau         # DataStoreService session leasing, retry logic, offline tips
│
└── tests/
    ├── art.spec.luau / run-art.mjs         # Room mesh generation, instance count benchmarks
    ├── character.spec.luau / run-character.mjs # Appearance bounds, creator flow, animator cleanup
    ├── crowd.spec.luau / run-crowd.mjs     # Crowd queue, pathfinding, bouncer escort, happiness
    ├── music.spec.luau / social.spec       # Playlist loop, volume, social actions
    ├── server.spec.luau / run-server.mjs   # DataStore leasing, remote protection, offline tips
    ├── pan.spec.luau / run-pan.mjs         # Mouse panning, boundary clamping, zoom scale
    └── *-mocks.luau                        # Lightweight headless Roblox environment mocks
```

---

## 3. Mathematical Foundations & Coordinate Systems

### 3.1 Tile Constants
```luau
GameConfig.TILE_WIDTH = 128   -- Width of an isometric tile diamond in pixels
GameConfig.TILE_HEIGHT = 64   -- Height of an isometric tile diamond in pixels
```

### 3.2 Grid to Screen Projection
In isometric 2:1 projection:
$$\text{screenX} = (gx - gy) \times \frac{\text{TILE\_WIDTH}}{2} = (gx - gy) \times 64$$
$$\text{screenY} = (gx + gy) \times \frac{\text{TILE\_HEIGHT}}{2} = (gx + gy) \times 32$$

Implemented in `src/shared/IsometricMath.luau`:
```luau
function IsometricMath.gridToScreen(gx: number, gy: number): Vector2
    local sx = (gx - gy) * (GameConfig.TILE_WIDTH * 0.5)
    local sy = (gx + gy) * (GameConfig.TILE_HEIGHT * 0.5)
    return Vector2.new(sx, sy)
end
```

### 3.3 Screen to Grid Inverse Projection
To transform screen coordinates $(sx, sy)$ back to grid tile coordinates $(gx, gy)$:
$$a = \frac{sx}{\text{TILE\_WIDTH} / 2} = \frac{sx}{64}$$
$$b = \frac{sy}{\text{TILE\_HEIGHT} / 2} = \frac{sy}{32}$$
$$gx = \text{round}\left(\frac{a + b}{2}\right)$$
$$gy = \text{round}\left(\frac{b - a}{2}\right)$$

```luau
function IsometricMath.screenToGrid(sx: number, sy: number): (number, number)
    local a = sx / (GameConfig.TILE_WIDTH * 0.5)
    local b = sy / (GameConfig.TILE_HEIGHT * 0.5)
    local gx = math.round((a + b) * 0.5)
    local gy = math.round((b - a) * 0.5)
    return gx, gy
end
```

### 3.4 Mouse Cursor & Zoom Math
Because `IsometricWorld` is scaled via a `UIScale` (`WorldScale.Scale`), mouse screen coordinates must be adjusted for both the Topbar Inset (`GuiService:GetGuiInset()`) and canvas zoom:
```luau
local rawMouse = UserInputService:GetMouseLocation()
local inset = GuiService:GetGuiInset()
local screenPos = rawMouse - inset -- Aligns with ScreenGui (IgnoreGuiInset = true)

-- Relativize to canvas center and divide by UIScale
local relX = (screenPos.X - WorldCanvas.AbsolutePosition.X) / WorldScale.Scale
local relY = (screenPos.Y - WorldCanvas.AbsolutePosition.Y) / WorldScale.Scale
local gx, gy = IsometricMath.screenToGrid(relX, relY)
```

### 3.5 Global Isometric Depth Sorting (`ZIndex`)
In 2D isometric rendering, depth is proportional to the Manhattan distance from the back corner $(0, 0)$. Objects further down-right and down-left must render on top of objects behind them.

**Formula:**
$$\text{ZIndex} = \text{clamp}\left(\lfloor(gx + gy) \times 10\rfloor + \text{layerOffset}, 1, 100000\right)$$

**Layer Offsets:**
| Layer Offset | Contents | Description |
|:---:|:---|:---|
| **`1`** | Floor Tiles & Pavement | Base diamond floor geometry |
| **`2`** | Wall Panels | Outer club boundary walls |
| **`3`** | Dancefloor Pads & Neon Strips | Walkable floor-level electronics |
| **`4`** | Neon Wall Decor | Wall-mounted artwork and signage |
| **`5`** | Furniture, Bouncers, Guests | Solid items and walking characters |
| **`9`** | Overhead Popups & Status Tags | `+$Cash` floating text, guest status labels |
| **`80000`** | Hover Cursor & Ghost Preview | Active build grid placement indicator |
| **`90000+`** | Fixed HUD & Modals | Facebook-style bottom dock, top banner, creator |

---

## 4. Shared Types & Data Contracts (`src/shared/Types.luau`)

```luau
--!strict

export type ItemCategory = "Floor" | "DancePad" | "Decor" | "Speaker" | "MocktailBar" | "DJBooth" | "VIPBooth" | "BouncerPost"
export type DJSkillId = "RefreshSet" | "DropTheBass" | "MicShoutout"
export type EditMode = "None" | "Build" | "Move" | "Remove"
export type GuestMode = "Queueing" | "Walking" | "Chatting" | "Escorted" | "Entering" | "Dancing" | "GettingMocktail" | "VIPChilling" | "RowdyCrasher" | "Leaving"

export type ItemDef = {
    Id: string,
    Name: string,
    Category: ItemCategory,
    Cost: number,
    Popularity: number,
    Luxury: number,
    FootprintX: number,
    FootprintY: number,
    HeightPx: number,
    FallbackColor: Color3,
    AssetId: string,
    EffectRadius: number?,
    StorageCapacity: number?,
}

export type PlacedItem = {
    Uid: string,
    ItemId: string,
    GX: number,
    GY: number,
}

export type CelebrityVisit = {
    Id: string,
    Name: string,
    Genre: string,
    EndsAt: number,
    Progress: number,
    Goal: number,
    Reward: number,
    Rewarded: boolean,
}

export type Appearance = {
    Skin: number,        -- 1..6: Pale Porcelain to Deep Espresso
    Face: number,        -- 1..6: Oval, Round, Diamond, Wide, Heart, Slim
    Hair: number,        -- 1..6: Messy Pixie, Ponytail, Sleek Bob, Side Part, Layered Wings, Newsboy Cap
    HairColor: number,   -- 1..6: Espresso Black, Chocolate Brown, Honey Blonde, Auburn/Red, Chestnut, Midnight
    Eyes: number,        -- 1..6: Deep Brown, Emerald Green, Sapphire Blue, Warm Amber, Violet, Slate
    Top: number,         -- 1..6: Black Tank, Purple Shirt, Vest & Tie, Blue Casual, Bomber Jacket, Field Jacket
    Bottom: number,      -- 1..5: Khaki Slacks, Denim Jeans, Indigo Slim, Green Skirt, Charcoal Jeans
    Shoes: number,       -- 1..4: High-Top Canvas, Low-Top Sneakers, Glossy Oxfords, Leather Boots
}

export type ClubState = {
    Appearance: Appearance?,
    Celebrity: CelebrityVisit?,
    NextCelebrityAt: number,
    GridWidth: number,
    GridHeight: number,
    Cash: number,
    MocktailStock: number,
    MaxMocktailStock: number,
    Popularity: number,
    Luxury: number,
    ActiveGenre: string,
    DJSetEndsAt: number,
    SkillCooldowns: { [DJSkillId]: number },
    PlacedItems: { [string]: PlacedItem },
}

export type SpriteClip = {
    FirstFrame: number,
    FrameCount: number,
    FPS: number,
    Looped: boolean,
}

export type SpriteSheet = {
    AssetId: string,
    Clips: { [string]: SpriteClip },
}

export type SpriteAnimator = {
    Root: Frame,
    Play: (name: string) -> (),
    Update: (dt: number, zIndex: number, facing: ("Left" | "Right")?) -> (),
    SetFacing: ((facing: "Left" | "Right") -> ())?,
    Destroy: () -> (),
}
```

---

## 5. Game Balance, Catalog & Rules (`GameConfig.luau`)

### 5.1 Economy & Crowd Tuning
```luau
GameConfig.STARTING_GRID_W = 10
GameConfig.STARTING_GRID_H = 10
GameConfig.STARTING_CASH = 2500

GameConfig.RESTOCK_COST_PER_UNIT = 2    -- $2 per mocktail stock unit
GameConfig.MOCKTAIL_SALE_PRICE = 8      -- $8 earned per drink sold
GameConfig.BASE_COVER_CHARGE = 10       -- $10 base entry fee + (Luxury * 0.25)
GameConfig.TIP_AMOUNT = 50              -- $50 transferred when tipping a friend's DJ booth
GameConfig.TIP_COOLDOWN = 60            -- 60s cooldown between tips to the same friend

GameConfig.CROWD = {
    MaxGuests = 36,
    MaxQueue = 6,
    ArrivalInterval = 1.2,
    AdmissionInterval = 1.8,
    DecisionInterval = 0.25,
    VisitSeconds = 110,
    RowdyEvery = 9,                     -- 1 out of every 9 admitted guests is a Rowdy Crasher
    RowdyRadius = 2.5,                  -- AoE radius where Rowdy Crashers reduce happiness
    HappinessLossPerSecond = 9,
    HappinessRecoveryPerSecond = 2,
    GuardSpeed = 3.8,
}
```

### 5.2 Furniture Catalog (`GameConfig.ITEMS`)
| Item ID | Name | Category | Cost | Pop | Lux | Footprint | Height | Effect / Storage |
|:---|:---|:---|:---:|:---:|:---:|:---:|:---:|:---|
| `NeonDancePad` | Neon Pulse Tile | `DancePad` | $100 | 15 | 5 | 1×1 | 64px | Walkable dance surface |
| `BassTower` | Subwoofer Stack | `Speaker` | $350 | 45 | 15 | 1×1 | 120px | Solid sound obstacle |
| `FizzMocktailBar` | Neon Fizz Mocktail Bar | `MocktailBar` | $500 | 25 | 40 | 1×1 | 105px | +250 Mocktail Storage |
| `StarterDJBooth` | Laser Turntable Deck | `DJBooth` | $600 | 60 | 35 | 1×1 | 115px | Enables DJ skills & tips |
| `VelvetVIPBooth` | High-Roller VIP Lounge | `VIPBooth` | $900 | 20 | 95 | 1×1 | 100px | Required for Celebrities |
| `BouncerStation` | Security Bouncer Post | `BouncerPost` | $450 | 10 | 30 | 1×1 | 115px | Radius: 3.5 tiles AoE escort |

### 5.3 DJ Skills (`GameConfig.DJ_SKILLS`)
- **`RefreshSet`**: Cooldown 10s | Cost $50 | Sets `DJSetEndsAt = now + 180s`.
- **`DropTheBass`**: Cooldown 45s | Tips $25 per active dancer + immediate drink sales.
- **`MicShoutout`**: Cooldown 30s | Flat VIP tip $120 + `math.floor(Luxury * 1.5)`.

### 5.4 Club Expansion Tiers (`GameConfig.EXPANSIONS`)
| Current Size | Target Size | Expansion Cost |
|:---:|:---:|:---:|
| 10×10 | 12×12 | $3,000 |
| 12×12 | 14×14 | $6,000 |
| 14×14 | 16×16 | $10,000 |
| 16×16 | 18×18 | $16,000 |
| 18×18 | 20×20 | $24,000 |

### 5.5 Parody Celebrities (`GameConfig.CELEBRITIES`)
- **Builderbeat VIP**: Preferred Genre: `Electro` | Goal: 30s | Payout: $750
- **DJ Blox**: Preferred Genre: `HipHop` | Goal: 30s | Payout: $900
- **Pixel Popstar**: Preferred Genre: `SynthPop` | Goal: 30s | Payout: $850
*Requirement:* Must have a `VelvetVIPBooth`, active matching music genre, mocktails in stock, and active DJ timer.

---

## 6. 2D Character Customization & Animation Engine

### 6.1 Dual Rendering Architecture
`src/client/SpriteAnimator.luau` supports two distinct visual pathways:
1. **Sprite Sheet Mode:** Active when `sheet.AssetId ~= ""` and no appearance table is provided. Renders an `ImageLabel` mapping 256×256px cells on a 1024×1024 atlas.
2. **Procedural Vector Engine:** Active when `sheet.AssetId == ""` or when an `Appearance` table is provided (e.g., in Character Creator or for the player's avatar). Uses vector shapes with `UICorner` and `UIGradient` to construct a 2010 Flash cartoon character.

### 6.2 Proportions & Visual Hierarchy
- **Dimensions:** Root `56×76px`, AnchorPoint `(0.5, 1)`.
- **Head:** ~38–40px wide, ~34–37px tall (occupies >50% of total height, capturing chibi aesthetics).
- **DOM Hierarchy (Sibling Order for Sorting):**
  1. `GroundShadow` (translucent ellipse under feet)
  2. `BodyContainer` (vertical bob container for breathing/strides)
     - `BackHair` / `Ponytail` (rendered behind the body)
     - `LeftLeg` & `RightLeg` (or bare legs under pencil skirt)
     - `LeftShoe` & `RightShoe` (toe caps, rubber foxing, laces)
     - `TorsoOutline` & `TorsoMain`
     - `Belt` & metallic `BeltBuckle`
     - Top garment layers (tank scoop, shirt collar, vest, necktie, bomber zipper)
     - `LeftArm`, `RightArm`, `LeftHand`, `RightHand`
     - `Neck`
     - `HeadOutline` & `FaceBase` (jaw shape based on `Face`)
     - `EarL`, `EarR`, `Tragus`
     - `BlushL`, `BlushR` (soft rosy cheek highlights)
     - `Nose` mark & `Smile` with lip glint
     - `BrowL`, `BrowR`
     - `EyeWhiteL`, `EyeWhiteR`, `IrisL`, `IrisR`, `PupilL`, `PupilR`
     - `GlintMajorL`, `GlintMinorL`, `GlintMajorR`, `GlintMinorR` (dual specular shine)
     - `HairCrown`, front bangs, headband, or newsboy cap visor
     - `VIPBadge` (golden star with stroke)

### 6.3 Directional Facing (Horizontal Reflection)
To face left or right without non-uniform `UIScale` bugs or rebuilding instances, `SpriteAnimator` mirrors part horizontal positions across the central vertical axis ($x = 28$):
$$\text{flippedX} = 56 - \text{BaseX} - \text{Width}$$
$$\text{flippedRot} = -\text{BaseRot}$$

```luau
local function setFacing(facing: "Left" | "Right")
    if currentFacing == facing then return end
    currentFacing = facing
    local isLeft = facing == "Left"
    for _, p in registeredVectorParts do
        local targetX = if isLeft then (56 - p.BaseX - p.Width) else p.BaseX
        p.Frame.Position = UDim2.fromOffset(targetX, p.BaseY)
        if p.BaseRot ~= 0 then
            p.Frame.Rotation = if isLeft then -p.BaseRot else p.BaseRot
        end
    end
end
```

### 6.4 Animation Parameter Equations
- **`Idle`:**
  - Torso vertical bob: $y = \sin(t \times 3) \times 1.5$ px
  - Arm sway: $\text{rot} = \pm\sin(t \times 3) \times 4^\circ$
  - Ponytail bounce: $\text{rot} = \text{base} + \sin(t \times 3) \times 3^\circ$
  - Blink cycle: eye squashes to $2$px height for $0.12$s every $3.5$s.
- **`Walk`:**
  - Opposing leg strides: $\text{rot} = \pm\sin(\text{phase}) \times 24^\circ$
  - Opposing arm swings: $\text{rot} = \mp\sin(\text{phase}) \times 24^\circ$
  - Stride bounce: $y = -|\sin(\text{phase})| \times 2.5$ px
- **`Dance`:**
  - Arm gestures: $\text{rot}_L = 45^\circ + \sin(\text{phase}) \times 35^\circ$, $\text{rot}_R = -45^\circ - \cos(\text{phase}) \times 35^\circ$
  - Leg rhythm: $\text{rot} = \pm\sin(\text{phase}) \times 8^\circ$
  - Dance bounce: $y = -|\sin(\text{phase})| \times 5$ px
  - Ponytail physics: $\text{rot} = \text{base} + \sin(\text{phase}) \times 15^\circ$

---

## 7. Crowd AI, Navigation & Bouncer AoE

### 7.1 State Machine (`src/client/GuestController.luau`)
```
[Outside Entrance (1, 1)]
         │
    "Queueing" ────► (Admission Interval)
         │
    "Entering"
         │
    "Walking" ◄────────────────────────┐
         │                             │
    ┌────┴─────────────────────────────┴────┐
    ▼                                       ▼
"Dancing"                            "GettingMocktail"
(on NeonDancePad)                    (at FizzMocktailBar)
    │                                       │
    └─────────────────┬─────────────────────┘
                      ▼
               "VIPChilling"
             (at VelvetVIPBooth)
                      │
           (Visit Timer / Rowdy)
                      │
                      ▼
                  "Leaving" ──► Destroy & Despawn
```

### 7.2 BFS Grid Pathfinding (`src/client/GuestNavigation.luau`)
- Uses a pure 2D breadth-first search on tile coordinates `(1..GridWidth, 1..GridHeight)`.
- **Walkable:** Any tile not occupied by solid furniture (`FootprintX × FootprintY`).
- `DancePad` and `Floor` items are explicitly excluded from blocking, allowing full crowd circulation.
- Path waypoints are recentered before turns to avoid diagonal corner-cutting on replans.

### 7.3 Bouncer AoE & Escort Mechanic
- Bouncer posts (`BouncerStation`) cast an AoE radius of $3.5$ grid units.
- Rowdy Crashers entering the radius trigger the security guard.
- The bouncer walks to the troublemaker, tags them with `"ESCORTED OUT"`, changes their state to `"Leaving"`, and escorts them to the entrance threshold `(1, 1)` before returning to the station.

---

## 8. Client UI Architecture (`src/client/`)

### 8.1 Toolbar & Dock Structure
1. **`TopHud` (Glossy 2010 Blue Banner):** Displays Cash, Popularity, Luxury, Mocktail Stock/Max, and active DJ Timer countdown.
2. **`SubBanner`:** Mode indicator (e.g., `BUILD MODE: Click an empty tile to place [Item] • Right-Click / ESC to cancel`).
3. **`BottomDock`:** Contains primary action buttons with procedural icons (`src/client/HudIcons.luau`):
   - `RefreshSet` ($50)
   - `DROP BASS!`
   - `Shoutout`
   - `Restock Bar`
   - `Build Shop` (toggles `BuildShelf`)
   - `Move Item`
   - `Sell Item` (70% refund)
   - Zoom In (`+`), Zoom Out (`-`), Zoom Reset (`50%`–`180%`)
   - `MY LOOK` (opens Character Creator modal)
4. **`SocialPanel` (`src/client/SocialPanel.luau`):**
   - Bottom Friends Bar with online status badges and profile avatars.
   - Celebrity Mission progress bar and timer.
   - Visiting mode controls (`VISITING FRIEND'S CLUB`, `TIP DJ BOOTH ($50)`, `RETURN HOME`).

### 8.2 Building & Edit Modes
- **Build Mode:** Hovering mouse highlights valid tiles in cyan (`HoverTile`). Left-clicking validates bounds and fires `PerformClubAction` with `"PlaceItem"`.
- **Move Mode:** Clicking placed furniture fades the item and initiates placement mode for new coordinates (`"MoveItem"`).
- **Sell Mode:** Clicking furniture refunds 70% of the initial purchase cost (`"RemoveItem"`).

---

## 9. Server Architecture & Persistence (`src/server/`)

### 9.1 Remote Protocol Specification
All remotes live under `ReplicatedStorage.ClubRemotes`:

| Remote Name | Type | Direction | Purpose |
|:---|:---:|:---:|:---|
| `GetClubState` | `RemoteFunction` | Client -> Server | Retrieves current player's loaded `ClubState` |
| `PerformClubAction` | `RemoteFunction` | Client -> Server | Executes building, skills, restocking, customization |
| `ClubSocial` | `RemoteFunction` | Client -> Server | Handles Friends list, Visiting, Home, and Tipping |
| `ClubStateUpdated` | `RemoteEvent` | Server -> Client | Pushes authoritative state updates to the player |

### 9.2 `PerformClubAction` Payloads
```luau
-- 1. Character Customization
ActionFn:InvokeServer("SetAppearance", { Appearance = appearanceTable })

-- 2. Genre Switching
ActionFn:InvokeServer("SetGenre", { Genre = "Electro" | "HipHop" | "SynthPop" })

-- 3. Club Expansion
ActionFn:InvokeServer("ExpandClub", {})

-- 4. Item Placement
ActionFn:InvokeServer("PlaceItem", { ItemId = "NeonDancePad", GX = 5, GY = 5 })

-- 5. Restock Bar
ActionFn:InvokeServer("RestockMocktails", {})

-- 6. Trigger DJ Skill
ActionFn:InvokeServer("TriggerDJSkill", { Skill = "RefreshSet" | "DropTheBass" | "MicShoutout" })

-- 7. Remove / Sell Item
ActionFn:InvokeServer("RemoveItem", { Uid = uidString })

-- 8. Move Item
ActionFn:InvokeServer("MoveItem", { Uid = uidString, NewGX = 6, NewGY = 6 })
```

### 9.3 Production DataStore Session Leasing (`DataManager.luau`)
To prevent data corruption from concurrent servers (e.g., rapid rejoining), `DataManager` uses a strict token-lease algorithm on `DataStoreService`:
1. **Acquiring Session:** On `join`, server generates a GUID `token` and runs `UpdateAsync`:
   - Checks if existing `record.Lock` is held by another server. If `Lock.Expires > os.time()`, load fails and player is instructed to rejoin shortly.
   - Sets `record.Lock = { Token = token, Expires = os.time() + 180 }`.
2. **Autosave & Flushing:** Every 45 seconds (`AutosaveSeconds`), the server updates the profile via `UpdateAsync`, extending the lock lease by 180 seconds.
3. **Ambiguous Network Recovery:** Each save generates an `operationId` (`SaveId`). If a retried `UpdateAsync` succeeds on the second attempt, it checks `record.SaveId == operationId` to prevent duplicate credit additions.
4. **Offline Cross-Server Tipping:** When player A tips player B's club:
   - If player B is offline or on another server, `DataManager.Tip` adds credits to player B's `PendingCredits` field in their DataStore record using an atomic `UpdateAsync`.
   - When player B's server saves or flushes, `PendingCredits` is safely folded into `State.Cash`.
5. **Session Release:** On `PlayerRemoving` or `game:BindToClose`, the lock is cleared (`record.Lock = nil`), allowing immediate re-entry on new servers.

---

## 10. Verification, Tests & Tooling

### 10.1 Running the Headless Luau Test Suite
The project includes automated regression tests using a wasm-compiled Luau runner:
```powershell
# Execute from project root:
node tests/run-art.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-crowd.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-server.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-character.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-pan.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
```

### 10.2 Building the Roblox Place File with Rojo
```powershell
rojo build -o nightclub_roblox.rbxlx
```

### 10.3 Git Repository & Branches
- Remote: `https://github.com/faithingod1/nightclub_rbx.git`
- Main Branch: `master`
- Place file `nightclub_roblox.rbxlx` is excluded from git tracking via `.gitignore`.

---

## 11. Strict Coding Standards & Checklist for AI Agents

Whenever making additions or edits to this codebase, you **must strictly adhere** to these rules:

1. **`--!strict` at the Top:** Every `.luau` file must begin with `--!strict`.
2. **Central Types:** Share types via `ReplicatedStorage.Shared.Types`. Never invent ad-hoc inline tables for core data models.
3. **Task Library Only:** Always use `task.wait()`, `task.spawn()`, `task.delay()`, and `os.clock()`. **NEVER** use deprecated `wait()`, `spawn()`, `delay()`, or standard desktop Lua libraries (`io`, `os.execute`).
4. **No 2nd Parent Argument in `Instance.new()`:** Always construct the object, configure properties, and set `.Parent` last:
   ```luau
   -- CORRECT:
   local frame = Instance.new("Frame")
   frame.Size = UDim2.fromOffset(100, 100)
   frame.Parent = parent

   -- INCORRECT (DEPRECATED):
   local frame = Instance.new("Frame", parent)
   ```
5. **Programmatic UI Only:** Build all UI components purely in Luau modules. Never rely on manually assembled Studio `.rbxm` binary instances.
6. **No 3D Objects:** Never add `Part`, `MeshPart`, or `Humanoid`. Keep `Players.CharacterAutoLoads = false`.
7. **Safe Audio & Assets:** Never hardcode unverified Roblox asset IDs. Use procedural vector geometry for UI icons and characters whenever `AssetId == ""`.
8. **Atlas Limits:** Character sprite sheet atlases must never exceed `1024×1024` with `256×256` frames.
9. **Depth Sorting:** Adhere to `ZIndex = (gx + gy) * 10 + layerOffset` for every placed object.
