import { test } from 'node:test';
import assert from 'node:assert/strict';
import { installAudioLifecycle } from './audio-lifecycle.mjs';

function fixture({ native = false, pending = false } = {}) {
  const context = new EventTarget();
  context.state = 'interrupted';
  let attempts = 0;
  context.resume = () => {
    attempts++;
    if (pending) return new Promise(() => {});
    context.state = 'running';
    return Promise.resolve();
  };
  const page = new EventTarget();
  page.visibilityState = 'visible';
  const lifecycle = new EventTarget();
  const stage = { dataset: {} };
  const browser = { audioSession: { type: 'auto' } };
  const audio = installAudioLifecycle({ context, page, lifecycle, stage,
    native, navigator: browser });
  return { context, page, lifecycle, stage, browser, audio, attempts: () => attempts };
}

test('native iOS interrupted audio resumes as playback on touchend', () => {
  const f = fixture({ native: true });
  f.page.dispatchEvent(new Event('touchend'));
  assert.equal(f.attempts(), 1);
  assert.equal(f.context.state, 'running');
  assert.equal(f.browser.audioSession.type, 'playback');
  f.audio.dispose();
});

test('an unresolved resume never blocks a later gesture retry', () => {
  const f = fixture({ pending: true });
  f.context.state = 'suspended';
  f.audio.resume();
  f.page.dispatchEvent(new Event('click'));
  assert.equal(f.attempts(), 2);
  assert.equal(f.browser.audioSession.type, 'auto');
  f.audio.dispose();
});

test('foreground restores interrupted sound, hidden pages remain inactive', () => {
  const f = fixture();
  f.page.visibilityState = 'hidden';
  f.page.dispatchEvent(new Event('visibilitychange'));
  assert.equal(f.attempts(), 0);
  f.page.visibilityState = 'visible';
  f.page.dispatchEvent(new Event('visibilitychange'));
  assert.equal(f.attempts(), 1);
  f.context.state = 'interrupted';
  f.lifecycle.dispatchEvent(new Event('pageshow'));
  assert.equal(f.attempts(), 2);
  f.audio.dispose();
});

test('leaving the player removes gesture and lifecycle audio handlers', () => {
  const f = fixture();
  f.audio.dispose();
  for (const name of ['touchend', 'click', 'pointerdown', 'keydown', 'visibilitychange']) {
    f.page.dispatchEvent(new Event(name));
  }
  f.lifecycle.dispatchEvent(new Event('focus'));
  f.audio.resume();
  assert.equal(f.attempts(), 0);
});
