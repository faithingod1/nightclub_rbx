# 2D Character Sprite Sheet Atlases (1024x1024)

This directory contains ready-to-upload 1024x1024 32-bit transparent RGBA sprite sheets matching the 2010 *Nightclub City* Flash art direction:

1. `guest-ponytail-1024.png`
   - **Character:** Female club guest featuring high ponytail hairstyle, side bangs, stylish headband, peachy skin, purple blouse, emerald green skirt, and white canvas sneakers.
   - **Resolution:** Exactly 1024x1024 pixels, 4x4 grid with 256x256px cells, 32bpp ARGB transparent background.
   - **Frame Mapping:**
     - Row 1 (Frames 0–3): Idle breathing animation cycle.
     - Row 2 (Frames 4–7): Walking stride cycle.
     - Rows 3–4 (Frames 8–15): Upbeat 8-frame club dance animation cycle.

2. `guest-teal-1024.png`
   - **Character:** Male club guest featuring swept brown hair, warm tan skin, turquoise jacket over tee, charcoal jeans, and white high-top sneakers.
   - **Resolution:** Exactly 1024x1024 pixels, 4x4 grid with 256x256px cells, 32bpp ARGB transparent background.
   - **Frame Mapping:** Same 4x4 layout (Row 1: Idle, Row 2: Walk, Rows 3–4: Dance).

## How to Import into Roblox

1. Open your browser to [Roblox Creator Dashboard](https://create.roblox.com/dashboard/creations) -> **Development Items** -> **Decals** (or open Roblox Studio -> **View** -> **Asset Manager** -> **Images** -> **Bulk Import**).
2. Upload `guest-ponytail-1024.png` or `guest-teal-1024.png`.
3. Once Roblox finishes moderating the upload, copy the numeric Asset ID (e.g., `1234567890`).
4. In `src/shared/GameConfig.luau`, set:
   ```luau
   GameConfig.GUEST_SPRITE = {
       AssetId = "rbxassetid://<YOUR_ASSET_ID>",
       Clips = {
           Idle = { FirstFrame = 0, FrameCount = 4, FPS = 4, Looped = true },
           Walk = { FirstFrame = 4, FrameCount = 4, FPS = 10, Looped = true },
           Dance = { FirstFrame = 8, FrameCount = 8, FPS = 12, Looped = true },
       },
   }
   ```
5. **Procedural Vector Fallback:** Whenever `AssetId == ""` (the default), the game automatically renders and animates the rich procedural cartoon characters with complete real-time customization (Ponytail, Pixie, Bob, Side Part, Wings, Cap, 6 skin tones, 6 eye colors, 6 hair colors, 6 tops, 5 bottoms, 4 shoes), directional facing while walking, and zero external asset dependencies.
