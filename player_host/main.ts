import { sound } from '@pixi/sound';
import { installAudioLifecycle } from './audio-lifecycle.mjs';
import { ReaderControls } from './reader-controls';
import { notifyHost } from './host-bridge';
import { StoryQueue, CompletionTransition } from './story-queue.mjs';
import { loadContextByScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/context';
import { createStoryPlayer } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/createStoryPlayer';
import { preloadContextAssets } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/preload';
import { parseScript } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/parser';
import { loadingWindow } from './loading-window.mjs';
import { installNativeDelivery } from './native-delivery';
import { installReaderPreferences } from './reader-preferences';
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
const archiveSkin = query.get('skin') === 'archive';
const loadingPercent = element<HTMLOutputElement>('loading-percent');
function setLoadingProgress(value: number) {
  const normalized = Math.max(0, Math.min(1, value));
  progress.value = normalized;
  overlay.style.setProperty('--load-progress', String(normalized));
  loadingPercent.textContent = `${Math.round(normalized * 100).toString().padStart(2, '0')}%`;
}
installReaderPreferences(query);
const controls = new ReaderControls(skipStory, () => ({
  title: queue?.current.title || query.get('title') || '当前剧情',
  storyName: queue?.current.storyName || query.get('storyName') || '',
  summary: queue?.current.summary || query.get('summary') || '',
}));
installNativeDelivery();
stage.dataset.resources = 'prts';
let player: StoryPlayer | null = null;
let ready = false;
let generation = 0;
let disposed = false;
let queue: StoryQueue;
const completion = new CompletionTransition();
let finishShown = false;
const audioContext = sound.context.audioContext;
const playerAudio = installAudioLifecycle({ context: audioContext, stage,
  native: query.get('native') === '1' });
const unlockAudio = playerAudio.resume;
// Called after the native app reactivates its iOS audio session on foreground.
Object.assign(globalThis, { __arkstoryResumeAudio: unlockAudio });

function fail(error: unknown) {
  console.error('[PRTS host]', error);
  ready = false;
  overlay.hidden = false;
  overlay.dataset.phase = 'error';
  heading.textContent = '剧情加载失败';
  status.textContent = error instanceof Error ? error.message : String(error);
  progress.hidden = true;
  retry.hidden = false;
  retry.textContent = '重试';
  retry.onclick = () => { void load(); };
}

async function load(continuing = false) {
  const playback = continuing ? player?.getAutoPlayState() : null;
  completion.reset();
  finishShown = false;
  const started = performance.now();
  const current = ++generation;
  ready = false;
  controls.attach(null);
  player?.destroy();
  player = null;
  overlay.hidden = false;
  overlay.dataset.phase = 'loading';
  heading.textContent = archiveSkin ? '正在释放神经递质' : '加载中…';
  status.textContent = '正在准备剧情…';
  progress.hidden = false;
  setLoadingProgress(0);
  retry.hidden = true;
  restart.disabled = true;
  try {
    queue ??= new StoryQueue(query.get('script'), query.get('playlist'));
    const scriptURL = queue.current.script;
    document.title = queue.current.title || query.get('title') || '剧情阅读';
    stage.dataset.script = scriptURL;
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
    setLoadingProgress(0.12);
    status.textContent = '正在解析剧情与资源映射…';
    const context = await Promise.race([
      loadContextByScript(script),
      new Promise<never>((_, reject) => setTimeout(() => reject(
        new Error('PRTS 资源映射加载超时，请重试。')), 45000)),
    ]);
    if (current !== generation || disposed) return;
    setLoadingProgress(0.24);
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
        setLoadingProgress(0.24 + Math.max(0, Math.min(1, value)) * 0.68);
        status.textContent = `正在加载开场资源 ${Math.round(value * 100)}%`;
      });
    } finally { clearTimeout(timeout); }
    if (current !== generation || disposed) return;
    setLoadingProgress(0.96);
    player = createStoryPlayer(context);
    await player.mount(stage);
    if (current !== generation || disposed) { player?.destroy(); player = null; return; }
    controls.attach(player, lines, context.audioVariables);
    if (playback) {
      player.setAutoPlayMode(playback.mode);
      player.setAutoPlaySpeedLevel(playback.mode === 'quick_play' ? playback.quickSpeedLevel : playback.buttonSpeedLevel);
    }
    ready = true;
    const loadMs = Math.round(performance.now() - started);
    stage.dataset.loadMs = String(loadMs);
    setLoadingProgress(1);
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
  if (!ready || !player || !overlay.hidden || controls.modalOpen) return;
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
async function skipStory() {
  if (!ready || !player || disposed || controls.modalOpen || !overlay.hidden) return;
  try {
    if (player.canSkipNode()) await player.skipNode();
    else if (queue.next) nextSection();
    else await notifyHost('exit');
  } catch (error) { fail(error); }
}

function nextSection() {
  if (!ready || disposed || controls.modalOpen || !queue.advance()) return;
  void load(true);
}
const poll = setInterval(() => {
  if (!ready || !player) return;
  stage.dataset.state = player.getState();
  controls.sync();
  if (player.getState() === 'finished') {
    if (!finishShown) {
      finishShown = true;
      overlay.hidden = false;
      overlay.dataset.phase = 'complete';
      heading.textContent = queue.isStoryEnd ? '整部故事已结束' : '本节故事结束';
      status.textContent = queue.next ? `即将进入下一节：${queue.next.title || '下一节'}` : '可以重新阅读，或返回故事页。';
      progress.hidden = true;
      retry.hidden = false;
      retry.textContent = queue.next ? '继续下一节' : '重新阅读';
      retry.onclick = () => { if (queue.next) nextSection(); else void load(); };
    }
    if (queue.next && completion.tick(performance.now(), controls.modalOpen)) nextSection();
  }

}, 100);
window.addEventListener('pagehide', () => {
  disposed = true;
  generation++;
  clearInterval(poll);
  playerAudio.dispose();
  controls.attach(null);
  player?.destroy();
  player = null;
});
void load();
