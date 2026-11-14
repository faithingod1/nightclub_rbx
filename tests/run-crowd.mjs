import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// Usage: node tests/run-crowd.mjs <path to installed luau-web/src/index.js>
const { LuauState } = await import(pathToFileURL(path.resolve(process.argv[2])).href);
const runtime = await LuauState.createAsync({ print: console.log });
const files = ['src/shared/Types.luau', 'src/shared/GameConfig.luau', 'src/shared/IsometricMath.luau',
  'src/client/SpriteAnimator.luau', 'src/client/GuestNavigation.luau', 'src/client/GuestController.luau',
  'src/client/ClubClient.client.luau', 'src/client/GlossyUI.luau', 'src/server/ClubServer.server.luau'];
for (const file of files) runtime.loadstring(fs.readFileSync(file, 'utf8'), file, true);
console.log(`Compiled ${files.length} Luau files`);
let bundle = fs.readFileSync('tests/crowd-mocks.luau', 'utf8');
for (const file of files.slice(0, 6)) {
  const name = path.basename(file, '.luau');
  bundle += `\nmodules["${name}"] = (function()\n${fs.readFileSync(file, 'utf8')}\nend)()\n`;
}
bundle += fs.readFileSync('tests/crowd.spec.luau', 'utf8');
bundle += '\n' + fs.readFileSync('tests/music-mocks.luau', 'utf8');
bundle += '\nmodules.MusicController = (function()\n' + fs.readFileSync('src/client/MusicController.luau', 'utf8') + '\nend)()\n';
bundle += fs.readFileSync('tests/music.spec.luau', 'utf8');
bundle += '\n' + fs.readFileSync('tests/ui-mocks.luau', 'utf8');
bundle += '\nmodules.SocialPanel = (function()\n' + fs.readFileSync('src/client/SocialPanel.luau', 'utf8') + '\nend)()\n';
bundle += fs.readFileSync('tests/ui.spec.luau', 'utf8');
try {
  await runtime.loadstring(bundle, 'crowd.spec', true)();
} finally {
  runtime.destroy();
}
