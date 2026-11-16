import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const { LuauState } = await import(pathToFileURL(path.resolve(process.argv[2])).href);
const runtime = await LuauState.createAsync({print: console.log});
const source = fs.readFileSync('src/client/ClubClient.client.luau', 'utf8');
let bundle = fs.readFileSync('tests/crowd-mocks.luau','utf8');
for (const file of ['src/shared/Types.luau','src/shared/GameConfig.luau','src/shared/IsometricMath.luau','src/client/ClubArt.luau','src/client/HudIcons.luau']) {
 bundle += `\nmodules["${path.basename(file,'.luau')}"] = (function()\n${fs.readFileSync(file,'utf8')}\nend)()\n`;
}
bundle += fs.readFileSync('tests/art-mocks.luau','utf8');
const start = source.indexOf('local PulsePads:');
const end = source.indexOf('-- Ground tile input',start);
if (start < 0 || end < 0) throw new Error('Cannot locate production world renderer');
bundle += '\n' + source.slice(start,end);
const renderStart = source.indexOf('local renderConnection = RunService.RenderStepped:Connect(function(dt: number)');
const lightStart = source.indexOf('\n',renderStart);
const lightEnd = source.indexOf('\thudElapsed += dt',lightStart);
if (lightEnd < lightStart) throw new Error('Cannot locate production frame effects');
bundle += '\nlocal lightElapsed = 0\nlocal function effects(dt: number)\n' + source.slice(lightStart,lightEnd) + '\nend\n';
bundle += fs.readFileSync('tests/art.spec.luau','utf8');
try { await runtime.loadstring(bundle,'phase6.spec',true)(); } finally { runtime.destroy(); }
