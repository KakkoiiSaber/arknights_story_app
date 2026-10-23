import { LayerGraph } from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/rendering/core/LayerGraph';

// Host-only art viewer: suppress the renderer UI root without changing the
// dialogue/decision state. Keep world artwork and scene effects intact.
let ui: LayerGraph['ui'] | undefined;
let hidden = false;
const attach = LayerGraph.prototype.attach;
LayerGraph.prototype.attach = function (stage) {
  attach.call(this, stage);
  ui = this.ui;
  ui.renderable = !hidden;
};

export function setSceneUIVisible(value: boolean) {
  if (ui && !ui.destroyed) ui.renderable = value;
}

let frame = 0;

export function setArtView(value: boolean, animate = false) {
  cancelAnimationFrame(frame);
  hidden = value;
  const root = ui;
  const hud = document.getElementById('hud')!;
  const restore = document.getElementById('restore-view') as HTMLButtonElement;
  const stage = document.getElementById('stage')!;
  const duration = animate && !matchMedia('(prefers-reduced-motion: reduce)').matches ? 220 : 0;
  const from = root && !root.destroyed && root.renderable ? root.alpha : 0;
  const hudFrom = getComputedStyle(hud).opacity;
  hud.getAnimations().forEach(animation => animation.cancel());
  document.body.classList.toggle('art-view', value);
  document.getElementById('art-view')?.setAttribute('aria-pressed', String(value));
  const finish = () => {
    if (root && !root.destroyed) { root.alpha = value ? 0 : 1; root.renderable = !value; }
    restore.hidden = !value;
    stage.setAttribute('aria-hidden', String(value));
    if (!value && animate) stage.focus();
  };
  if (!duration) { finish(); if (value) restore.focus(); return; }
  // The transparent restore button blocks story advancement during both fades.
  restore.hidden = false;
  stage.setAttribute('aria-hidden', 'true');
  if (value) restore.focus();
  if (root && !root.destroyed) root.renderable = true;
  hud.animate([{opacity:hudFrom},{opacity:value ? 0 : 1}], {duration, easing:'ease-out'});
  const started = performance.now();
  const tick = (now: number) => {
    const t = Math.min(1, (now - started) / duration);
    const eased = 1 - (1 - t) ** 3;
    if (root && !root.destroyed) root.alpha = from + ((value ? 0 : 1) - from) * eased;
    if (t < 1) frame = requestAnimationFrame(tick);
    else finish();
  };
  frame = requestAnimationFrame(tick);
}
