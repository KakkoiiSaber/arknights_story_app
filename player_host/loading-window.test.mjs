import test from 'node:test';
import assert from 'node:assert/strict';
import { loadingWindow } from './loading-window.mjs';

test('opening window excludes distant chapter assets', () => {
  const source = ['background', 'hello', 'sound', 'world', 'later background', 'later'];
  const parsed = source.map((text, i) => ({ lineNumber: i + 1,
    kind: i % 2 ? 'dialogue' : 'command', text }));
  assert.deepEqual(loadingWindow(source, parsed, 1, 2), source.slice(0, 4));
  assert.deepEqual(loadingWindow(source, parsed, 4, 2), source.slice(3));
});

test('physical multiline continuations stay intact; empty text does not consume lookahead', () => {
  const source = ['command', 'hello\\', 'world', '', 'next', 'later'];
  const parsed = [{lineNumber: 1, kind: 'command'},
    {lineNumber: 2, kind: 'dialogue', text: 'hello world'},
    {lineNumber: 4, kind: 'narration', text: ''},
    {lineNumber: 5, kind: 'dialogue', text: 'next'},
    {lineNumber: 6, kind: 'dialogue', text: 'later'}];
  assert.deepEqual(loadingWindow(source, parsed, 1, 1), source.slice(0, 3));
  assert.deepEqual(loadingWindow(source, parsed, 4, 1), source.slice(3, 5));
});

test('command-only passages are bounded and empty scripts are safe', () => {
  const source = Array.from({length: 300}, () => 'command');
  const parsed = source.map((_, i) => ({lineNumber: i + 1, kind: 'command'}));
  assert.equal(loadingWindow(source, parsed).length, 160);
  assert.deepEqual(loadingWindow([], []), []);
  assert.deepEqual(loadingWindow(source, parsed, 999), []);
});

test('implicit endtip sharing the last source line does not truncate dialogue', () => {
  const source = ['hello'];
  const parsed = [{lineNumber: 1, kind: 'dialogue', text: 'hello'},
    {lineNumber: 1, kind: 'command', command: 'endtip'}];
  assert.deepEqual(loadingWindow(source, parsed, 1, 1), source);
});
