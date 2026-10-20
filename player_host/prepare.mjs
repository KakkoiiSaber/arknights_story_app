import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const upstream = new URL('third_party/prts-widgets/', root);
// Cache build inputs outside the submodule. Never run upstream publish scripts.
const publicDir = new URL('./public/', import.meta.url);
for (const [path, upstreamURL] of [
  ['assets/avg/character.json', 'https://torappu.prts.wiki/assets/avg/character.json'],
  ['assets/avg/background.json', 'https://torappu.prts.wiki/assets/avg/background.json'],
  ['story/story_variables.json', 'https://torappu.prts.wiki/gamedata/latest/story/story_variables.json'],
]) {
  const destination = new URL(`metadata/${path}`, publicDir);
  if (!process.argv.includes('--refresh-metadata')) {
    try { JSON.parse(await readFile(destination, 'utf8')); continue; } catch {}
  }
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(upstreamURL, {
        headers: { Referer: 'https://prts.wiki/' }, signal: AbortSignal.timeout(30000),
      });
      if (!response.ok) throw new Error(`Metadata ${path}: HTTP ${response.status}`);
      const data = await response.json();
      if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error(`Invalid metadata: ${path}`);
      await mkdir(new URL('./', destination), {recursive: true});
      await writeFile(destination, JSON.stringify(data));
      lastError = null;
      break;
    } catch (error) { lastError = error; }
  }
  if (lastError) throw lastError;
}
await mkdir(new URL('fonts/', publicDir), { recursive: true });
const source = await readFile(new URL('src/widgets/StoryPlayer/engine/font.ts', upstream), 'utf8');
const filenames = [...source.matchAll(/file: "([^"]+\.woff2)"/g)].map(match => match[1]);
if (!filenames.length) throw new Error('No upstream fonts found; review the build adapter.');
for (const file of filenames) {
  const destination = new URL(`fonts/${file}`, publicDir);
  try { if ((await readFile(destination)).length > 1000) continue; } catch {}
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(`https://static.prts.wiki/${file}`, {
        headers: { Referer: 'https://prts.wiki/' }, signal: AbortSignal.timeout(45000),
      });
      if (!response.ok) throw new Error(`Font ${file}: HTTP ${response.status}`);
      const bytes = new Uint8Array(await response.arrayBuffer());
      if (String.fromCharCode(...bytes.slice(0, 4)) !== 'wOF2') throw new Error(`Invalid WOFF2: ${file}`);
      await writeFile(destination, bytes);
      lastError = null;
      break;
    } catch (error) { lastError = error; }
  }
  if (lastError) throw lastError;
}
await copyFile(new URL('LICENSE', upstream), new URL('UPSTREAM-LICENSE.txt', publicDir));
const revision = execFileSync('git', ['rev-parse', 'HEAD'], {
  cwd: fileURLToPath(upstream), encoding: 'utf8',
}).trim();
await writeFile(new URL('upstream.json', publicDir), JSON.stringify({
  repository: 'https://github.com/MooncellWiki/prts-widgets', revision,
  fonts: filenames, hostProtocol: 1,
}, null, 2));
console.log(`PRTS ${revision.slice(0, 7)}: ${filenames.length} fonts ready`);
