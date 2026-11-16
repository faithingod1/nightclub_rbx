# Phase 6 test results ? 2026-11-17

## Passed

- All six furniture categories construct valid UI geometry with consistent furniture depth.
- Room construction succeeds at 10x10 and 20x20 (447 and 818 room descendants respectively).
- Cash-only updates reuse existing artwork.
- Furniture edits retain the static room and replace furniture/animated-pad references; move selection fades furniture.
- Production frame-effect code changes dance-pad color and synchronizes cursor color/depth.
- Existing crowd/client, pan and server regression suites pass; all 17 production Luau files compile.
- Creator tests cover all option bounds, NaN/infinite values, draft isolation, wraparound, cancel, save, retry and preview cleanup.
- Server tests cover old-save migration, appearance persistence, malformed remote payloads and visitor rejection.
- Rojo builds `nightclub_roblox.rbxlx` in the project and `nightclub-character-performance.rbxlx` in the temporary directory.

## Fixed

The current client collected animated dance-pad frames but never updated them. It also
left cursor-edge colors and ZIndex at their construction values. Both updates are now
connected to RenderStepped, with lighting limited to 10 updates per second.

The later detailed-wall renderer had grown to 5,880/11,771 room descendants.
Gradient-masked triangles reduce that to 447/818 (about 93% fewer). Furniture edits
no longer rebuild the static room. Mouse movement in normal mode no longer runs
build-preview work. Character limb poses update only when their clip frame changes.

## Not verified

Studio opened the isolated build, but repeated active-user-input guards blocked Play.
The user opted to open/play it themselves. No game visual inspection, FPS measurement,
or static type analysis was completed. UI-instance counts are construction measurements,
not FPS results. The right-triangle mask orientation still needs native visual review.

The current ClubClient.client.luau uses the older random-walking guest loop and does not
connect GuestController, MusicController, or SocialPanel. Their standalone tests pass,
but this does not establish that Phases 3?5 work through the current client entry point.
This integration discrepancy was reported without replacing unrelated client changes.

## Repeat

```powershell
node tests/run-art.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-crowd.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-server.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-character.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
node tests/run-pan.mjs "$env:TEMP/nightclub-luau-check/node_modules/luau-web/src/index.js"
rojo build -o nightclub_roblox.rbxlx
```

The art test executes ClubArt and the renderer/frame-effect sections extracted directly
from the production client with lightweight Roblox UI stand-ins.
