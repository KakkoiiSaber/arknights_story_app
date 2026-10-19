import { sound } from '@pixi/sound';
import { loadContextByScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/context';
import { createStoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/createStoryPlayer';
import { preloadContextAssets } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/preload';
import { parseScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/parser';
import { resolveScriptURL } from './source.mjs';
import { resourceSource, githubCharacterContext } from './resources.mjs';
import { loadingWindow } from './loading-window.mjs';
import type { StoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/types';

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const stage = element<HTMLDivElement>('stage');
const overlay = element<HTMLDivElement>('overlay');
const heading = element<HTMLHeadingElement>('heading');
const status = element<HTMLParagraphElement>('status');
const progress = element<HTMLProgressElement>('progress');
const start = element<HTMLButtonElement>('start');
const restart = element<HTMLButtonElement>('restart');
const query = new URLSearchParams(location.search);
const source = resourceSource();
const sourceSelect = element<HTMLSelectElement>('resources');
sourceSelect.value = source;
sourceSelect.onchange = () => {
  const next = new URL(location.href);
  next.searchParams.set('resources', sourceSelect.value);
  location.replace(next.href);
};
stage.dataset.resources = source;
const returnButton = element<HTMLButtonElement>('return');
returnButton.hidden = window.parent === window;
returnButton.onclick = () => window.parent.postMessage('arkstory:exit', location.origin);
element('title').textContent = query.get('title') || '黑暗时代·上 · 序章·上';
let player: StoryPlayer | null = null;
let ready = false;
let generation = 0;
let disposed = false;

function fail(error: unknown) {
  console.error('[PRTS host]', error);
  ready = false;
  overlay.hidden = false;
  heading.textContent = '剧情加载失败';
  status.textContent = error instanceof Error ? error.message : String(error);
  progress.hidden = true;
  start.textContent = '重新加载';
  start.disabled = false;
  start.onclick = () => { void load(); };
}

async function load() {
  const started = performance.now();
  const current = ++generation;
  ready = false;
  player?.destroy();
  player = null;
  overlay.hidden = false;
  heading.textContent = '正在载入剧情';
  status.textContent = '获取原版 TXT 和 PRTS 资源映射…';
  progress.hidden = false;
  progress.value = 0;
  start.disabled = true;
  restart.disabled = true;
  try {
    const scriptURL = resolveScriptURL(query.get('script'));
    const response = await fetch(scriptURL, { signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error(`剧情 TXT: HTTP ${response.status}`);
    const script = await response.text();
    if (!script.trim()) throw new Error('剧情 TXT 为空');
    const originalContext = await Promise.race([
      loadContextByScript(script),
      new Promise<never>((_, reject) => setTimeout(() => reject(
        new Error('PRTS 资源映射加载超时，请重试。')), 45000)),
    ]);
    if (current !== generation || disposed) return;
    const context = source === 'github' ? githubCharacterContext(originalContext) : originalContext;
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
        status.textContent = `${source === 'github' ? 'GitHub Raw' : 'PRTS'} · 准备开场资源和字体 ${Math.round(value * 100)}%`;
      });
    } finally { clearTimeout(timeout); }
    if (current !== generation || disposed) return;
    player = createStoryPlayer(context);
    await player.mount(stage);
    if (current !== generation || disposed) { player?.destroy(); player = null; return; }
    ready = true;
    heading.textContent = '准备就绪';
    const loadMs = Math.round(performance.now() - started);
    stage.dataset.loadMs = String(loadMs);
    status.textContent = `${source === 'github' ? 'GitHub Raw' : 'PRTS'} · 开场就绪，用时 ${(loadMs / 1000).toFixed(1)} 秒。后续资源随阅读加载，点击开始启用音频。`;
    progress.value = 1;
    start.textContent = '开始阅读';
    start.disabled = false;
    restart.disabled = false;
    start.onclick = () => { void begin(); };
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
      stage.dataset.line = line?.toString() ?? '';
      if (line !== null && line !== undefined && current === generation && !disposed) {
        pendingLine = line;
        void warmAhead();
      }
      // Despite its name, upstream emits the physical, 1-based source line.
      const entry = lines.find(entry => entry.lineNumber === line && entry.kind !== 'command');
      if (entry && entry.kind !== 'command') {
        stage.setAttribute('aria-label',
          `${entry.kind === 'dialogue' ? entry.speaker + '：' : ''}${entry.text}，点击继续`);
      }
    });
  } catch (error) { if (current === generation && !disposed) fail(error); }
}

async function begin() {
  if (!ready || !player) return;
  // Resume audio within the user's click, before any asynchronous playback work.
  void sound.context.audioContext.resume();
  stage.dataset.audioState = sound.context.audioContext.state;
  overlay.hidden = true;
  stage.focus();
  try { await player.start(); } catch (error) { fail(error); }
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
    start.textContent = '重新阅读';
    start.onclick = () => { void load(); };
  }
}, 100);
window.addEventListener('pagehide', () => {
  disposed = true;
  generation++;
  clearInterval(poll);
  player?.destroy();
  player = null;
});
void load();
