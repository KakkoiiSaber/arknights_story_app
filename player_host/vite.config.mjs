import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';
import MagicString from 'magic-string';
import { adaptReaderPreferences } from './preferences-adapter.mjs';

// Delivery adaptation only. Keep all upstream AVG behavior unchanged.
const remoteFontURL = '`https://static.prts.wiki/${file}`';
export default defineConfig({
  root: fileURLToPath(new URL('./', import.meta.url)),
  base: './',
  // Compile imported engine TS with the host settings, not the Wiki's Vue app config.
  esbuild: { tsconfigRaw: JSON.stringify({ compilerOptions: { useDefineForClassFields: true } }) },
  plugins: [{
    name: 'prts-reader-preferences',
    enforce: 'pre',
    transform(source, id) {
      const code = adaptReaderPreferences(source, id);
      if (code !== undefined) return { code, map: null };
    },
  }, {
    name: 'prts-native-resource-delivery',
    enforce: 'pre',
    transform(source, id) {
      const path = id.replaceAll('\\', '/');
      const helper = '\nconst __arkstoryLocal = (url: string): string => globalThis.__arkstoryAssetURL?.(url) ?? url;\n';
      if (path.endsWith('/StoryPlayer/engine/asset.ts')) {
        let output = source;
        for (const name of ['resolveAssetUrl', 'resolveStoryAssetByKey', 'resolveStoryCharacterAssetByKey', 'resolveStoryVideoByKey', 'resolveStoryAudioByKey']) {
          if (!output.includes(`export function ${name}(`)) throw new Error(`Asset contract changed: ${name}`);
          output = output.replace(`export function ${name}(`, `function __raw_${name}(`);
          output += `\nexport function ${name}(...args: Parameters<typeof __raw_${name}>): ReturnType<typeof __raw_${name}> { const url = __raw_${name}(...args); return url === null ? null : __arkstoryLocal(url); }\n`;
        }
        return { code: helper + output, map: null };
      }
      if (path.endsWith('/rendering/panels/VideoPanel.ts')) {
        if (!source.includes('src: url,')) throw new Error('Video delivery contract changed');
        return { code: helper + source.replace('src: url,', 'src: __arkstoryLocal(url),'), map: null };
      }
    },
  }, {
    name: 'prts-local-font-delivery',
    enforce: 'pre',
    transform(source, id) {
      const path = id.replaceAll('\\', '/');
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
    rollupOptions: { input: {
      player: fileURLToPath(new URL('./index.html', import.meta.url)),
      manifest: fileURLToPath(new URL('./manifest.html', import.meta.url)),
    } },
    outDir: '../web/prts-player',
    emptyOutDir: true,
    sourcemap: true,
    target: 'es2022',
  },
});
