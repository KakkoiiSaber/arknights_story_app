import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';
import MagicString from 'magic-string';

// Delivery adaptation only. Keep all upstream AVG behavior unchanged.
const remoteFontURL = '`https://static.prts.wiki/${file}`';
const resourceModule = fileURLToPath(new URL('./resources.mjs', import.meta.url)).replaceAll('\\', '/');
export default defineConfig({
  root: fileURLToPath(new URL('./', import.meta.url)),
  base: './',
  // Compile imported engine TS with the host settings, not the Wiki's Vue app config.
  esbuild: { tsconfigRaw: JSON.stringify({ compilerOptions: { useDefineForClassFields: true } }) },
  plugins: [{
    name: 'prts-local-font-delivery',
    enforce: 'pre',
    transform(source, id) {
      const path = id.replaceAll('\\', '/');
      if (path.endsWith('/StoryPlayer/engine/asset.ts')) {
        const output = new MagicString(source);
        output.prepend(`import { routeAssetURL } from ${JSON.stringify(resourceModule)};\n`);
        for (const name of ['resolveAssetUrl', 'resolveStoryAssetByKey',
          'resolveStoryCharacterAssetByKey', 'resolveStoryVideoByKey', 'resolveStoryAudioByKey']) {
          const signature = `export function ${name}(`;
          const start = source.indexOf(signature);
          if (start < 0 || source.indexOf(signature, start + 1) >= 0) {
            throw new Error(`Upstream asset contract changed: ${name}`);
          }
          const internal = `_arkUpstream_${name}`;
          output.overwrite(start, start + signature.length, `function ${internal}(`);
          output.append(`\nexport function ${name}(...args: Parameters<typeof ${internal}>) { return routeAssetURL(${internal}(...args)); }\n`);
        }
        return {code: output.toString(), map: output.generateMap({hires: true, source: id, includeContent: true})};
      }
      if (path.endsWith('/StoryPlayer/context.ts')) {
        const output = new MagicString(source);
        for (const [remote, local] of [
          ['"https://torappu.prts.wiki/assets"', '"./metadata/assets"'],
          ['"https://torappu.prts.wiki/gamedata/latest/story"', '"./metadata/story"'],
        ]) {
          const start = source.indexOf(remote);
          if (start < 0) throw new Error('Upstream context URL contract changed');
          output.overwrite(start, start + remote.length, `new URL(${local}, document.baseURI).href`);
        }
        return {code: output.toString(), map: output.generateMap({hires: true, source: id, includeContent: true})};
      }
      if (!path.endsWith('/StoryPlayer/engine/font.ts')) return;
      if (!source.includes(remoteFontURL)) {
        throw new Error('Upstream font URL contract changed; review the host adapter.');
      }
      const output = new MagicString(source);
      const start = source.indexOf(remoteFontURL);
      output.overwrite(start, start + remoteFontURL.length,
        'new URL(`./fonts/${file}`, document.baseURI).href');
      return { code: output.toString(), map: output.generateMap({hires: true, source: id, includeContent: true}) };
    },
  }],
  build: {
    outDir: '../web/prts-player',
    emptyOutDir: true,
    sourcemap: true,
    target: 'es2022',
  },
});
