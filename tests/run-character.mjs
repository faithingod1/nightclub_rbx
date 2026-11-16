import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { LuauState } = await import(pathToFileURL(path.resolve(process.argv[2])).href);
const runtime = await LuauState.createAsync({print: console.log});
let bundle = ['crowd-mocks.luau', 'music-mocks.luau', 'ui-mocks.luau']
  .map(file => fs.readFileSync(`tests/${file}`, 'utf8')).join('\n');
for (const file of ['src/shared/Types.luau', 'src/shared/GameConfig.luau', 'src/shared/Appearance.luau',
  'src/client/SpriteAnimator.luau', 'src/client/CharacterCreator.luau']) {
  bundle += `\nmodules["${path.basename(file, '.luau')}"] = (function()\n${fs.readFileSync(file, 'utf8')}\nend)()\n`;
}
bundle += fs.readFileSync('tests/character.spec.luau', 'utf8');
try { await runtime.loadstring(bundle, 'character.spec', true)(); } finally { runtime.destroy(); }
