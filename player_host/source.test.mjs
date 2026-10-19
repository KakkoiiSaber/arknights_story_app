import { test } from 'node:test';
import assert from 'node:assert/strict';
import { defaultScript, resolveScriptURL } from './source.mjs';

test('default source is the requested prologue', () => {
  assert.equal(resolveScriptURL(null).href, defaultScript);
  assert.match(defaultScript, /obt\/guide\/beg\/0_welcome_to_guide.txt$/);
});
test('accept CN and YoStar script URLs from Flutter config', () => {
  assert.equal(resolveScriptURL(defaultScript).href, defaultScript);
  assert.match(resolveScriptURL('https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData_YoStar/main/en_US/gamedata/story/obt/main/example.txt').href, /en_US/);
});
test('reject non-script, cross-origin and credential-bearing sources', () => {
  for (const value of ['javascript:alert(1)', 'https://example.com/story.txt',
    defaultScript+'?token=x', defaultScript+'#test', defaultScript.replace('.txt','.json'),
    defaultScript.replace('https://','https://user:password@'),
    defaultScript.replace('/zh_CN/gamedata/story/', '/other/')]) {
    assert.throws(() => resolveScriptURL(value));
  }
});
