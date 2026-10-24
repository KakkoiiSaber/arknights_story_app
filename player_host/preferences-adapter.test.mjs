import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import ts from 'typescript';
import { adaptReaderPreferences } from './preferences-adapter.mjs';

const root = '../third_party/prts-widgets/src/widgets/StoryPlayer/';
const read = file => readFile(new URL(root + file, import.meta.url), 'utf8');

test('real upstream nickname substitution follows the global doctor name', async () => {
  const source = adaptReaderPreferences(await read('engine/textVariables.ts'),
    '/StoryPlayer/engine/textVariables.ts');
  const js = ts.transpileModule(source, {compilerOptions: {target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ESNext}}).outputText;
  const engine = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
  globalThis.__arkstoryPreferences = {doctorName: '凯尔希'};
  try {
    assert.equal(engine.expandStoryText('你好，{@nickname}。'), '你好，凯尔希。');
    globalThis.__arkstoryPreferences.doctorName = '博士';
    assert.equal(engine.expandStoryText('{@nickname}'), '博士');
  } finally { delete globalThis.__arkstoryPreferences; }
});

test('automatic reading follows text preferences regardless of gears; quick play keeps its speed', async () => {
  const source = adaptReaderPreferences(await read('engine/runtime.ts'),
    '/StoryPlayer/engine/runtime.ts');
  const body = source.match(/private getCurrentSpeed\(\): AutoSpeed \{([\s\S]*?)\n  \}/)[1];
  const js = ts.transpileModule(`function getSpeed() {${body}}`, {
    compilerOptions: {target: ts.ScriptTarget.ES2022}}).outputText;
  const speed = new Function('BUTTON_AUTO_SPEEDS', 'QUICK_AUTO_SPEEDS',
    `${js}; return getSpeed.call(this);`);
  const runtime = {autoPlayMode: 'default', defaultSpeed: {
    typeWriterDelayMs: 40, animateRatio: 1, autoWaitBaseTime: 2}};
  globalThis.__arkstoryPreferences = {typingIntervalMs: 0};
  try {
    assert.deepEqual(speed.call(runtime, [], []), {...runtime.defaultSpeed, typeWriterDelayMs: 0});
    runtime.autoPlayMode = 'button_auto';
    for (const delay of [0, 25, 70]) {
      globalThis.__arkstoryPreferences.typingIntervalMs = delay;
      for (const gear of [0, 1, 2]) {
        runtime.buttonSpeedLevel = gear;
        runtime.quickSpeedLevel = gear;
        assert.deepEqual(speed.call(runtime, [{typeWriterDelayMs: 10}], []),
          {...runtime.defaultSpeed, typeWriterDelayMs: delay});
      }
    }
    runtime.autoPlayMode = 'quick_play'; runtime.quickSpeedLevel = 1;
    const quickSpeeds = [{typeWriterDelayMs: 10}, {typeWriterDelayMs: 5}];
    assert.deepEqual(speed.call(runtime, [], quickSpeeds), quickSpeeds[1]);
  } finally { delete globalThis.__arkstoryPreferences; }
});

test('dialogue font refresh preserves current text and recalculates layout', async () => {
  const source = adaptReaderPreferences(await read('engine/rendering/panels/DialogPanel.ts'),
    '/rendering/panels/DialogPanel.ts');
  const callback = source.match(/globalThis.__arkstoryRefreshDialogue = \(\) => \{([\s\S]*?)\n    \};/)[1];
  const layout = {text: '完整的一行对白'};
  let applied;
  const panel = {dialogue: {text: '完整', style: {}}, applyLayout: v => applied = v};
  let fittedName;
  panel.speaker = {text: '阿米娅'};
  panel.applyNameBestFit = name => fittedName = name;
  globalThis.__arkstoryPreferences = {fontScale: 1.4};
  try {
    new Function('layout', callback).call(panel, layout);
    assert.equal(panel.dialogue.style.fontSize, 24 * 1.4);
    assert.equal(panel.dialogue.text, '完整');
    assert.equal(fittedName, '阿米娅');
    assert.equal(applied, layout);
  } finally { delete globalThis.__arkstoryPreferences; }
  assert.throws(() => adaptReaderPreferences('', '/StoryPlayer/engine/runtime.ts'), /contract changed/);
});

test('speaker font follows the dialogue scale and long names fit their region', async () => {
  const source = adaptReaderPreferences(await read('engine/rendering/panels/DialogPanel.ts'),
    '/rendering/panels/DialogPanel.ts');
  const method = source.match(/  private applyNameBestFit\(name: string\): void \{([\s\S]*?)\n  \}/)[1];
  const js = ts.transpileModule(`function fit(name: string) {${method}}`, {
    compilerOptions: {target: ts.ScriptTarget.ES2022}}).outputText;
  const fit = new Function('CanvasTextMetrics', 'DialogPanel', 'name', `${js}; return fit.call(this, name);`);
  const metrics = {measureText: (name, style) => ({width: Array.from(name).length * style.fontSize})};
  const constants = {NAME_FONT_MAX: 30, NAME_FONT_MIN: 25, NAME_WIDTH: 312.3};
  const panel = {speaker: {style: {fontSize: 30}}};
  try {
    for (const scale of [0.8, 1, 1.4, 1]) {
      globalThis.__arkstoryPreferences = {fontScale: scale};
      fit.call(panel, metrics, constants, '阿米娅');
      assert.equal(panel.speaker.style.fontSize, 30 * scale);
      const longName = '一个很长很长的人物称号与人物名称';
      fit.call(panel, metrics, constants, longName);
      assert.ok(metrics.measureText(longName, panel.speaker.style).width <= 312.3 + 1e-9);
    }
  } finally { delete globalThis.__arkstoryPreferences; }
});
