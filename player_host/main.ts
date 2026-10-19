import { sound } from '@pixi/sound';
import { loadContextByScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/context';
import { createStoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/createStoryPlayer';
import { preloadContextAssets } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/preload';
import { parseScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/parser';
import { resolveScriptURL } from './source.mjs';
import { loadingWindow } from './loading-window.mjs';
import type { StoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/types';

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const stage = element<HTMLDivElement>('stage');
const overlay = element<HTMLDivElement>('overlay');
const heading = element<HTMLHeadingElement>('heading');
const status = element<HTMLParagraphElement>('status');
const progress = element<HTMLProgressElement>('progress');
const retry = element<HTMLButtonElement>('retry');
const restart = element<HTMLButtonElement>('restart');
const query = new URLSearchParams(location.search);
stage.dataset.resources = 'prts';
const returnButton = element<HTMLButtonElement>('return');
returnButton.hidden = window.parent === window;
returnButton.onclick = () => window.parent.postMessage('arkstory:exit', location.origin);
element('title').textContent = query.get('title') || '黑暗时代·上 · 序章·上';
let player: StoryPlayer | null = null;
let ready = false;
let generation = 0;
let disposed = false;
const audioContext = sound.context.audioContext;
function syncAudioState() { stage.dataset.audioState = audioContext.state; }
function unlockAudio() {
  // Browsers may require a gesture for sound. Visual playback must not wait
  // for resume(), whose promise can remain pending until that gesture occurs.
  if (audioContext.state === 'suspended') void audioContext.resume().catch(() => {});
  syncAudioState();
}
audioContext.addEventListener('statechange', syncAudioState);
document.addEventListener('pointerdown', unlockAudio, true);
document.addEventListener('click', unlockAudio, true);
document.addEventListener('keydown', unlockAudio, true);

function fail(error: unknown) {
  console.error('[PRTS host]', error);
  ready = false;
  overlay.hidden = false;
  heading.textContent = '剧情加载失败';
  status.textContent = error instanceof Error ? error.message : String(error);
  progress.hidden = true;
  retry.hidden = false;
  retry.textContent = '重试';
  retry.onclick = () => { void load(); };
}

async function load() {
  const started = performance.now();
  const current = ++generation;
  ready = false;
  player?.destroy();
  player = null;
  overlay.hidden = false;
  heading.textContent = '加载中…';
  status.textContent = '正在准备剧情…';
  progress.hidden = false;
  progress.value = 0;
  retry.hidden = true;
  restart.disabled = true;
  try {
    const scriptURL = resolveScriptURL(query.get('script'));
    let response: Response;
    try { response = await fetch(scriptURL, { signal: AbortSignal.timeout(30000) }); }
    catch (error) {
      if (error instanceof DOMException && (error.name === 'TimeoutError' || error.name === 'AbortError')) {
        throw new Error('剧情加载超时，请稍后重试。');
      }
      throw new Error('暂时无法连接剧情资源，请检查网络后重试。');
    }
    if (!response.ok) throw new Error(`剧情 TXT: HTTP ${response.status}`);
    const script = await response.text();
    if (!script.trim()) throw new Error('剧情 TXT 为空');
    const context = await Promise.race([
      loadContextByScript(script),
      new Promise<never>((_, reject) => setTimeout(() => reject(
        new Error('PRTS 资源映射加载超时，请重试。')), 45000)),
    ]);
    if (current !== generation || disposed) return;
    const lines = parseScript(context.script);
    const windowContext = (line: number) => {
      const script = loadingWindow(context.script, lines, line);
      // Legacy charMap contains chapter-wide references; collect this window
      // using the same linkMap/resolvers as the upstream renderer instead.
      return { ...context, charMap: {}, script, scriptText: script.join('\n') };
    };
    stage.dataset.loading = 'windowed';
    stage.dataset.openingLines = String(windowContext(1).script.length);
    const timeout = setTimeout(() => {
      if (current === generation && !ready) {
        generation++;
        fail(new Error('资源加载超时，请检查网络后重试。'));
      }
    }, 90000);
    try {
      await preloadContextAssets(windowContext(1), value => {
        if (current !== generation || disposed) return;
        progress.value = value;
        status.textContent = `正在加载开场资源 ${Math.round(value * 100)}%`;
      });
    } finally { clearTimeout(timeout); }
    if (current !== generation || disposed) return;
    player = createStoryPlayer(context);
    await player.mount(stage);
    if (current !== generation || disposed) { player?.destroy(); player = null; return; }
    ready = true;
    const loadMs = Math.round(performance.now() - started);
    stage.dataset.loadMs = String(loadMs);
    progress.value = 1;
    restart.disabled = false;
    let pendingLine: number | null = null;
    let warming = false;
    const warmAhead = async () => {
      if (warming) return;
      warming = true;
      try {
        while (pendingLine !== null && current === generation && !disposed) {
          const nextLine = pendingLine;
          pendingLine = null;
          try { await preloadContextAssets(windowContext(nextLine)); }
          catch (error) {
            // Speculative loading must not interrupt the current dialogue.
            // Upstream Assets.load retries the actual resource when needed.
            console.warn('[PRTS host] lookahead preload failed', error);
          }
        }
      } finally { warming = false; }
    };
    player.onDisplayedLineChange(line => {
      if (current !== generation || disposed) return;
      stage.dataset.line = line?.toString() ?? '';
      if (line !== null && line !== undefined && current === generation && !disposed) {
        pendingLine = line;
        void warmAhead();
      }
      // Despite its name, upstream emits the physical, 1-based source line.
      const entry = lines.find(entry => entry.lineNumber === line && entry.kind !== 'command');
      if (entry && entry.kind !== 'command') {
        stage.setAttribute('aria-label',
          `${entry.kind === 'dialogue' && entry.speaker ? entry.speaker + '：' : ''}${entry.text}，点击继续`);
      }
    });
    await begin();
  } catch (error) { if (current === generation && !disposed) fail(error); }
}

async function begin() {
  if (!ready || !player) return;
  const active = player;
  unlockAudio();
  overlay.hidden = true;
  stage.focus();
  await active.start();
}

function advance() {
  if (!ready || !player || !overlay.hidden) return;
  void player.advance().catch(fail);
}
stage.addEventListener('click', advance);
stage.addEventListener('keydown', event => {
  if (event.key === ' ' || event.key === 'Enter' || event.key === 'ArrowRight') {
    event.preventDefault();
    advance();
  }
});
restart.onclick = () => { void load(); };
element('fullscreen').onclick = () => {
  if (!document.fullscreenElement) void document.documentElement.requestFullscreen().catch(fail);
  else void document.exitFullscreen();
};
const poll = setInterval(() => {
  if (!ready || !player) return;
  stage.dataset.state = player.getState();
  if (player.getState() === 'finished') {
    overlay.hidden = false;
    heading.textContent = '本节故事结束';
    status.textContent = '可以重新阅读，或返回活动主题页。';
    progress.hidden = true;
    retry.hidden = false;
    retry.textContent = '重新阅读';
    retry.onclick = () => { void load(); };
  }
}, 100);
window.addEventListener('pagehide', () => {
  disposed = true;
  generation++;
  clearInterval(poll);
  document.removeEventListener('pointerdown', unlockAudio, true);
  document.removeEventListener('click', unlockAudio, true);
  document.removeEventListener('keydown', unlockAudio, true);
  audioContext.removeEventListener('statechange', syncAudioState);
  player?.destroy();
  player = null;
});
void load();
