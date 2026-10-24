import { test } from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';

// Exercise the real button wiring with only its rendering/dialog dependencies mocked.
const output = await build({
  entryPoints: [fileURLToPath(new URL('./reader-controls.ts', import.meta.url))],
  bundle: true, write: false, format: 'esm', platform: 'node',
  plugins: [{name: 'control-dependencies', setup(api) {
    api.onResolve({filter: /^\.\/(dialog-motion|art-view|reader-history|reader-preferences|host-bridge)$/}, args => ({path: args.path, namespace: 'stub'}));
    api.onLoad({filter: /.*/, namespace: 'stub'}, () => ({contents: `
      export const openReaderDialog = () => {}, closeReaderDialog = async () => {};
      export const setArtView = value => globalThis.__artView = value, setSceneUIVisible = () => {};
      export const readHistory = () => [], normalizePreferences = value => value;
      export const notifyHost = async () => {};
    `}));
  }}],
});
const {ReaderControls} = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);

test('auto has no gear; quick cycles four gears and toggles back to manual', () => {
  const elements = new Map();
  const element = id => {
    if (!elements.has(id)) elements.set(id, {hidden: true, disabled: false, attributes: {},
      addEventListener() {}, setAttribute(k, v) { this.attributes[k] = v; }});
    return elements.get(id);
  };
  globalThis.document = {getElementById: element, addEventListener() {}, querySelectorAll: () => [], querySelector: () => null};
  const state = {mode: 'default', buttonSpeedLevel: 0, quickSpeedLevel: 0};
  const player = {
    getState: () => 'waiting_input', getAutoPlayState: () => ({...state}), isTheaterMode: () => false,
    onDisplayedLineChange: () => () => {}, setAutoPlayMode: mode => state.mode = mode,
    setAutoPlaySpeedLevel: level => {state.quickSpeedLevel = level;},
  };
  try {
    const controls = new ReaderControls(async () => {}, () => ({}));
    controls.attach(player);
    element('auto').onclick();
    assert.equal(state.mode, 'button_auto');
    assert.equal(element('speed').hidden, true);
    element('speed').onclick();
    assert.equal(state.quickSpeedLevel, 0);
    element('quick').onclick();
    assert.equal(state.mode, 'quick_play');
    assert.equal(element('speed').hidden, false);
    for (const expected of [1, 2, 3, 0]) {
      element('speed').onclick();
      assert.equal(state.quickSpeedLevel, expected);
      assert.match(element('speed').textContent, new RegExp(String(expected + 1)));
    }
    element('quick').onclick();
    assert.equal(state.mode, 'default');
    assert.equal(element('speed').hidden, true);
    element('auto').onclick();
    element('art-view').onclick();
    assert.equal(state.mode, 'default');
    assert.equal(globalThis.__artView, true);
    assert.equal(element('art-view').attributes['aria-pressed'], undefined);
  } finally { delete globalThis.document; delete globalThis.__artView; }
});
