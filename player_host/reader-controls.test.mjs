import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';

const output = await build({
  stdin: {contents: `export {readHistory} from './reader-history';
    export {parseScript} from '../third_party/prts-widgets/src/widgets/StoryPlayer/engine/parser';`,
    resolveDir: fileURLToPath(new URL('.', import.meta.url)), loader: 'ts'},
  bundle: true, write: false, format: 'esm', platform: 'node', target: 'es2022',
});
const { readHistory, parseScript } = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
const text = rows => rows.map(r => r.spans.map(s => s.text).join('')).join('\n');

test('history includes displayed text but never unread text or markup', () => {
  const lines = parseScript(['[name="阿米娅"]<b>已读</b>', '[name="凯尔希"]未读']);
  const rows = readHistory(lines, new Set([1]), {lineIndex: 1, selections: []});
  assert.equal(rows.length, 1);
  assert.equal(rows[0].speaker, '阿米娅');
  assert.equal(text(rows), '已读');
  assert.equal(rows[0].spans[0].bold, true);
});

test('history uses the actual decision and excludes the other branch', () => {
  const lines = parseScript([
    '[Decision(options="前进;等待",values="1;2")]',
    '[Predicate(references="1")]', '[name="阿米娅"]前进分支',
    '[Predicate(references="2")]', '[name="阿米娅"]等待分支',
    '[Predicate]', '[name="阿米娅"]下一句',
  ]);
  const rows = readHistory(lines, new Set([3]), {lineIndex: 3,
    selections: [{decisionId: 1, optionIndex: 0, value: 1}]});
  assert.match(text(rows), /› 前进/);
  assert.match(text(rows), /前进分支/);
  assert.doesNotMatch(text(rows), /等待分支|下一句/);
});

test('history uses upstream multiline accumulation', () => {
  const lines = parseScript([
    '[multiline(name="阿米娅")]第一段',
    '[multiline]第二段', '[name="凯尔希"]之后的对白',
  ]);
  const rows = readHistory(lines, new Set([1, 2]), {lineIndex: 2, selections: []});
  assert.match(text(rows), /第一段/);
  assert.match(text(rows), /第二段/);
  assert.doesNotMatch(text(rows), /之后的对白/);
});

test('immersive shell has no fullscreen action or title bar', async () => {
  const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
  assert.doesNotMatch(html, /<header|id="fullscreen"|id="title"/);
  for (const id of ['return', 'settings', 'log', 'auto', 'quick'])
    assert.match(html, new RegExp(`id="${id}"`));
});
