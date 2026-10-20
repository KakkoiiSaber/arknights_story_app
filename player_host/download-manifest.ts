import { loadContextByScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/context';
import { collectContextAssetManifest } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/preload';
import { parseScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/parser';
import { resolveStoryVideoByKey } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/asset';
import { DIALOG_FONT, ANIMTEXT_MAIN_FONT, SAMI_FONTS } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/font';
import * as ui from '../third_party/prts-widgets/src/widgets/StoryPlayer/assets';
import { resolveScriptURL } from './source.mjs';

export async function chapterManifest(id: string, signal: AbortSignal): Promise<string[]> {
  const scriptURL = resolveScriptURL(id).href;
  const response = await fetch(scriptURL, { signal: AbortSignal.any([signal, AbortSignal.timeout(30000)]) });
  if (!response.ok) throw new Error(`剧情 TXT: HTTP ${response.status}`);
  const script = await response.text();
  if (!script.trim()) throw new Error('剧情 TXT 为空');
  const context = await loadContextByScript(script);
  signal.throwIfAborted();
  const manifest = collectContextAssetManifest({ ...context, charMap: {} });
  const urls = new Set([scriptURL, ...manifest.urls]);
  for (const face of manifest.faceAssets) { urls.add(face.baseUrl); urls.add(face.faceUrl); }
  // Keep the exact mapping snapshot used to resolve this chapter.
  for (const path of ['assets/avg/character.json', 'assets/avg/background.json', 'story/story_variables.json']) {
    urls.add(new URL(`./metadata/${path}`, document.baseURI).href);
  }
  for (const font of [DIALOG_FONT, ANIMTEXT_MAIN_FONT, ...SAMI_FONTS]) {
    urls.add(new URL(`./fonts/${font.file}`, document.baseURI).href);
  }
  for (const value of Object.values(ui)) {
    if (typeof value === 'string') urls.add(value);
    else for (const url of Object.values(value)) urls.add(url);
  }
  for (const line of parseScript(context.script)) {
    if (line.kind !== 'command' || line.command !== 'video') continue;
    const direct = String(line.args.url ?? '').trim();
    const url = direct || resolveStoryVideoByKey(String(line.args.res ?? ''));
    if (url && !context.missingVideoUrls?.has(url)) urls.add(url);
  }
  return [...urls].filter(url => !url.startsWith('data:'));
}
