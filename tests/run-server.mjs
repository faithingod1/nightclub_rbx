import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { LuauState } = await import(pathToFileURL(path.resolve(process.argv[2])).href);
const runtime = await LuauState.createAsync({ print: console.log });
const all = fs.readdirSync('src', { recursive: true }).filter(f => f.endsWith('.luau'));
for (const file of all) runtime.loadstring(fs.readFileSync(path.join('src', file), 'utf8'), file, true);
console.log(`Compiled ${all.length} production Luau files`);
let bundle = fs.readFileSync('tests/crowd-mocks.luau', 'utf8') + '\n' + fs.readFileSync('tests/server-mocks.luau', 'utf8');
for (const file of ['src/shared/Types.luau', 'src/shared/GameConfig.luau', 'src/shared/Appearance.luau', 'src/server/ClubRules.luau', 'src/server/DataManager.luau']) {
  bundle += `\nmodules["${path.basename(file, '.luau')}"] = (function()\n${fs.readFileSync(file, 'utf8')}\nend)()\n`;
}
bundle += fs.readFileSync('tests/server.spec.luau', 'utf8');
bundle += '\n' + fs.readFileSync('tests/remote-mocks.luau', 'utf8');
bundle += '\n(function()\n' + fs.readFileSync('src/server/ClubServer.server.luau', 'utf8') + '\nend)()\n';
bundle += fs.readFileSync('tests/remote.spec.luau', 'utf8');
try { await runtime.loadstring(bundle, 'server.spec', true)(); } finally { runtime.destroy(); }
